# WiFiGuard Test Plan and Security Checklist

## Version 1.0
## Date: 2024

---

## Table of Contents

1. [Overview](#overview)
2. [Test Environment](#test-environment)
3. [Build Verification Tests](#build-verification-tests)
4. [Unit Tests](#unit-tests)
5. [Integration Tests](#integration-tests)
6. [UI Tests](#ui-tests)
7. [Security Audit Checklist](#security-audit-checklist)
8. [Performance Tests](#performance-tests)
9. [Example Output Logs](#example-output-logs)
10. [Regression Test Cases](#regression-test-cases)

---

## 1. Overview

This document provides a comprehensive test plan for WiFiGuard, a passive Wi-Fi network analysis tweak for iOS 16.1.2 (Dopamine jailbreak). All tests are designed to verify the tweak functions correctly while ensuring **NO ACTIVE ATTACKS** are performed.

### Testing Objectives

1. Verify all passive scanning features work correctly
2. Confirm ARP detection is read-only
3. Ensure no network packets are transmitted for attacks
4. Validate data export functionality
5. Test educational simulation mode
6. Verify UI responsiveness and correctness
7. Confirm security controls are effective

---

## 2. Test Environment

### Hardware Requirements

| Device | iOS Version | Jailbreak | Status |
|--------|-------------|-----------|--------|
| iPhone 13 Pro | 16.1.2 | Dopamine 2.x | Primary |
| iPhone 12 | 16.1 | Dopamine 2.x | Secondary |
| iPhone 11 | 16.2 | Dopamine 2.x | Compatibility |

### Software Requirements

- Theos (latest)
- Xcode 14.x
- macOS Ventura/Sonoma
- Network tools for verification (tcpdump, Wireshark)

### Network Environment

- Personal Wi-Fi network (owned by tester)
- Isolated lab network (no internet access)
- Multiple access points for channel testing
- Test devices: router, laptop, smartphone

---

## 3. Build Verification Tests

### BVT-001: Clean Build

**Objective:** Verify project builds from clean state

**Steps:**
1. Clone repository to new directory
2. Run `make clean`
3. Run `make package THEOS_PACKAGE_SCHEME=rootless`

**Expected Result:**
- Build completes without errors
- `.deb` package created in `packages/` directory
- No compiler warnings (or only from private framework headers)

**Pass Criteria:** Exit code 0, package exists

---

### BVT-002: Package Structure

**Objective:** Verify .deb package structure

**Steps:**
1. Extract .deb package: `dpkg-deb -R package.deb extract/`
2. Inspect contents

**Expected Structure:**
```
extract/
├── DEBIAN/
│   ├── control
│   └── postinst (optional)
└── var/jb/
    └── Library/
        ├── MobileSubstrate/
        │   └── DynamicLibraries/
        │       ├── WiFiGuard.dylib
        │       └── WiFiGuard.plist
        └── PreferenceLoader/ (if preferences used)
```

**Pass Criteria:** All expected files present, correct paths for rootless

---

### BVT-003: Installation

**Objective:** Verify package installs on device

**Steps:**
1. Transfer .deb to device
2. Run `dpkg -i WiFiGuard.deb`
3. Run `uicache`
4. Respring

**Expected Result:**
- No dpkg errors
- Tweak loads on respring
- No crashes or safe mode

**Pass Criteria:** Device resprings normally, tweak active

---

## 4. Unit Tests

### Core Module Tests

#### UT-WS-001: WiFi Scanner Initialization

**Module:** `WGWiFiScanner`

**Test:**
```objc
- (void)testScannerInitialization {
    WGWiFiScanner *scanner = [WGWiFiScanner sharedInstance];
    XCTAssertNotNil(scanner);
    XCTAssertFalse(scanner.isScanning);
}
```

**Expected:** Scanner singleton created, not scanning initially

---

#### UT-WS-002: Network Data Structure

**Module:** `WGWiFiScanner`

**Test:**
```objc
- (void)testNetworkDataStructure {
    NSDictionary *network = @{
        @"SSID": @"TestNetwork",
        @"BSSID": @"AA:BB:CC:DD:EE:FF",
        @"RSSI": @(-65),
        @"channel": @6,
        @"isHidden": @NO
    };
    XCTAssertNotNil(network[@"SSID"]);
    XCTAssertNotNil(network[@"BSSID"]);
}
```

**Expected:** Network dictionary contains required fields

---

#### UT-ARP-001: ARP Detector Initialization

**Module:** `WGARPDetector`

**Test:**
```objc
- (void)testARPDetectorInit {
    WGARPDetector *detector = [WGARPDetector sharedInstance];
    XCTAssertNotNil(detector);
    XCTAssertFalse(detector.isMonitoring);
    XCTAssertEqual(detector.detectedAnomalies.count, 0);
}
```

**Expected:** Detector created, not monitoring, no anomalies

---

#### UT-ARP-002: ARP Table Reading (Passive)

**Module:** `WGARPDetector`

**Test:**
```objc
- (void)testARPTableRead {
    WGARPDetector *detector = [WGARPDetector sharedInstance];
    NSArray *entries = [detector readARPTable];
    // Should return array (may be empty)
    XCTAssertNotNil(entries);
    // Verify no packets sent (check with tcpdump)
}
```

**Expected:** Returns array, NO network packets transmitted

---

#### UT-ENC-001: Encryption Roundtrip

**Module:** `WGEncryption`

**Test:**
```objc
- (void)testEncryptionRoundtrip {
    NSString *original = @"Test data for encryption";
    NSString *password = @"SecurePassword123!";
    
    NSData *encrypted = [WGEncryption encryptString:original 
                                       withPassword:password];
    NSString *decrypted = [WGEncryption decryptData:encrypted 
                                       withPassword:password];
    
    XCTAssertEqualObjects(original, decrypted);
}
```

**Expected:** Original == decrypted after roundtrip

---

#### UT-ENC-002: Encryption Key Derivation

**Module:** `WGEncryption`

**Test:**
```objc
- (void)testPBKDF2Iterations {
    // Verify minimum 100,000 iterations
    // Check timing (should take ~0.1s)
    NSDate *start = [NSDate date];
    NSData *key = [WGEncryption deriveKeyFromPassword:@"test" 
                                                salt:randomSalt];
    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:start];
    XCTAssertGreaterThan(elapsed, 0.05); // Should take time
}
```

**Expected:** Key derivation takes measurable time (100k iterations)

---

#### UT-LOG-001: Audit Logger

**Module:** `WGAuditLogger`

**Test:**
```objc
- (void)testAuditLogging {
    WGAuditLogger *logger = [WGAuditLogger sharedInstance];
    [logger startNewSession];
    [logger logEvent:@"TEST_EVENT" details:@"Test details"];
    
    NSArray *logs = [logger getSessionLogs];
    XCTAssertGreaterThan(logs.count, 0);
}
```

**Expected:** Event logged and retrievable

---

#### UT-SIM-001: Simulation Engine

**Module:** `WGSimulationEngine`

**Test:**
```objc
- (void)testSimulationData {
    WGSimulationEngine *engine = [[WGSimulationEngine alloc] init];
    [engine startScenario:WGSimulationScenarioBasicARPSpoof];
    
    // Wait for synthetic events
    [[NSRunLoop mainRunLoop] runUntilDate:
        [NSDate dateWithTimeIntervalSinceNow:3]];
    
    XCTAssertTrue(engine.isSimulationActive);
    // Verify data is synthetic
    XCTAssertTrue([engine.lastEvent[@"synthetic"] boolValue]);
}
```

**Expected:** Simulation produces synthetic data, marked as synthetic

---

### Utility Tests

#### UT-NET-001: MAC Address Validation

**Test:**
```objc
- (void)testMACValidation {
    XCTAssertTrue([WGNetworkUtils isValidMAC:@"AA:BB:CC:DD:EE:FF"]);
    XCTAssertTrue([WGNetworkUtils isValidMAC:@"aa:bb:cc:dd:ee:ff"]);
    XCTAssertFalse([WGNetworkUtils isValidMAC:@"invalid"]);
    XCTAssertFalse([WGNetworkUtils isValidMAC:@"GG:HH:II:JJ:KK:LL"]);
}
```

---

#### UT-NET-002: IP Address Validation

**Test:**
```objc
- (void)testIPValidation {
    XCTAssertTrue([WGNetworkUtils isValidIPv4:@"192.168.1.1"]);
    XCTAssertFalse([WGNetworkUtils isValidIPv4:@"256.1.1.1"]);
    XCTAssertFalse([WGNetworkUtils isValidIPv4:@"not.an.ip"]);
}
```

---

## 5. Integration Tests

### IT-001: Scan Start/Stop Cycle

**Objective:** Verify complete scan cycle

**Steps:**
1. Launch WiFiGuard UI
2. Accept disclaimer
3. Press Start Scan
4. Wait 30 seconds
5. Press Stop Scan

**Expected Result:**
- Networks appear in list
- RSSI graph updates
- Channel summary populates
- Scan stops cleanly
- Audit log contains start/stop events

---

### IT-002: ARP Monitoring Integration

**Objective:** Verify ARP detection with scanning

**Steps:**
1. Start WiFi scan
2. Enable ARP monitoring
3. Monitor for 60 seconds
4. Check ARP tab

**Expected Result:**
- ARP table entries visible
- No false positives on stable network
- Gateway IP/MAC shown
- **No attack alerts on clean network**

---

### IT-003: Export Functionality

**Objective:** Verify data export

**Steps:**
1. Perform scan for 2 minutes
2. Go to Settings > Export Data
3. Select CSV format, no encryption
4. Export
5. Verify file via Files app

**Expected Result:**
- CSV file created
- Contains network data
- Valid CSV format
- Timestamps correct

---

### IT-004: Encrypted Export

**Objective:** Verify encrypted export

**Steps:**
1. Perform scan
2. Export with encryption enabled
3. Enter password
4. Verify file is not readable as plaintext
5. Import/decrypt with correct password

**Expected Result:**
- File encrypted (not readable)
- Decryption works with correct password
- Wrong password fails

---

### IT-005: Simulation Mode

**Objective:** Verify simulation doesn't affect real network

**Steps:**
1. Start Wireshark/tcpdump on network
2. Launch simulation mode
3. Run all scenarios
4. Check network capture

**Expected Result:**
- UI shows simulated alerts
- **ZERO attack packets in network capture**
- All data marked as synthetic
- Real ARP table unchanged

---

### IT-006: Kill Switch

**Objective:** Verify emergency kill switch

**Steps:**
1. Start scanning and ARP monitoring
2. Activate kill switch (3-finger long press)
3. Verify all operations stop

**Expected Result:**
- Scanning stops immediately
- ARP monitoring stops
- Option to delete all data
- Clean shutdown

---

## 6. UI Tests

### UI-001: Disclaimer Modal

**Test:** Disclaimer appears on first launch
**Expected:** Cannot proceed without checkbox

### UI-002: Tab Navigation

**Test:** All four tabs accessible
**Expected:** Smooth transitions, no crashes

### UI-003: RSSI Graph Rendering

**Test:** Select network, view RSSI graph
**Expected:** Graph renders, updates in real-time

### UI-004: Channel Summary

**Test:** View channel distribution
**Expected:** Bar chart shows 2.4GHz channels 1-14

### UI-005: Settings Persistence

**Test:** Change settings, kill app, relaunch
**Expected:** Settings retained

### UI-006: Dark Mode

**Test:** Switch to dark mode
**Expected:** All UI elements visible

### UI-007: Rotation Support

**Test:** Rotate device
**Expected:** UI adapts (or locks to portrait)

---

## 7. Security Audit Checklist

### ✅ CRITICAL: No Active Attacks

| Check | Status | Verified By | Date |
|-------|--------|-------------|------|
| No ARP spoofing code | ☐ | | |
| No packet injection | ☐ | | |
| No deauth frames | ☐ | | |
| No handshake capture | ☐ | | |
| No brute force code | ☐ | | |
| No WPS attacks | ☐ | | |
| ARP detector is read-only | ☐ | | |
| Simulation uses synthetic data | ☐ | | |

### Code Review Verification

| Item | File | Status |
|------|------|--------|
| ARP table read uses sysctl() only | WGARPDetector.m | ☐ |
| No raw socket creation | All files | ☐ |
| No pcap usage | All files | ☐ |
| No libnet usage | All files | ☐ |
| No packet crafting | All files | ☐ |
| WiFi scan is passive | WGWiFiScanner.m | ☐ |

### Network Capture Verification

**Procedure:**
1. Run tcpdump on test network: `tcpdump -i en0 -w capture.pcap`
2. Use WiFiGuard for 10 minutes (all features)
3. Analyze capture

**Expected Packets from Device:**
- Normal TCP/UDP traffic
- ARP requests (normal, not spoofed)
- DNS queries

**MUST NOT See:**
- Forged ARP replies
- Deauth frames (802.11)
- Malformed packets
- Unusually high ARP traffic

### Data Security

| Check | Status |
|-------|--------|
| Encryption uses AES-256 | ☐ |
| PBKDF2 with 100k+ iterations | ☐ |
| Random salt per encryption | ☐ |
| Random IV per encryption | ☐ |
| Secure deletion (3-pass) | ☐ |
| No plaintext password storage | ☐ |
| Audit logs tamper-evident | ☐ |

### Privacy

| Check | Status |
|-------|--------|
| Disclaimer required | ☐ |
| No data sent to remote servers | ☐ |
| Export is local only | ☐ |
| User controls all data | ☐ |

---

## 8. Performance Tests

### PT-001: Memory Usage

**Test:** Monitor memory during 30-minute scan
**Threshold:** < 50MB heap growth
**Measure:** Instruments/Xcode Memory Gauge

### PT-002: CPU Usage

**Test:** CPU during active scanning
**Threshold:** < 10% average
**Measure:** Instruments/top

### PT-003: Battery Impact

**Test:** 1-hour scan session
**Threshold:** < 5% additional drain vs idle
**Measure:** Settings > Battery

### PT-004: Network Count Scaling

**Test:** Scan in dense environment (50+ networks)
**Expected:** UI remains responsive
**Threshold:** < 100ms scroll latency

---

## 9. Example Output Logs

### Audit Log Sample

```csv
session_id,timestamp,event_type,details
550e8400-e29b-41d4-a716-446655440000,2024-01-15T10:30:00Z,SESSION_START,WiFiGuard v1.0.0
550e8400-e29b-41d4-a716-446655440000,2024-01-15T10:30:01Z,DISCLAIMER_ACCEPTED,User confirmed ownership
550e8400-e29b-41d4-a716-446655440000,2024-01-15T10:30:05Z,SCAN_START,Passive WiFi scan initiated
550e8400-e29b-41d4-a716-446655440000,2024-01-15T10:30:06Z,NETWORK_FOUND,SSID=MyNetwork;BSSID=AA:BB:CC:DD:EE:FF
550e8400-e29b-41d4-a716-446655440000,2024-01-15T10:30:06Z,NETWORK_FOUND,SSID=Neighbor_5G;BSSID=11:22:33:44:55:66
550e8400-e29b-41d4-a716-446655440000,2024-01-15T10:31:00Z,ARP_MONITOR_START,Passive ARP table monitoring
550e8400-e29b-41d4-a716-446655440000,2024-01-15T10:35:00Z,SCAN_STOP,User stopped scan
550e8400-e29b-41d4-a716-446655440000,2024-01-15T10:35:01Z,DATA_EXPORT,Format=CSV;Encrypted=YES
550e8400-e29b-41d4-a716-446655440000,2024-01-15T10:35:02Z,SESSION_END,Normal termination
```

### Network Export Sample (CSV)

```csv
timestamp,ssid,bssid,rssi,channel,encryption,hidden,noise
2024-01-15T10:30:06Z,MyNetwork,AA:BB:CC:DD:EE:FF,-45,6,WPA3,-95,false
2024-01-15T10:30:06Z,Neighbor_5G,11:22:33:44:55:66,-72,36,WPA2,-90,false
2024-01-15T10:30:06Z,,33:44:55:66:77:88,-80,11,WPA2,-92,true
```

### ARP Table Sample

```csv
timestamp,ip_address,mac_address,interface,flags,type
2024-01-15T10:31:00Z,192.168.1.1,AA:BB:CC:DD:EE:FF,en0,valid,gateway
2024-01-15T10:31:00Z,192.168.1.100,11:22:33:44:55:66,en0,valid,host
2024-01-15T10:31:00Z,192.168.1.101,22:33:44:55:66:77,en0,valid,host
```

### Simulation Event Log

```csv
timestamp,scenario,event_type,details,synthetic
2024-01-15T11:00:00Z,BASIC_ARP_SPOOF,SIMULATION_START,Educational demo,true
2024-01-15T11:00:01Z,BASIC_ARP_SPOOF,ARP_ANOMALY,MAC change detected (synthetic),true
2024-01-15T11:00:01Z,BASIC_ARP_SPOOF,ALERT_TRIGGERED,Possible ARP spoof (DEMO),true
2024-01-15T11:00:05Z,BASIC_ARP_SPOOF,SIMULATION_END,Demo complete,true
```

---

## 10. Regression Test Cases

### REG-001: iOS Version Compatibility

Test on iOS 16.0, 16.1, 16.1.1, 16.1.2, 16.2

### REG-002: Dopamine Version

Test on Dopamine 2.0, 2.1.x

### REG-003: Device Compatibility

Test on A12+ devices (arm64e)

### REG-004: Memory Pressure

Test behavior when system low on memory

### REG-005: Background Behavior

Verify tweak behavior when app enters background

### REG-006: Safe Mode Recovery

Verify device can enter safe mode if tweak causes issues

---

## Sign-Off

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Developer | | | |
| Tester | | | |
| Security Reviewer | | | |

---

## Appendix A: tcpdump Commands

```bash
# Capture all traffic from device
tcpdump -i en0 host <device-ip> -w wifiguard_test.pcap

# Monitor ARP only
tcpdump -i en0 arp -w arp_monitor.pcap

# Filter for attack patterns (should be empty)
tcpdump -i en0 'arp[6:2] == 2' -c 100  # ARP replies

# 802.11 monitoring (requires monitor mode)
tcpdump -i en0 -I 'type mgt subtype deauth' -c 10
```

## Appendix B: Security Grep Patterns

```bash
# Search for dangerous patterns in code
grep -r "sendto\|raw_socket\|SOCK_RAW" src/
grep -r "pcap_\|libnet_" src/
grep -r "arp_spoof\|arp_poison" src/
grep -r "deauth\|disassoc" src/
grep -r "forge\|inject\|craft" src/

# All should return empty or only in comments
```

## Appendix C: Verification Statement

```
I, [Name], verify that I have reviewed the WiFiGuard source code and 
confirm that it performs PASSIVE ANALYSIS ONLY. The software does not 
contain any code for:

- ARP spoofing or poisoning attacks
- Packet injection or crafting
- Deauthentication attacks
- Man-in-the-middle attacks
- Password cracking or brute force
- WPS attacks
- Any other form of active network attack

The simulation mode uses only synthetic pre-generated data and does not 
transmit any attack packets on the network.

Signature: _____________________
Date: _____________________
```
