# WiFiGuard - Passive Wi-Fi Network Analyzer

[![iOS 16.1.2](https://img.shields.io/badge/iOS-16.1.2-blue.svg)](https://support.apple.com/ios)
[![Dopamine](https://img.shields.io/badge/Jailbreak-Dopamine%20Rootless-purple.svg)](https://ellekit.space/dopamine/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> **⚠️ LEGAL DISCLAIMER**: This tool is designed for **PASSIVE ANALYSIS ONLY** of Wi-Fi networks that you own or have explicit written permission to analyze. **NO ACTIVE ATTACKS** are implemented or supported. Unauthorized network monitoring is illegal in most jurisdictions.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Private APIs](#private-apis)
- [Security & Privacy](#security--privacy)
- [Simulation Mode](#simulation-mode)
- [Export Formats](#export-formats)
- [Troubleshooting](#troubleshooting)
- [Legal Notice](#legal-notice)
- [License](#license)

## Overview

WiFiGuard is a standalone iOS application for iOS 16.1.2 (Dopamine rootless jailbreak) that provides passive Wi-Fi network analysis capabilities for educational and legitimate security testing purposes. It helps network owners understand their wireless environment without performing any active attacks or intrusive operations.

### What This Tool Does ✅

- Passive scanning of nearby Wi-Fi networks (SSID, BSSID, channels, RSSI)
- Channel congestion analysis and recommendations
- RSSI signal strength monitoring over time
- **Passive** ARP table monitoring for spoofing detection
- Educational simulation of ARP attacks (synthetic data only)
- Encrypted data export

### What This Tool Does NOT Do ❌

- ARP poisoning/spoofing
- Deauthentication attacks
- Man-in-the-Middle attacks
- Handshake capture
- Password cracking
- WPS attacks
- Any form of active network attacks

## Features

### 🔍 Passive Wi-Fi Scanning

- **SSID/BSSID Detection**: Identify all nearby access points
- **Channel Information**: View channel usage and width (20/40/80/160 MHz)
- **Signal Strength**: Monitor RSSI values in real-time
- **Security Type**: Detect WPA2, WPA3, WEP, or Open networks
- **Hidden Networks**: Identify networks with hidden SSIDs

### 📊 RSSI Time Graphs

- Track signal strength changes over time
- Monitor multiple networks simultaneously
- Visual indication of signal quality
- Configurable time window (default: 60 seconds)

### 📡 Channel Analysis

- View network distribution across 2.4 GHz channels
- Identify congested channels
- Get recommendations for optimal channel selection
- Highlight non-overlapping channels (1, 6, 11)

### 🛡️ ARP Spoofing Detection

**PASSIVE MONITORING ONLY** - This module detects potential ARP spoofing attacks by monitoring the ARP table for anomalies:

- Gateway MAC address changes (high severity)
- General MAC address changes
- Duplicate MAC addresses across multiple IPs
- Rapid ARP table changes
- Gratuitous ARP detection

The detector **does NOT**:
- Send any network packets
- Modify the ARP table
- Perform any corrective actions
- Block or intercept traffic

### 🎓 Educational Simulation Mode

Demonstrates ARP spoofing effects using **synthetic data only** for educational purposes. See [Simulation Mode](#simulation-mode) for details.

### 📤 Data Export

- CSV format for spreadsheet analysis
- JSON format for programmatic access
- Optional AES-256 encryption with password
- Manual export only (no automatic transmission)

## Requirements

- **Device**: iPhone/iPad with iOS 16.0 - 16.2
- **Jailbreak**: Dopamine (rootless)
- **Dependencies**: None (standalone application)

## Installation

### From Source (Theos)

1. **Install Theos** (if not already installed):
   ```bash
   bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"
   ```

2. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/WiFiGuard.git
   cd WiFiGuard
   ```

3. **Configure for rootless**:
   ```bash
   export THEOS_PACKAGE_SCHEME=rootless
   ```

4. **Build the package**:
   ```bash
   make package
   ```

5. **Install on device**:
   ```bash
   make install THEOS_DEVICE_IP=your.device.ip
   ```
   
   Or copy the `.deb` file from `packages/` and install via Sileo/Zebra.

6. **Run uicache** (if app icon doesn't appear):
   ```bash
   uicache -a
   ```

### Pre-built Package

1. Add the repository to your package manager
2. Search for "WiFiGuard"
3. Install the application

## Usage

### First Launch

1. After installation, find WiFiGuard app icon on your home screen
2. Tap to launch the application
3. **Read and accept the legal disclaimer**
4. Confirm that you own or have permission to analyze the target network
5. This confirmation is logged for audit purposes

### Main Interface

#### Networks Tab
- View all discovered Wi-Fi networks
- Tap a network for detailed information
- Color-coded signal strength indicators

#### RSSI Graph Tab
- Select networks to track
- View signal strength changes over time
- Useful for finding optimal device placement

#### Channels Tab
- View 2.4 GHz channel distribution
- Bar chart shows network count per channel
- Blue borders highlight non-overlapping channels
- Get channel recommendations

#### ARP Tab
- View current gateway information
- Check for detected anomalies
- Review anomaly history

### Control Buttons

- **▶️ Start Monitoring**: Begin passive scanning and ARP monitoring
- **⏹ Stop Monitoring**: Stop all monitoring activities
- **🛑 Kill Switch**: Immediately stop everything and securely delete temporary files

### Settings

Access settings via the gear icon:

- **Scan Settings**: Adjust scan interval
- **ARP Detection**: Configure alert thresholds
- **Export Data**: Export to CSV/JSON (with optional encryption)
- **Educational Simulation**: Run attack demonstrations
- **Data Management**: Clear cache or secure delete all data
- **About**: Version info, audit log, disclaimer

## Private APIs

This tweak uses the following private frameworks:

### MobileWiFi.framework

| API | Purpose | Risk Level |
|-----|---------|------------|
| `WiFiManagerClientCreate` | Initialize WiFi manager | Medium |
| `WiFiManagerClientCopyDevices` | Get WiFi devices | Medium |
| `WiFiDeviceClientScanAsync` | Perform passive scan | Medium |
| `WiFiNetworkGetSSID` | Get network SSID | Low |
| `WiFiNetworkGetBSSID` | Get network BSSID | Low |
| `WiFiNetworkGetRSSI` | Get signal strength | Low |
| `WiFiNetworkGetChannel` | Get channel number | Low |
| `WiFiNetworkIsHidden` | Check if hidden | Low |
| `WiFiNetworkCopyRecord` | Get network details | Low |

### System APIs (Documented)

| API | Purpose |
|-----|---------|
| `sysctl()` | Read ARP table (passive) |
| `getifaddrs()` | Get network interfaces |
| `CNCopyCurrentNetworkInfo` | Get current network |

### Compatibility Notes

- **Tested on**: iOS 16.0, 16.1, 16.1.2, 16.2
- **Not tested on**: iOS 16.3+
- Private APIs may change between iOS versions
- WiFi scanning requires WiFi to be enabled

### Risks

1. **App Store Rejection**: Uses private APIs (not applicable for sideloading)
2. **iOS Updates**: APIs may change or break
3. **Battery Usage**: Continuous scanning uses more power
4. **Privacy**: Scans can reveal nearby networks

## Security & Privacy

### Data Storage

- All data stored **locally only**
- No telemetry or external transmission
- No cloud sync
- Export only via manual user action

### Encryption

- Optional AES-256 encryption for exports
- PBKDF2 key derivation (100,000 rounds)
- Random salt and IV per encryption

### Audit Logging

Every significant action is logged locally:
- Session start/stop
- Monitoring start/stop
- Owner confirmation
- Data exports
- Anomaly detections
- Errors

### Secure Deletion

- Kill switch securely deletes temporary files
- 3-pass overwrite before deletion
- Option to securely delete all data

## Simulation Mode

The educational simulation mode demonstrates how ARP spoofing attacks work using **completely synthetic data**. No real network operations are performed.

### Available Scenarios

1. **Basic ARP Spoofing**: Shows how an attacker changes the gateway MAC
2. **Man-in-the-Middle**: Demonstrates dual-target ARP poisoning
3. **Duplicate MAC Attack**: Shows same MAC for multiple IPs
4. **Rapid Changes**: Simulates ARP table flooding
5. **Gratuitous ARP**: Demonstrates unsolicited ARP replies

### Important Notes

- Uses pre-generated synthetic data
- No real packets are sent
- No real ARP tables are modified
- For educational/demonstration purposes only
- Helps users understand attack patterns for defense

### Setting Up an Isolated Lab

For hands-on learning with real (but contained) attacks:

1. **Create virtual machines** (not on real network)
2. **Set up isolated virtual network**
3. **Use dedicated tools** on the VMs (not this tweak)
4. **Never connect to production networks**

This tweak intentionally does NOT provide real attack capabilities.

## Export Formats

### CSV (networks.csv)

```csv
SSID,BSSID,Channel,RSSI,Channel Width,Security Type,Hidden,Last Seen
HomeNetwork,AA:BB:CC:DD:EE:01,6,-45,40,WPA2,No,2024-01-15 10:30:00
OfficeWiFi,AA:BB:CC:DD:EE:02,11,-62,20,WPA3,No,2024-01-15 10:30:00
```

### JSON (networks.json)

```json
{
  "exportType": "WiFiNetworks",
  "exportedAt": "2024-01-15 10:30:00",
  "networkCount": 2,
  "networks": [
    {
      "ssid": "HomeNetwork",
      "bssid": "AA:BB:CC:DD:EE:01",
      "channel": 6,
      "rssi": -45,
      "channelWidth": 40,
      "securityType": "WPA2",
      "isHidden": false
    }
  ]
}
```

### Encrypted Export

- Extension: `.json.enc` or `.csv.enc`
- Format: `[32-byte salt][16-byte IV][ciphertext]`
- Algorithm: AES-256-CBC
- Key derivation: PBKDF2-SHA256

## Troubleshooting

### WiFi Scanning Not Working

1. Ensure WiFi is enabled
2. Check that location services are enabled
3. Respring the device
4. Verify the tweak is loaded: `grep WiFiGuard /var/jb/Library/MobileSubstrate/DynamicLibraries/`

### No Networks Found

- Move to different location
- Wait for scan interval to complete
- Check that MobileWiFi framework is accessible

### ARP Detection Not Working

- Ensure you're connected to a WiFi network
- Check that gateway is detected
- Verify network interface is active

### Crashes

1. Check crash logs in Settings > Privacy > Analytics
2. Ensure iOS version is compatible (16.0-16.2)
3. Report issues with crash log

## Legal Notice

### Terms of Use

By using WiFiGuard, you agree to:

1. Only analyze networks you **own** or have **explicit written permission** to test
2. Comply with all applicable local, state, and federal laws
3. Not use this tool for any illegal or unauthorized activities
4. Accept full responsibility for your actions

### Network Owner Permission Template

```
NETWORK ANALYSIS AUTHORIZATION

I, [Owner Name], owner/administrator of the network identified as:

SSID: ____________________
BSSID: ____________________

Grant permission to [Tester Name] to perform passive Wi-Fi network 
analysis using the WiFiGuard tool for the purpose of:

[ ] Security assessment
[ ] Network optimization
[ ] Educational purposes
[ ] Other: ____________________

This authorization is valid from [Start Date] to [End Date].

Scope of authorized activities:
- Passive scanning of network characteristics
- Signal strength monitoring
- Channel analysis
- ARP table monitoring (read-only)

NOT authorized:
- Active attacks of any kind
- Modification of network settings
- Interception of user traffic
- Any action that may disrupt network service

Owner Signature: ____________________
Date: ____________________
Contact: ____________________
```

### Disclaimer

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND. THE DEVELOPERS ARE NOT RESPONSIBLE FOR ANY MISUSE, DAMAGE, OR ILLEGAL ACTIVITY CONDUCTED WITH THIS SOFTWARE. USERS ASSUME ALL RISKS AND LIABILITIES.

## License

MIT License

Copyright (c) 2024 WiFiGuard Developer

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

## Contributing

Contributions are welcome! Please ensure:

1. No active attack functionality
2. All features are passive/detection only
3. Code follows existing style
4. Documentation is updated

## Acknowledgments

- Theos development team
- Dopamine jailbreak developers
- iOS security research community
