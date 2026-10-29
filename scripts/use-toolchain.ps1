param([string]$SdkHome = (Join-Path $PSScriptRoot '../.tools/moon016'))
$MoonLibertySdk = (Resolve-Path -LiteralPath $SdkHome -ErrorAction Stop).Path
$MoonLibertyVersion = & (Join-Path $MoonLibertySdk 'bin/moon.exe') version --all
if ($LASTEXITCODE -ne 0 -or ($MoonLibertyVersion -join "`n") -notmatch 'moonc v0\.10\.16\+b1a0e846e') {
    throw 'Expected the pinned 0.10.16 SDK. Run python scripts/setup-toolchain.py first.'
}
$env:MOON_HOME = $MoonLibertySdk
$env:PATH = (Join-Path $MoonLibertySdk 'bin') + ';' + $env:PATH
$MoonLibertyVersion
