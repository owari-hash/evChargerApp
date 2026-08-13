# Wireless Android Device Connection Helper Script
# Usage: .\connect-wireless-device.ps1

$adbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

if (-not (Test-Path $adbPath)) {
    Write-Host "ERROR: ADB not found at $adbPath" -ForegroundColor Red
    Write-Host "Please ensure Android SDK platform-tools are installed." -ForegroundColor Yellow
    exit 1
}

Write-Host "=== Wireless Android Device Connection ===" -ForegroundColor Cyan
Write-Host ""

# Restart ADB server to avoid hanging issues
Write-Host "Restarting ADB server..." -ForegroundColor Yellow
& $adbPath kill-server 2>&1 | Out-Null
Start-Sleep -Milliseconds 500
& $adbPath start-server 2>&1 | Out-Null
Start-Sleep -Milliseconds 500

# Check current devices with timeout
Write-Host "Current connected devices:" -ForegroundColor Yellow
try {
    $job = Start-Job -ScriptBlock { 
        param($adb)
        & $adb devices 2>&1
    } -ArgumentList $adbPath
    
    $result = Wait-Job -Job $job -Timeout 3
    if ($result) {
        Receive-Job -Job $job
        Remove-Job -Job $job
    } else {
        Write-Host "ADB command timed out. Trying direct call..." -ForegroundColor Yellow
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        Remove-Job -Job $job -ErrorAction SilentlyContinue
        # Try direct call as fallback
        Start-Process -FilePath $adbPath -ArgumentList "devices" -NoNewWindow -Wait -RedirectStandardOutput "temp_adb_output.txt" -ErrorAction SilentlyContinue | Out-Null
        if (Test-Path "temp_adb_output.txt") {
            Get-Content "temp_adb_output.txt"
            Remove-Item "temp_adb_output.txt" -ErrorAction SilentlyContinue
        }
    }
} catch {
    Write-Host "Error checking devices: $_" -ForegroundColor Red
    Write-Host "Continuing anyway..." -ForegroundColor Yellow
}
Write-Host ""

# Ask user for connection method
Write-Host "Select connection method:" -ForegroundColor Green
Write-Host "1. Android 11+ (Wireless Debugging with pairing code)"
Write-Host "2. Android 10 and below (ADB over Network)"
Write-Host "3. Just list devices"
Write-Host ""

$choice = Read-Host "Enter choice (1-3)"

switch ($choice) {
    "1" {
        Write-Host ""
        Write-Host "=== Android 11+ Wireless Debugging ===" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "On your device:" -ForegroundColor Yellow
        Write-Host "1. Go to Settings → Developer options → Wireless debugging"
        Write-Host "2. Tap 'Pair device with pairing code'"
        Write-Host "3. Note the PORT and 6-digit code"
        Write-Host ""
        
        $defaultIP = "192.168.1.11"
        $pairPort = Read-Host "Enter pairing PORT (default IP: $defaultIP)"
        $pairCode = Read-Host "Enter 6-digit pairing code"
        
        $pairAddress = "$defaultIP`:$pairPort"
        
        Write-Host ""
        Write-Host "Pairing device at $pairAddress..." -ForegroundColor Yellow
        & $adbPath pair "$pairAddress" "$pairCode"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "Pairing successful! Now connect using the new PORT shown above." -ForegroundColor Green
            $connectPort = Read-Host "Enter the new PORT to connect (default IP: $defaultIP)"
            
            $connectAddress = "$defaultIP`:$connectPort"
            Write-Host ""
            Write-Host "Connecting to $connectAddress..." -ForegroundColor Yellow
            & $adbPath connect "$connectAddress"
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host ""
                Write-Host "Connection successful!" -ForegroundColor Green
                & $adbPath devices
            }
        }
    }
    "2" {
        Write-Host ""
        Write-Host "=== ADB over Network (Android 10 and below) ===" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "First, connect your device via USB and enable USB debugging." -ForegroundColor Yellow
        Write-Host ""
        
        $usbConnected = Read-Host "Is your device connected via USB? (y/n)"
        
        if ($usbConnected -eq "y" -or $usbConnected -eq "Y") {
            Write-Host ""
            Write-Host "Enabling TCP/IP mode on port 5555..." -ForegroundColor Yellow
            & $adbPath tcpip 5555
            
            Write-Host ""
            Write-Host "Now disconnect the USB cable." -ForegroundColor Yellow
            Write-Host ""
            
            $defaultIP = "192.168.1.11"
            $devicePort = Read-Host "Enter PORT (default: 5555, default IP: $defaultIP)"
            
            if ([string]::IsNullOrWhiteSpace($devicePort)) {
                $devicePort = "5555"
            }
            
            $deviceAddress = "$defaultIP`:$devicePort"
            
            Write-Host ""
            Write-Host "Connecting wirelessly to $deviceAddress..." -ForegroundColor Yellow
            & $adbPath connect "$deviceAddress"
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host ""
                Write-Host "Connection successful!" -ForegroundColor Green
                & $adbPath devices
            }
        } else {
            Write-Host "Please connect your device via USB first, then run this script again." -ForegroundColor Red
        }
    }
    "3" {
        Write-Host ""
        Write-Host "=== Connected Devices ===" -ForegroundColor Cyan
        & $adbPath devices
        Write-Host ""
        Write-Host "=== Flutter Devices ===" -ForegroundColor Cyan
        flutter devices
    }
    default {
        Write-Host "Invalid choice. Exiting." -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan

