[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$MihomoHome,
    [ValidateSet('blocker', 'blockerFL')][string]$List = 'blocker',
    [string]$ProxyUrl
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$homeDir = [IO.Path]::GetFullPath($MihomoHome)
if (-not (Test-Path -LiteralPath $homeDir -PathType Container)) {
    throw 'MihomoHome должен указывать на существующий рабочий каталог ядра (не папку profiles).'
}
$uri = "https://raw.githubusercontent.com/Zalexanninev15/NoADS_RU/main/hosts/$List.txt"
$argsHttp = @{ Uri = $uri; UseBasicParsing = $true; TimeoutSec = 90 }
if ($ProxyUrl) { $argsHttp.Proxy = $ProxyUrl }
$content = [string](Invoke-WebRequest @argsHttp).Content
if ($content.Length -gt 50000000) { throw 'Список неожиданно большой; старый файл сохранён.' }
$domains = New-Object 'System.Collections.Generic.HashSet[string]'
$ip = $null
foreach ($line in ($content -split "`n")) {
    $parts = (($line -split '#', 2)[0].Trim()) -split '\s+'
    if ($parts.Count -lt 2 -or $parts[0] -notin @('0.0.0.0','127.0.0.1','::','::1')) { continue }
    for ($i = 1; $i -lt $parts.Count; $i++) {
        $domain = $parts[$i].ToLowerInvariant().TrimEnd('.')
        if ($domain.Length -gt 253 -or $domain -notmatch '^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$') { continue }
        if ([Net.IPAddress]::TryParse($domain, [ref]$ip)) { continue }
        if ($domain -match '(^|\.)(localhost|local|lan|invalid|test|example)$') { continue }
        [void]$domains.Add($domain)
    }
}
if ($domains.Count -lt 1000) { throw 'Подозрительно мало доменов; старый файл сохранён.' }
$dir = Join-Path $homeDir 'rule-sets'
[void](New-Item -ItemType Directory -Path $dir -Force)
$target = Join-Path $dir 'noads-ru.txt'
$temp = Join-Path $dir ('noads-ru.' + [Guid]::NewGuid().ToString('N') + '.tmp')
$lines = @('# NoADS_RU: exact hostnames, NOT suffixes.', "# Source: $uri", "# Updated UTC: $([DateTime]::UtcNow.ToString('o'))") + @($domains | Sort-Object)
try {
    [IO.File]::WriteAllLines($temp, [string[]]$lines, (New-Object System.Text.UTF8Encoding($false)))
    if ([IO.File]::Exists($target)) {
        [IO.File]::Replace($temp, $target, $target + '.bak')
    } else { [IO.File]::Move($temp, $target) }
} finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp } }
Write-Output "Обновлено доменов: $($domains.Count). Перезагрузите текущую конфигурацию Clash Verge Rev для гарантированного применения."
