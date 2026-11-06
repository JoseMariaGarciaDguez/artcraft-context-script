#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('List','Install','Uninstall')][string]$Action = 'List',
    [ValidateSet('Machine','User')][string]$Scope = 'Machine',
    [string[]]$Product
)
$ErrorActionPreference = 'Stop'
$catalog = Get-Content -LiteralPath "$PSScriptRoot/products.json" -Raw | ConvertFrom-Json
$names = @($catalog.PSObject.Properties.Name)
if ($Product) {
    foreach ($name in $Product) {
        if ($name -notin $names) { throw "Unknown product: $name. Run -Action List for the catalog." }
    }
    $names = $Product
}
if ($Action -ne 'List' -and $Scope -eq 'Machine') {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    if (!([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole('Administrator')) {
        throw 'Open Windows PowerShell as administrator, or use -Scope User.'
    }
    if ([Environment]::Is64BitOperatingSystem -and ![Environment]::Is64BitProcess) {
        throw 'Use 64-bit Windows PowerShell to configure the machine menu.'
    }
}
$classes = if ($Scope -eq 'Machine') { 'HKLM:\Software\Classes' } else { 'HKCU:\Software\Classes' }
$owner = 'artcraft-context-script.v1'
function Find-App($name) {
    $roots = @($env:ProgramW6432, $env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ } | Select-Object -Unique
    if ($Scope -eq 'User') { $roots = @("$env:LOCALAPPDATA\Programs", $env:LOCALAPPDATA) + $roots }
    $slug = $name.Replace(' ','-').ToLowerInvariant()
    foreach ($root in $roots) {
        $shortName = $name -replace '^ArtCraft ', ''
        foreach ($folder in @("$root\ArtCraft\$name", "$root\$name", "$root\ArtCraft\$slug", "$root\$slug", "$root\ArtCraft\$shortName")) {
            foreach ($base in @($slug, $name, $name.Replace(' ',''))) {
                $exe = Join-Path $folder "$base.exe"
                if (Test-Path -LiteralPath $exe -PathType Leaf) { return (Get-Item -LiteralPath $exe).FullName }
            }
        }
    }
}
function Make-Template($name, $recipe, $exe, $temp) {
    $file = Join-Path $temp ($name + $recipe[1])
    switch ($recipe[2]) {
        '@pdf' { return [IO.File]::ReadAllBytes("$PSScriptRoot/assets/blank.pdf") }
        '@png' { return [IO.File]::ReadAllBytes("$PSScriptRoot/assets/blank.png") }
    }
    $cli = Join-Path (Split-Path $exe) ($name.ToLowerInvariant() + '-cli.exe')
    if (!(Test-Path -LiteralPath $cli)) { throw "Companion CLI missing: $cli" }
    $arguments = foreach ($token in $recipe[2..($recipe.Count-1)]) {
        switch ($token) {
            '{output}' { $file }
            '{steps}' { "$PSScriptRoot/assets/empty-steps.json" }
            default { $token }
        }
    }
    if ('{output}' -notin $recipe) { $arguments = @($arguments) + $file }
    & $cli @arguments | Out-Host
    if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $file -PathType Leaf)) { throw "Template generation failed for $name." }
    $length = (Get-Item -LiteralPath $file).Length
    if ($length -le 0) { throw "$name produced an empty file." }
    if ($length -gt 1MB) { throw 'Template exceeds the registry data limit used by this installer.' }
    return [IO.File]::ReadAllBytes($file)
}
function Set-Value($path, $key, $value, $type = 'String') {
    if (!(Test-Path -LiteralPath $path)) { New-Item -Path $path -Force | Out-Null }
    New-ItemProperty -LiteralPath $path -Name $key -Value $value -PropertyType $type -Force | Out-Null
}
function Remove-Owned($path) {
    if (Test-Path -LiteralPath $path) {
        if ((Get-Item -LiteralPath $path).GetValue('ArtCraftContextOwner') -eq $owner) {
            Remove-Item -LiteralPath $path -Recurse -Force
        }
    }
}
$temp = $null
$failed = $false
try {
    if ($Action -eq 'Install') {
        $temp = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString()))
    }
    foreach ($name in $names) {
        $recipe = @($catalog.$name)
        $slug = $name.Replace(' ','').ToLowerInvariant()
        $launchExt = ".artcraftnew-$slug"
        $class = "ArtCraftContext.$slug"
        $ext = if ($recipe.Count) { $recipe[1] } else { $null }
        $exe = Find-App $name
        if ($Action -eq 'List') {
            [pscustomobject]@{Product=$name; Installed=[bool]$exe; Format=if ($ext) {$ext} else {'Open app'}; Executable=$exe}
            continue
        }
        try {
            if ($Action -eq 'Uninstall') {
                if ($ext) {
                    Remove-Owned "$classes\$ext\ShellNew"
                    $extKey = Get-Item -LiteralPath "$classes\$ext" -ErrorAction SilentlyContinue
                    if ($extKey -and $extKey.GetValue('') -eq $class) {
                        $writable = $extKey.OpenSubKey('', $true)
                        try { $writable.DeleteValue('') } finally { $writable.Close() }
                    }
                }
                Remove-Owned "$classes\$launchExt"
                Remove-Owned "$classes\$class"
                continue
            }
            if (!$exe) { Write-Host "Skipped $name (not installed in this scope)."; continue }
            $data = $null
            $label = "Open $name"
            if ($ext) {
                $handler = Get-Item -LiteralPath "Registry::HKEY_CLASSES_ROOT\$ext\ShellNew" -ErrorAction SilentlyContinue
                if (!$handler -or $handler.GetValue('ArtCraftContextOwner') -eq $owner) {
                    try {
                        [byte[]]$data = Make-Template $name $recipe $exe $temp.FullName
                        $label = "$name $($recipe[0])"
                    } catch {
                        if ($handler) {
                            Write-Warning "$_ Keeping the last installed template."
                            continue
                        }
                        Write-Warning "$_ Using the Open entry."
                    }
                } elseif ($handler.GetValue('FileName') -like '*\ArtCraft\ShellNew\*') {
                    Write-Host "Keeping the existing ArtCraft menu entry for $name."
                    continue
                } else { Write-Host "$name already has a New handler for $ext. Keeping it." }
            }
            $target = if ($data) { $ext } else { $launchExt }
            $privateKeys = @("$classes\$class")
            if (!$data) { $privateKeys += "$classes\$launchExt" }
            foreach ($key in $privateKeys) {
                if ((Test-Path $key) -and (Get-Item $key).GetValue('ArtCraftContextOwner') -ne $owner) { throw "Existing registration at $key; skipping." }
            }
            Set-Value "$classes\$class" ArtCraftContextOwner $owner
            Set-Value "$classes\$class" '(default)' $label
            Set-Value "$classes\$class\DefaultIcon" '(default)' ('"{0}",0' -f $exe)
            Set-Value "$classes\$class\shell\open\command" '(default)' ('"{0}" "%1"' -f $exe)
            if (!$data) { Set-Value "$classes\$target" ArtCraftContextOwner $owner }
            $assoc = Get-Item -LiteralPath "Registry::HKEY_CLASSES_ROOT\$target" -ErrorAction SilentlyContinue
            if (!$assoc -or !$assoc.GetValue('')) { Set-Value "$classes\$target" '(default)' $class }
            $new = "$classes\$target\ShellNew"
            Set-Value $new ArtCraftContextOwner $owner
            Set-Value $new ItemName $label
            Set-Value $new IconPath ('"{0}",0' -f $exe)
            if ($data) {
                Set-Value $new Data $data Binary
                Remove-Owned "$classes\$launchExt"
            } else { Set-Value $new Command ('"{0}"' -f $exe) }
            Write-Host "Registered $label ($target)."
        } catch { $failed = $true; Write-Warning "$name : $_" }
    }
} finally {
    if ($temp -and $temp.Parent.FullName.TrimEnd('\') -eq [IO.Path]::GetTempPath().TrimEnd('\')) {
        Get-ChildItem -LiteralPath $temp.FullName -File | Remove-Item -Force
        Remove-Item -LiteralPath $temp.FullName
    }
}
if ($Action -ne 'List') {
    Add-Type -Namespace ArtCraftContext -Name Shell -MemberDefinition '[System.Runtime.InteropServices.DllImport("shell32.dll")] public static extern void SHChangeNotify(uint e,uint f,System.IntPtr a,System.IntPtr b);' -ErrorAction SilentlyContinue
    [ArtCraftContext.Shell]::SHChangeNotify(0x08000000,0,[IntPtr]::Zero,[IntPtr]::Zero)
}
if ($failed) { throw 'One or more products could not be configured. See the messages above.' }
