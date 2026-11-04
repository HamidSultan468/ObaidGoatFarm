# Desktop launcher for Tangent Smart Manager (local development setup).
# 1. Checks PostgreSQL is reachable.
# 2. Starts the backend (port 3000) if it isn't already running.
# 3. Starts the local web server for the Flutter web build (port 8770) if needed.
# 4. Opens the app in its own Chrome/Edge app window.
# Already-running services are reused, so double-clicking twice is safe.
# Logs: backend\logs\. Stop everything with tools\launcher\stop-tangent.ps1.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

$repo = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$backendDir = Join-Path $repo 'backend'
$webDir = Join-Path $repo 'app\build\web'
$logDir = Join-Path $backendDir 'logs'
$backendPort = 3000
$webPort = 8770
$appUrl = "http://localhost:$webPort/"

# Small "Starting..." window: the first start after a reboot can take 40+
# seconds (Node loads node_modules from a cold disk), so show progress.
$splash = New-Object System.Windows.Forms.Form
$splash.Text = 'Tangent Smart Manager'
$splash.Size = New-Object System.Drawing.Size(380, 130)
$splash.StartPosition = 'CenterScreen'
$splash.FormBorderStyle = 'FixedDialog'
$splash.MaximizeBox = $false
$splash.MinimizeBox = $false
$splash.TopMost = $true
$iconPath = Join-Path $PSScriptRoot 'tangent.ico'
if (Test-Path $iconPath) { $splash.Icon = New-Object System.Drawing.Icon($iconPath) }
$status = New-Object System.Windows.Forms.Label
$status.Dock = 'Fill'
$status.TextAlign = 'MiddleCenter'
$status.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$status.Text = 'Starting...'
$splash.Controls.Add($status)
$splash.Show()

function Set-Status([string]$text) {
    $status.Text = $text
    [System.Windows.Forms.Application]::DoEvents()
}

function Show-Error([string]$message) {
    $splash.Close()
    [System.Windows.Forms.MessageBox]::Show($message, 'Tangent Smart Manager', 'OK', 'Error') | Out-Null
    exit 1
}

function Test-Port([int]$port) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $connect = $client.BeginConnect('127.0.0.1', $port, $null, $null)
        return $connect.AsyncWaitHandle.WaitOne(500) -and $client.Connected
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

function Wait-Until([scriptblock]$condition, [int]$seconds) {
    $deadline = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $deadline) {
        if (& $condition) { return $true }
        for ($i = 0; $i -lt 5; $i++) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 100
        }
    }
    return $false
}

$node = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $node) { Show-Error 'Node.js was not found. Install Node.js and try again.' }

# 1. Database
Set-Status 'Checking the database...'
if (-not (Test-Port 5432)) {
    Show-Error "PostgreSQL is not running on port 5432.`n`nStart the 'postgresql-x64-16' service (Services app) and try again."
}

New-Item -ItemType Directory -Force -Path $logDir | Out-Null

# 2. Backend
if (-not (Test-Port $backendPort)) {
    if (-not (Test-Path (Join-Path $backendDir 'dist\main.js'))) {
        Show-Error "The backend has not been built yet.`n`nRun 'npm run build' in the backend folder, then try again."
    }
    Set-Status "Starting the server...`n(the first start after a restart can take up to a minute)"
    Start-Process -FilePath $node -ArgumentList 'dist/main.js' -WorkingDirectory $backendDir -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $logDir 'backend.log') -RedirectStandardError (Join-Path $logDir 'backend-error.log')
    $healthy = Wait-Until {
        try { (Invoke-RestMethod -Uri "http://localhost:$backendPort/health" -TimeoutSec 2).status -eq 'ok' } catch { $false }
    } 120
    if (-not $healthy) {
        Show-Error "The backend did not start within 2 minutes.`n`nSee $logDir\backend-error.log for details."
    }
}

# 3. Web app
if (-not (Test-Port $webPort)) {
    if (-not (Test-Path (Join-Path $webDir 'index.html'))) {
        Show-Error "The web app has not been built yet.`n`nRun 'flutter build web' in the app folder, then try again."
    }
    Set-Status 'Starting the app...'
    Start-Process -FilePath $node -ArgumentList @("`"$PSScriptRoot\serve-web.mjs`"", "`"$webDir`"", $webPort) -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $logDir 'web.log') -RedirectStandardError (Join-Path $logDir 'web-error.log')
    if (-not (Wait-Until { Test-Port $webPort } 15)) {
        Show-Error "The web app server did not start.`n`nSee $logDir\web-error.log for details."
    }
}

# 4. Open as an app window (no tabs/address bar). Chrome, then Edge, then the default browser.
Set-Status 'Opening...'
$browsers = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
)
$browser = $browsers | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($browser) {
    Start-Process -FilePath $browser -ArgumentList "--app=$appUrl", '--window-size=1400,900'
} else {
    Start-Process $appUrl
}
Start-Sleep -Milliseconds 800
$splash.Close()
