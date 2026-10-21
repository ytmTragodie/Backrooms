param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath
)

$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$logDirectory = Join-Path ([IO.Path]::GetTempPath()) ('backrooms-validation-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($logDirectory) | Out-Null

function Invoke-GodotCheck([string]$Name, [string[]]$Arguments, [bool]$RequiresPass = $false) {
    $logPath = Join-Path $logDirectory ($Name + '.log')
    & $GodotPath --headless --path $projectPath @Arguments *> $logPath
    $processExit = $LASTEXITCODE
    $lines = Get-Content -LiteralPath $logPath
    # 退出码可能漏报 GDScript 异常，必须同时检查日志和套件完成标记。
    $unexpected = @($lines | Select-String -Pattern 'SCRIPT ERROR|^ERROR:(?! Failed to read the root certificate store)|ObjectDB instances leaked|resources still in use|[TEST] FAIL')
    $passed = @($lines | Select-String -SimpleMatch '[TEST] PASS')
    if ($processExit -ne 0 -or $unexpected.Count -gt 0 -or ($RequiresPass -and $passed.Count -eq 0)) {
        $lines | Select-Object -Last 80 | Write-Output
        throw "Validation failed: $Name (exit=$processExit). Log: $logPath"
    }
    if ($RequiresPass) {
        $passed | ForEach-Object { $_.Line } | Write-Output
    } else {
        Write-Output "[CHECK] PASS $Name"
    }
}

# --quit 是首帧退出；--import 明确等待资源导入结束，避免扫描未完成时退出。
Invoke-GodotCheck 'import' @('--import')
foreach ($suite in @('phase_1', 'phase_2', 'phase_3', 'phase_4', 'phase_5', 'phase_6', 'phase_7', 'phase_8', 'rework_a', 'rework_b', 'rework_c', 'ui', 'phase_9', 'phase_10', 'phase_11', 'phase_12', 'objective_types')) {
    Invoke-GodotCheck $suite @('--script', "res://tests/${suite}_validation.gd") $true
}
Invoke-GodotCheck 'main' @('--quit-after', '5')
Write-Output "Logs: $logDirectory"
Write-Output 'Known environment message allowed: Windows root certificate store unavailable.'
