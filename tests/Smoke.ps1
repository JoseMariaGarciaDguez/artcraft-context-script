$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$entries = @(. "$root/ArtCraftContext.ps1" -Action List)
if ($entries.Count -ne 19) { throw 'Unexpected catalog size' }
if (@($entries | Group-Object Product | Where-Object Count -gt 1).Count) { throw 'Duplicate product' }
$testDir = [IO.Directory]::CreateDirectory((Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())))
try {
    foreach ($entry in $entries) {
        $recipe = @($catalog.($entry.Product))
        if (!$recipe.Count) { continue }
        if (!$entry.Installed -and $recipe[2] -notin '@pdf','@png') { continue }
        [byte[]]$bytes = Make-Template $entry.Product $recipe $entry.Executable $testDir.FullName
        if ($bytes.Length -lt 32) { throw "Invalid template for $($entry.Product)" }
        if ($entry.Product -in 'WordCraft','GridCraft','DeckCraft') {
            $cli = $entry.Executable.Replace('.exe','-cli.exe')
            & $cli info (Join-Path $testDir.FullName ($entry.Product + $recipe[1])) | Out-Null
            if ($LASTEXITCODE) { throw "Cannot reopen $($entry.Product) template" }
        }
    }
} finally {
    Get-ChildItem -LiteralPath $testDir.FullName -File | Remove-Item -Force
    Remove-Item -LiteralPath $testDir.FullName
}
Write-Host 'Catalog and available template generators passed.'
