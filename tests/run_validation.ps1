param([Parameter(Mandatory=$true)][string]$GodotPath)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$logDirectory = Join-Path ([IO.Path]::GetTempPath()) ('backrooms-phase14-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($logDirectory) | Out-Null
function Check-Godot([string]$Name, [string[]]$Arguments, [bool]$RequirePass=$false) {
    $logPath = Join-Path $logDirectory ($Name + '.log')
    & $GodotPath --headless --path $projectPath @Arguments *> $logPath
    $processExit = $LASTEXITCODE
    $lines = Get-Content -LiteralPath $logPath
    $unexpected = @($lines | Select-String -Pattern 'SCRIPT ERROR|^ERROR:(?! Failed to read the root certificate store)|ObjectDB instances leaked|resources still in use|\[TEST\] FAIL')
    $pass = @($lines | Select-String -SimpleMatch '[TEST] PASS')
    if ($processExit -ne 0 -or $unexpected.Count -gt 0 -or ($RequirePass -and $pass.Count -eq 0)) {
        $lines | Select-Object -Last 80 | Write-Output
        throw "Validation failed: $Name. Log: $logPath"
    }
    if ($RequirePass) { $pass | ForEach-Object { $_.Line } | Write-Output }
    else { Write-Output "[CHECK] PASS $Name" }
}
Check-Godot 'import' @('--import')
Check-Godot 'phase_14' @('--script','res://tests/phase_14_validation.gd') $true
Check-Godot 'phase_15' @('--script','res://tests/phase_15_validation.gd') $true
Check-Godot 'simulation' @('--script','res://tests/phase_14_simulation.gd') $true
Check-Godot 'main' @('--quit-after','5')
Write-Output "Logs: $logDirectory"
