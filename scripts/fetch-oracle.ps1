$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$destination = Join-Path $project '.tools/oracle'
New-Item -ItemType Directory -Force $destination | Out-Null
$revision = '77440f598eee8291ddf9393e397711645cf0ee11'
$encoded = gh api "repos/liyanqing1987/libertyParser/contents/libertyParser.py?ref=$revision" --jq .content | Out-String
if ($LASTEXITCODE -ne 0) { throw 'Cannot fetch independent oracle' }
$bytes = [Convert]::FromBase64String($encoded)
$target = Join-Path $destination 'libertyParser.py'
[IO.File]::WriteAllBytes($target, $bytes)
$license = gh api "repos/liyanqing1987/libertyParser/contents/LICENSE?ref=$revision" --jq .content | Out-String
if ($LASTEXITCODE -ne 0) { throw 'Cannot fetch oracle license' }
[IO.File]::WriteAllBytes((Join-Path $destination 'LICENSE'), [Convert]::FromBase64String($license))
Write-Output "Independent GPL-2.0 oracle at $revision; ignored test-only directory: $destination"
