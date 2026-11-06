# Run on a disposable Windows runner. Exercise the real HKCU provider.
$ErrorActionPreference = 'Stop'
$source = Split-Path $PSScriptRoot
$root = [IO.Directory]::CreateDirectory((Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())))
$original = $env:LOCALAPPDATA
$script = Join-Path $root.FullName 'ArtCraftContext.ps1'
$products = 'FixturePDF','FixtureLibrary'
$keys = '.artcraft-test-pdf','ArtCraftContext.fixturepdf','.artcraftnew-fixturelibrary','ArtCraftContext.fixturelibrary'
foreach ($key in $keys) {
    if (Test-Path "HKCU:\Software\Classes\$key") { throw "Test requires a clean account: $key" }
}
try {
    $env:LOCALAPPDATA = $root.FullName
    Copy-Item "$source/ArtCraftContext.ps1" $script
    New-Item -ItemType Directory -Path "$($root.FullName)/assets" | Out-Null
    Copy-Item "$source/assets/blank.pdf" "$($root.FullName)/assets/blank.pdf"
    '{"FixturePDF":["Document",".artcraft-test-pdf","@pdf"],"FixtureLibrary":[]}' | Set-Content "$($root.FullName)/products.json"
    foreach ($name in $products) {
        $folder = [IO.Directory]::CreateDirectory((Join-Path $root.FullName "Programs\ArtCraft\$name"))
        [IO.File]::WriteAllBytes((Join-Path $folder.FullName "$name.exe"), [byte[]]@())
    }
    foreach ($pass in 1,2) { & $script -Action Install -Scope User -Product $products }
    $launch = Get-Item 'HKCU:\Software\Classes\.artcraftnew-fixturelibrary\ShellNew'
    if ($launch.GetValue('Command') -notlike '*FixtureLibrary.exe"') { throw 'Launch entry missing' }
    $pdf = Get-Item 'HKCU:\Software\Classes\.artcraft-test-pdf\ShellNew'
        $bytes = $pdf.GetValue('Data')
        if ([Text.Encoding]::ASCII.GetString($bytes,0,5) -ne '%PDF-') { throw 'Invalid PDF registration' }
} finally {
    & $script -Action Uninstall -Scope User -Product $products
    $env:LOCALAPPDATA = $original
    foreach ($name in $products) {
        $file = Join-Path $root.FullName "Programs\ArtCraft\$name\$name.exe"
        if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file }
    }
    foreach ($part in 'assets\blank.pdf','products.json','ArtCraftContext.ps1') { [IO.File]::Delete((Join-Path $root.FullName $part)) }
    foreach ($part in 'assets','Programs\ArtCraft\FixturePDF','Programs\ArtCraft\FixtureLibrary','Programs\ArtCraft','Programs','.') {
        $dir = [IO.Path]::GetFullPath((Join-Path $root.FullName $part))
        if ([IO.Directory]::Exists($dir)) { [IO.Directory]::Delete($dir) }
    }
}
$extension = Get-Item 'HKCU:\Software\Classes\.artcraft-test-pdf' -ErrorAction SilentlyContinue
if ($extension -and !$extension.ValueCount -and !$extension.SubKeyCount) { Remove-Item $extension.PSPath }
foreach ($key in $keys) {
    if (Test-Path "HKCU:\Software\Classes\$key") { throw "Uninstall left $key" }
}

