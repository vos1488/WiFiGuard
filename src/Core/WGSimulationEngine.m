/*
 * WGSimulationEngine.m - Educational Simulation Implementation
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 * 
 * ============================================================================
 *                    EDUCATIONAL SIMULATION ONLY
 * ============================================================================
 * 
 * THIS MODULE DOES NOT PERFORM ANY REAL ATTACKS.
 * 
 * All data is synthetic and pre-generated. No real network packets are sent.
 * The purpose is to visually demonstrate what ARP spoofing attacks look like
 * so users can better understand and detect them.
 * 
 * This is intended for use in:
 *   - Cybersecurity education courses
 *   - Lab environments with virtual machines
 *   - Understanding attack patterns for defense
 * 
 * ============================================================================
 */

#import "WGSimulationEngine.h"
#import "WGAuditLogger.h"

#pragma mark - WGSimulatedHost Implementation

@implementation WGSimulatedHost

+ (instancetype)hostWithName:(NSString *)name ip:(NSString *)ip mac:(NSString *)mac role:(NSString *)role {
    WGSimulatedHost *host = [[WGSimulatedHost alloc] init];
    host.name = name;
    host.ipAddress = ip;
    host.macAddress = mac;
    host.role = role;
    host.isCompromised = NO;
    return host;
}

@end

#pragma mark - WGSimulationEvent Implementation

@implementation WGSimulationEvent

- (instancetype)init {
    self = [super init];
    if (self) {
        _timestamp = [NSDate date];
        _isMalicious = NO;
    }
    return self;
}

+ (instancetype)eventWithType:(NSString *)type description:(NSString *)desc {
    WGSimulationEvent *event = [[WGSimulationEvent alloc] init];
    event.eventType = type;
    event.description = desc;
    return event;
}

@end

#pragma mark - WGSimulationState Implementation

@implementation WGSimulationState

- (instancetype)init {
    self = [super init];
    if (self) {
        _hosts = @[];
        _eventLog = [NSMutableArray array];
        _victimARPTable = [NSMutableDictionary dictionary];
        _gatewayARPTable = [NSMutableDictionary dictionary];
        _activeScenario = WGSimulationScenarioNone;
        _attackInProgress = NO;
        _elapsedTime = 0;
    }
    return self;
}

@end

#pragma mark - WGSimulationEngine Implementation

@interface WGSimulationEngine ()

@property (nonatomic, strong) WGAuditLogger *auditLogger;
@property (nonatomic, strong) WGSimulationState *currentState;
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, assign) BOOL isPaused;
@property (nonatomic, strong) NSTimer *simulationTimer;
@property (nonatomic, assign) NSInteger currentStep;
@property (nonatomic, assign) WGSimulationScenario currentScenario;

@end

@implementation WGSimulationEngine

#pragma mark - Initialization

- (instancetype)initWithAuditLogger:(WGAuditLogger *)logger {
    self = [super init];
    if (self) {
        _auditLogger = logger;
        _currentState = [[WGSimulationState alloc] init];
        _isRunning = NO;
        _isPaused = NO;
        _currentStep = 0;
        
        [_auditLogger logEvent:@"SIMULATION_ENGINE_INIT" 
                       details:@"Educational simulation engine initialized (NO REAL ATTACKS)"];
    }
    return self;
}

- (void)dealloc {
    [self stopSimulation];
}

#pragma mark - Scenario Information

+ (NSString *)scenarioName:(WGSimulationScenario)scenario {
    switch (scenario) {
        case WGSimulationScenarioBasicARPSpoof:
            return @"Basic ARP Spoofing";
        case WGSimulationScenarioMITMAttack:
            return @"Man-in-the-Middle Attack";
        case WGSimulationScenarioDuplicateMAC:
            return @"Duplicate MAC Attack";
        case WGSimulationScenarioRapidChanges:
            return @"ARP Table Flooding";
        case WGSimulationScenarioGratuitousARP:
            return @"Gratuitous ARP Attack";
        default:
            return @"None";
    }
}

+ (NSString *)scenarioDescription:(WGSimulationScenario)scenario {
    switch (scenario) {
        case WGSimulationScenarioBasicARPSpoof:
            return @"Demonstrates how an attacker changes the gateway's MAC address in the victim's ARP table to intercept traffic. This simulation shows the ARP table before, during, and after the attack.";
            
        case WGSimulationScenarioMITMAttack:
            return @"Shows a complete Man-in-the-Middle scenario where the attacker positions themselves between the victim and gateway. Both the victim and gateway are deceived into sending traffic through the attacker.";
            
        case WGSimulationScenarioDuplicateMAC:
            return @"Illustrates an attack where multiple IP addresses are associated with the same MAC address, which can be used to intercept traffic destined for multiple hosts.";
            
        case WGSimulationScenarioRapidChanges:
            return @"Simulates an ARP table flooding attack where rapid changes overwhelm the network's ARP cache, potentially causing denial of service or enabling spoofing.";
            
        case WGSimulationScenarioGratuitousARP:
            return @"Demonstrates unsolicited ARP replies used to update ARP caches on the network. While sometimes legitimate, this technique is often used in attacks.";
            
        default:
            return @"No scenario selected.";
    }
}

+ (NSArray<NSNumber *> *)availableScenarios {
    return @[
        @(WGSimulationScenarioBasicARPSpoof),
        @(WGSimulationScenarioMITMAttack),
        @(WGSimulationScenarioDuplicateMAC),
        @(WGSimulationScenarioRapidChanges),
        @(WGSimulationScenarioGratuitousARP)
    ];
}

#pragma mark - Simulation Control

- (BOOL)startSimulation:(WGSimulationScenario)scenario {
    if (self.isRunning) {
        [self stopSimulation];
    }
    
    // Log simulation start
    [self.auditLogger logEvent:@"SIMULATION_STARTED" 
                       details:[NSString stringWithFormat:@"Scenario: %@ (EDUCATIONAL ONLY - NO REAL ATTACKS)",
                               [WGSimulationEngine scenarioName:scenario]]];
    
    self.currentScenario = scenario;
    self.currentStep = 0;
    self.isRunning = YES;
    self.isPaused = NO;
    
    // Initialize simulation state
    [self initializeScenario:scenario];
    
    // Start simulation timer (1 second intervals for visualization)
    self.simulationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                            target:self
                                                          selector:@selector(simulationTick)
                                                          userInfo:nil
                                                           repeats:YES];
    
    [self.delegate simulationDidStart:scenario];
    
    return YES;
}

- (void)stopSimulation {
    [self.simulationTimer invalidate];
    self.simulationTimer = nil;
    self.isRunning = NO;
    self.isPaused = NO;
    
    [self.auditLogger logEvent:@"SIMULATION_STOPPED" details:nil];
    [self.delegate simulationDidStop];
}

- (void)pauseSimulation {
    if (self.isRunning && !self.isPaused) {
        [self.simulationTimer invalidate];
        self.simulationTimer = nil;
        self.isPaused = YES;
    }
}

- (void)resumeSimulation {
    if (self.isRunning && self.isPaused) {
        self.simulationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                                target:self
                                                              selector:@selector(simulationTick)
                                                              userInfo:nil
                                                               repeats:YES];
        self.isPaused = NO;
    }
}

- (void)stepForward {
    if (self.isRunning && self.isPaused) {
        [self simulationTick];
    }
}

#pragma mark - Scenario Initialization

- (void)initializeScenario:(WGSimulationScenario)scenario {
    // Create fresh state
    self.currentState = [[WGSimulationState alloc] init];
    self.currentState.activeScenario = scenario;
    
    // Create simulated network hosts (all synthetic data)
    NSMutableArray *hosts = [NSMutableArray array];
    
    // Gateway (router)
    WGSimulatedHost *gateway = [WGSimulatedHost hostWithName:@"Gateway Router"
                                                          ip:@"192.168.1.1"
                                                         mac:@"AA:BB:CC:DD:EE:01"
                                                        role:@"gateway"];
    [hosts addObject:gateway];
    
    // Victim host
    WGSimulatedHost *victim = [WGSimulatedHost hostWithName:@"Victim PC"
                                                         ip:@"192.168.1.100"
                                                        mac:@"AA:BB:CC:DD:EE:10"
                                                       role:@"victim"];
    [hosts addObject:victim];
    
    // Attacker (simulated)
    WGSimulatedHost *attacker = [WGSimulatedHost hostWithName:@"Attacker Machine"
                                                           ip:@"192.168.1.50"
                                                          mac:@"AA:BB:CC:DD:EE:05"
                                                         role:@"attacker"];
    [hosts addObject:attacker];
    
    // Additional clients
    WGSimulatedHost *client1 = [WGSimulatedHost hostWithName:@"Client Device 1"
                                                          ip:@"192.168.1.101"
                                                         mac:@"AA:BB:CC:DD:EE:11"
                                                        role:@"client"];
    [hosts addObject:client1];
    
    WGSimulatedHost *client2 = [WGSimulatedHost hostWithName:@"Client Device 2"
                                                          ip:@"192.168.1.102"
                                                         mac:@"AA:BB:CC:DD:EE:12"
                                                        role:@"client"];
    [hosts addObject:client2];
    
    self.currentState.hosts = hosts;
    
    // Initialize clean ARP tables
    self.currentState.victimARPTable[@"192.168.1.1"] = @"AA:BB:CC:DD:EE:01";   // Gateway
    self.currentState.victimARPTable[@"192.168.1.50"] = @"AA:BB:CC:DD:EE:05";  // Attacker
    
    self.currentState.gatewayARPTable[@"192.168.1.100"] = @"AA:BB:CC:DD:EE:10"; // Victim
    self.currentState.gatewayARPTable[@"192.168.1.50"] = @"AA:BB:CC:DD:EE:05";  // Attacker
    
    // Log initial state
    WGSimulationEvent *initEvent = [WGSimulationEvent eventWithType:@"INIT"
                                                         description:@"Simulation initialized with clean network state"];
    [self.currentState.eventLog addObject:initEvent];
}

#pragma mark - Simulation Execution

- (void)simulationTick {
    self.currentState.elapsedTime += 1.0;
    self.currentStep++;
    
    switch (self.currentScenario) {
        case WGSimulationScenarioBasicARPSpoof:
            [self executeBasicARPSpoofStep];
            break;
        case WGSimulationScenarioMITMAttack:
            [self executeMITMAttackStep];
            break;
        case WGSimulationScenarioDuplicateMAC:
            [self executeDuplicateMACStep];
            break;
        case WGSimulationScenarioRapidChanges:
            [self executeRapidChangesStep];
            break;
        case WGSimulationScenarioGratuitousARP:
            [self executeGratuitousARPStep];
            break;
        default:
            break;
    }
    
    // Notify delegate of state update
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate simulationStateDidUpdate:self.currentState];
    });
}

#pragma mark - Scenario Execution: Basic ARP Spoof

- (void)executeBasicARPSpoofStep {
    switch (self.currentStep) {
        case 1: {
            // Normal network traffic
            WGSimulationEvent *event = [WGSimulationEvent eventWithType:@"NORMAL_TRAFFIC"
                description:@"📶 Normal network traffic: Victim communicates with gateway"];
            [self.currentState.eventLog addObject:event];
            [self notifyEvent:event];
            break;
        }
        case 2: {
            // Attacker prepares
            WGSimulationEvent *event = [WGSimulationEvent eventWithType:@"ATTACK_PREP"
                description:@"🔍 Attacker scans network and identifies gateway (192.168.1.1)"];
            event.sourceIP = @"192.168.1.50";
            event.sourceMAC = @"AA:BB:CC:DD:EE:05";
            [self.currentState.eventLog addObject:event];
            [self notifyEvent:event];
            break;
        }
        case 3: {
            // Attacker sends spoofed ARP reply
            WGSimulationEvent *event = [WGSimulationEvent eventWithType:@"SPOOFED_ARP"
                description:@"⚠️ Attacker sends spoofed ARP reply: 'I am 192.168.1.1' with attacker's MAC"];
            event.sourceIP = @"192.168.1.50";
            event.sourceMAC = @"AA:BB:CC:DD:EE:05";
            event.targetIP = @"192.168.1.100";
            event.isMalicious = YES;
            self.currentState.attackInProgress = YES;
            [self.currentState.eventLog addObject:event];
            [self notifyEvent:event];
            break;
        }
        case 4: {
            // Victim's ARP table poisoned
            self.currentState.victimARPTable[@"192.168.1.1"] = @"AA:BB:CC:DD:EE:05"; // Changed!
            
            WGSimulationEvent *event = [WGSimulationEvent eventWithType:@"ARP_POISONED"
                description:@"🚨 VICTIM'S ARP TABLE POISONED: Gateway MAC now points to attacker!"];
            event.isMalicious = YES;
            event.targetIP = @"192.168.1.1";
            event.targetMAC = @"AA:BB:CC:DD:EE:05";
            [self.currentState.eventLog addObject:event];
            [self notifyEvent:event];
            break;
        }
        case 5: {
            // Traffic interception
            WGSimulationEvent *event = [WGSimulationEvent eventWithType:@"TRAFFIC_INTERCEPTED"
                description:@"📨 Victim's traffic to gateway now goes to attacker"];
            event.isMalicious = YES;
            [self.currentState.eventLog addObject:event];
            [self notifyEvent:event];
            break;
        }
        case 6: {
            // Detection event
            WGSimulationEvent *event = [WGSimulationEvent eventWithType:@"DETECTED"
                description:@"✅ WiFiGuard DETECTED: Gateway MAC changed from AA:BB:CC:DD:EE:01 to AA:BB:CC:DD:EE:05"];
            [self.currentState.eventLog addObject:event];
            [self notifyEvent:event];
            break;
        }
        case 7: {
            // Simulation complete
            [self completeSimulation];
            break;
        }
    }
}

#pragma mark - Scenario Execution: MITM Attack

- (void)executeMITMAttackStep {
    switch (self.currentStep) {
        case 1: {
            WGSimulationEvent *event = [WGSimulationEvent eventWithType:@"NORMAL_STATE"
                description:@"📶 Initial state: Victim and Gateway have correct ARP entries"];
            [self.currentState.eventLog addObject:event];
            [self notifyEvent:event];
            break;
        }
        case 2: {
            WGSimulationEvent *event = [WGSimulationEvent eventWithType:@"MITM_START"
                description:@"🔍 Attacker initiates MITM: Will poison both victim AND gateway"];
            event.sourceIP = @"192.168.1.50";
            event.isMalicious = YES;
            [self.currentState.eventLog addObject:event];
            [self notifyEvent:event];
            break;
        }
        case 3: {
            // Poison victim
            self.currentState.victimARPTable[@"192.168.1.1"] = @"AA:BB:CC:DD:EE:05";
            
            WGSimulationEvent *event = [WGSimulationEvent eventWithType:@"VICTIM_POISONED"
                description:@"⚠️ Victim poisoned: Gateway points to attacker MAC"];
            event.isMalicious = YES;
            self.currentState.attackInProgress = YES;
            [self.currentState.eventLog addObject:event];
            [self notifyEvent:event];
            break;
        }
        case 4: {
            // Poison gateway
            self.currentState.gatewayARPTable[@"192.168.1.100"] = @"AA:BB:CC:DD:EE:05";
            
            WGSimulationEvent *event = [WGSimulationEvent eventWithType:@"GATEWAY_POISONED"
                description:@"⚠️ Gateway poisoned: Victim IP points to attacker MAC"];
            event.isMalicious = YES;
            [self.currentState.eventLog addObject:event];
            [self notifyEvent:event];
            break;
        }
        case 5: {
            WGSimulationEvent *event = [WGSimulationEvent eventWithType:@"MITM_ACTIVE"
                description:@"🚨 FULL MITM ACTIVE: All traffic between victim and gateway flows through attacker"];
            event.isMalicious = YES;
            [self.currentState.eventLog addObject:event];
            [self notifyEvent:event];
            break;
        }
        case 6: {
            WGSimulationEvent *event = [WGSimulationEvent eventWithType:@"DATA_INTERCEPTED"
                description:@"📧 Attacker can read/modify: HTTP traffic, DNS queries, unencrypted data"];
            event.isMalicious = YES;
            [self.currentState.eventLog addObject:event];
            [self notifyEvent:event];
            break;
        }
        case 7: {
            WGSimulationEvent *event = [WGSimulationEvent eventWithType:@"DETECTED"
                description:@"✅ WiFiGuard DETECTED multiple anomalies: Gateway MAC change + Duplicate MAC for multiple IPs"];
            [self.currentState.eventLog addObject:event];
            [self notifyEvent:event];
            break;
        }
        case 8: {
            [self completeSimulation];
            break;
        }
    }
}

#pragma mark - Scenario Execution: Duplicate MAC

- (void)executeDuplicateMACStep {
    switch (self.currentStep) {
        case 1: {
            WGSimulationEvent *event = [WGSimulationEvent eventWithType:@"NORMAL_STATE"
                description:@"📶 Normal state: Each IP has unique MAC address"];
            [self.currentState.eventLog addObject:event];
            [self notifyEvent:event];
            break;
        }
        case 2: {
            // Attacker claims gateway IP
            self.currentState.victimARPTable[@"192.168.1.1"] = @"AA:BB:CC:DD:EE:05";
            
            WGSimulationEvent *event = [WGSimulationEvent eventWithType:@"FIRST_SPOOF"
                description:@"⚠️ Attacker spoofs gateway IP (192.168.1.1) with own MAC"];
            event.isMalicious = YES;
            self.currentState.attackInProgress = YES;
            [self.currentState.eventLog addObject:event];
            [self notifyEvent:event];
            break;
        }
        case 3: {
            // Attacker claims another IP
            self.currentState.victimARPTable[@"192.168.1.101"] = @"AA:BB:CC:DD:EE:05";
            
            WGSimulationEvent *event = [WGSimulationEvent eventWithType:@"SECOND_SPOOF"
                description:@"⚠️ Attacker also spoofs client IP (192.168.1.101) with same MAC"];
            event.isMalicious = YES;
            [self.currentState.eventLog addObject:event];
            [self notifyEvent:event];
            break;
        }
        case 4: {
            WGSimulationEvent *event = [WGSimulationEvent eventWithType:@"DUPLICATE_DETECTED"
                description:@"🚨 ANOMALY: Same MAC (AA:BB:CC:DD:EE:05) now appears for multiple IPs!"];
            event.isMalicious = YES;
            [self.currentState.eventLog addObject:event];
            [self notifyEvent:event];
            break;
        }
        case 5: {
            WGSimulationEvent *event = [WGSimulationEvent eventWithType:@"DETECTED"
                description:@"✅ WiFiGuard DETECTED: Duplicate MAC anomaly - possible ARP spoofing"];
            [self.currentState.eventLog addObject:event];
            [self notifyEvent:event];
            break;
        }
        case 6: {
            [self completeSimulation];
            break;
        }
    }
}

#pragma mark - Scenario Execution: Rapid Changes

- (void)executeRapidChangesStep {
    if (self.currentStep <= 10) {
        // Simulate rapid MAC changes
        NSString *randomMAC = [NSString stringWithFormat:@"XX:XX:XX:%02X:%02X:%02X",
                              arc4random_uniform(256), arc4random_uniform(256), arc4random_uniform(256)];
        self.currentState.victimARPTable[@"192.168.1.1"] = randomMAC;
        self.currentState.attackInProgress = YES;
        
        WGSimulationEvent *event = [WGSimulationEvent eventWithType:@"RAPID_CHANGE"
            description:[NSString stringWithFormat:@"⚠️ ARP change #%ld: Gateway MAC → %@", 
                        (long)self.currentStep, randomMAC]];
        event.isMalicious = YES;
        [self.currentState.eventLog addObject:event];
        [self notifyEvent:event];
    } else if (self.currentStep == 11) {
        WGSimulationEvent *event = [WGSimulationEvent eventWithType:@"DETECTED"
            description:@"✅ WiFiGuard DETECTED: Rapid ARP table changes - possible ARP flood attack"];
        [self.currentState.eventLog addObject:event];
        [self notifyEvent:event];
    } else if (self.currentStep == 12) {
        [self completeSimulation];
    }
}

#pragma mark - Scenario Execution: Gratuitous ARP

