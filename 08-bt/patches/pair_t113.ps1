# Re-pair Windows with the T113 board via WinRT (the board lost its link keys,
# so the old Windows pairing is stale for auth-requiring profiles like A2DP).
# Steps: find device by BD addr -> unpair -> pair -> report status.
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Runtime.WindowsRuntime

$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() |
    Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
                   $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]

function Await($WinRtTask, $ResultType) {
    $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
    $netTask = $asTask.Invoke($null, @($WinRtTask))
    $netTask.Wait(-1) | Out-Null
    $netTask.Result
}

[Windows.Devices.Enumeration.DeviceInformation,Windows.Devices.Enumeration,ContentType=WindowsRuntime] | Out-Null
[Windows.Devices.Enumeration.DeviceUnpairingResult,Windows.Devices.Enumeration,ContentType=WindowsRuntime] | Out-Null
[Windows.Devices.Enumeration.DevicePairingResult,Windows.Devices.Enumeration,ContentType=WindowsRuntime] | Out-Null
[Windows.Devices.Bluetooth.BluetoothDevice,Windows.Devices.Bluetooth,ContentType=WindowsRuntime] | Out-Null

$addrStr = '347563484AAD'          # T13 board BD address 34:75:63:48:4A:AD
$addr = [Convert]::ToUInt64($addrStr, 16)

Write-Host "=== Re-pair Windows <-> T113-KelpBar ($addrStr) ==="
$bt = Await ([Windows.Devices.Bluetooth.BluetoothDevice]::FromBluetoothAddressAsync($addr)) ([Windows.Devices.Bluetooth.BluetoothDevice])
if (-not $bt) { Write-Host '*** board not visible over BT (not discoverable?)'; exit 1 }
Write-Host ("[1] found: " + $bt.Name + "  paired=" + $bt.DeviceInformation.Pairing.IsPaired)

if ($bt.DeviceInformation.Pairing.IsPaired) {
    Write-Host "[2] removing stale pairing ..."
    $u = Await ($bt.DeviceInformation.Pairing.UnpairAsync()) ([Windows.Devices.Enumeration.DeviceUnpairingResult])
    Write-Host ("    unpair status: " + $u.Status)
    Start-Sleep -Seconds 3
    $bt = Await ([Windows.Devices.Bluetooth.BluetoothDevice]::FromBluetoothAddressAsync($addr)) ([Windows.Devices.Bluetooth.BluetoothDevice])
}

Write-Host "[3] pairing (Just Works, no PIN) ..."
$p = Await ($bt.DeviceInformation.Pairing.PairAsync()) ([Windows.Devices.Enumeration.DevicePairingResult])
Write-Host ("    pair status: " + $p.Status + "  (" + [int]$p.Status + ")")
if ($p.Status -ne [Windows.Devices.Enumeration.DevicePairingResultStatus]::Paired) { exit 2 }

Start-Sleep -Seconds 3
$bt = Await ([Windows.Devices.Bluetooth.BluetoothDevice]::FromBluetoothAddressAsync($addr)) ([Windows.Devices.Bluetooth.BluetoothDevice])
Write-Host ("[4] connection state now: " + $bt.ConnectionState)
Write-Host "=== PAIR DONE ==="
