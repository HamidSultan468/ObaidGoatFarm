# Stops the backend (port 3000) and web server (port 8770) started by
# start-tangent.ps1. Only node.exe processes listening on those ports are
# stopped; anything else on those ports is left alone and reported.
Add-Type -AssemblyName System.Windows.Forms

$stopped = @()
$skipped = @()
foreach ($port in 3000, 8770) {
    $owners = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty OwningProcess -Unique
    foreach ($processId in $owners) {
        $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
        if (-not $process) { continue }
        if ($process.ProcessName -eq 'node') {
            Stop-Process -Id $processId -Force
            $stopped += "port $port (PID $processId)"
        } else {
            $skipped += "port $port is used by $($process.ProcessName) (PID $processId) - not stopped"
        }
    }
}

$message = if ($stopped.Count) { "Stopped: $($stopped -join ', ')" } else { 'Tangent Smart Manager was not running.' }
if ($skipped.Count) { $message += "`n`n$($skipped -join "`n")" }
[System.Windows.Forms.MessageBox]::Show($message, 'Tangent Smart Manager', 'OK', 'Information') | Out-Null