- (void)executeGratuitousARPStep {
    switch (self.currentStep) {
        case 1: {
            WGSimulationEvent *event = [WGSimulationEvent eventWithType:@"INFO"
                description:@"ℹ️ Gratuitous ARP: Unsolicited ARP reply used to update network caches"];
            [self.currentState.eventLog addObject:event];
            [self notifyEvent:event];
            break;
        }
        case 2: {
            WGSimulationEvent *event = [WGSimulationEvent eventWithType:@"LEGITIMATE_GARP"
                description:@"📶 Legitimate use: Device announces its presence after IP change"];
            [self.currentState.eventLog addObject:event];
            [self notifyEvent:event];
            break;
        }
        case 3: {
            WGSimulationEvent *event = [WGSimulationEvent eventWithType:@"MALICIOUS_GARP"
                description:@"⚠️ Attacker sends gratuitous ARP: 'I am the gateway'"];
            event.isMalicious = YES;
            self.currentState.attackInProgress = YES;
            [self.currentState.eventLog addObject:event];
            [self notifyEvent:event];
            break;
        }
        case 4: {
            self.currentState.victimARPTable[@"192.168.1.1"] = @"AA:BB:CC:DD:EE:05";
            
            WGSimulationEvent *event = [WGSimulationEvent eventWithType:@"CACHE_UPDATED"
                description:@"🚨 All devices accepting gratuitous ARP update their caches"];
            event.isMalicious = YES;
            [self.currentState.eventLog addObject:event];
            [self notifyEvent:event];
            break;
        }
        case 5: {
            WGSimulationEvent *event = [WGSimulationEvent eventWithType:@"DETECTED"
                description:@"✅ WiFiGuard DETECTED: Unexpected gateway MAC change via gratuitous ARP"];
            [self.currentState.eventLog addObject:event];
            [self notifyEvent:event];
            break;
        }
        case 6: {
            [self completeSimulation];
            break;
        }
    }
}

#pragma mark - Helpers

- (void)notifyEvent:(WGSimulationEvent *)event {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate simulationDidGenerateEvent:event];
    });
}

- (void)completeSimulation {
    [self.simulationTimer invalidate];
    self.simulationTimer = nil;
    self.isRunning = NO;
    self.currentState.attackInProgress = NO;
    
    NSDictionary *summary = @{
        @"scenario": [WGSimulationEngine scenarioName:self.currentScenario],
        @"duration": @(self.currentState.elapsedTime),
        @"eventCount": @(self.currentState.eventLog.count),
        @"finalVictimARP": [self.currentState.victimARPTable copy],
        @"finalGatewayARP": [self.currentState.gatewayARPTable copy],
        @"educational": @"This was a SIMULATION only. No real attacks were performed."
    };
    
    [self.auditLogger logEvent:@"SIMULATION_COMPLETED" 
                       details:[NSString stringWithFormat:@"Scenario: %@, Duration: %.0fs",
                               summary[@"scenario"], self.currentState.elapsedTime]];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate simulationDidComplete:self.currentScenario withSummary:summary];
    });
}

#pragma mark - Data Access

- (NSArray<WGSimulationEvent *> *)eventLog {
    return [self.currentState.eventLog copy];
}

- (NSDictionary *)currentARPTables {
    return @{
        @"victimARP": [self.currentState.victimARPTable copy],
        @"gatewayARP": [self.currentState.gatewayARPTable copy]
    };
}

- (NSArray<WGSimulatedHost *> *)simulatedHosts {
    return self.currentState.hosts;
}

#pragma mark - Export

- (NSDictionary *)exportSimulationResults {
    NSMutableArray *events = [NSMutableArray array];
    for (WGSimulationEvent *event in self.currentState.eventLog) {
        [events addObject:@{
            @"timestamp": event.timestamp.description,
            @"type": event.eventType ?: @"",
            @"description": event.description ?: @"",
            @"isMalicious": @(event.isMalicious)
        }];
    }
    
    return @{
        @"scenario": [WGSimulationEngine scenarioName:self.currentScenario],
        @"scenarioDescription": [WGSimulationEngine scenarioDescription:self.currentScenario],
        @"duration": @(self.currentState.elapsedTime),
        @"events": events,
        @"finalState": @{
            @"victimARPTable": self.currentState.victimARPTable,
            @"gatewayARPTable": self.currentState.gatewayARPTable
        },
        @"disclaimer": @"EDUCATIONAL SIMULATION ONLY - NO REAL ATTACKS WERE PERFORMED"
    };
}

@end
