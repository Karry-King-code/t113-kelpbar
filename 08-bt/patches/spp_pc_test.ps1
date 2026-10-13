$ErrorActionPreference = 'Continue'
$port = 'COM9'
$msg  = 'HELLO_FROM_WINDOWS_PC'

function Log($s) { Write-Host $s }

Log "=== T113-KelpBar SPP (Bluetooth Serial) business test ==="
Log "[1] Opening Bluetooth SPP port $port  (115200 8N1, no flow control)"

$sp = New-Object System.IO.Ports.SerialPort $port,115200,'None',8,'One'
$sp.NewLine      = "`n"
$sp.ReadTimeout  = 4000
$sp.WriteTimeout = 4000
$sp.Handshake    = [System.IO.Ports.Handshake]::None

try {
    $sp.Open()
} catch {
    Log ("    OPEN FAILED: " + $_.Exception.Message)
    exit 1
}
Log "    port opened -> RFCOMM link to the board is up"
Start-Sleep -Milliseconds 2500

Log "[2] Reading lines from the board ..."
$boardLines = @()
for ($i = 0; $i -lt 3; $i++) {
    try {
        $l = $sp.ReadLine().Trim()
        Log ("    BOARD > " + $l)
        $boardLines += $l
    } catch { break }
}

Log "[3] Sending one line from this PC ..."
try {
    $sp.WriteLine($msg)
    Log ("    PC    > " + $msg)
} catch {
    Log ("    WRITE FAILED: " + $_.Exception.Message)
}

Log "[4] Waiting for the echo ..."
$echoOk = $false
for ($i = 0; $i -lt 4; $i++) {
    try {
        $r = $sp.ReadLine().Trim()
        Log ("    BOARD > " + $r)
        if ($r -like "*$msg*") { $echoOk = $true }
    } catch { break }
}

$sp.Close()
Log "[5] Port closed"
Log ""
if ($echoOk) {
    Log "=== SPP BIDIRECTIONAL BUSINESS VERIFIED (PC -> board -> PC) ==="
} elseif ($boardLines.Count -gt 0) {
    Log "=== SPP ONE-WAY VERIFIED (board -> PC); echo not seen ==="
} else {
    Log "=== NO DATA RECEIVED ==="
}
