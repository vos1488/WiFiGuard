/*
 * WGSimulationEngine.h - Educational Simulation Mode
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 * 
 * SIMULATION ONLY - NO REAL ATTACKS
 * 
 * This module provides EDUCATIONAL demonstrations of ARP spoofing effects
 * using SIMULATED data. It does NOT:
 *   - Send any real network packets
 *   - Modify any real ARP tables
 *   - Perform any actual attacks
 *   - Use real network interfaces for attacks
 * 
 * The simulation uses pre-defined scenarios and artificial data to
 * demonstrate what ARP spoofing looks like for educational purposes.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class WGAuditLogger;

// Simulation Scenario Types
typedef NS_ENUM(NSInteger, WGSimulationScenario) {
    WGSimulationScenarioNone = 0,
    WGSimulationScenarioBasicARPSpoof,      // Basic gateway MAC change
    WGSimulationScenarioMITMAttack,          // Simulated MITM scenario
    WGSimulationScenarioDuplicateMAC,        // Multiple IPs same MAC
    WGSimulationScenarioRapidChanges,        // Fast ARP table changes
    WGSimulationScenarioGratuitousARP        // Gratuitous ARP flood
};

// Simulated Network Entity
@interface WGSimulatedHost : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *ipAddress;
@property (nonatomic, copy) NSString *macAddress;
@property (nonatomic, copy) NSString *role; // "victim", "gateway", "attacker", "client"
@property (nonatomic, assign) BOOL isCompromised;

+ (instancetype)hostWithName:(NSString *)name ip:(NSString *)ip mac:(NSString *)mac role:(NSString *)role;

@end

// Simulation Event
@interface WGSimulationEvent : NSObject

@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, copy) NSString *eventType;
@property (nonatomic, copy) NSString *sourceIP;
@property (nonatomic, copy) NSString *sourceMAC;
@property (nonatomic, copy) NSString *targetIP;
@property (nonatomic, copy) NSString *targetMAC;
@property (nonatomic, copy) NSString *description;
@property (nonatomic, assign) BOOL isMalicious;

@end

// Simulation State
@interface WGSimulationState : NSObject

@property (nonatomic, strong) NSArray<WGSimulatedHost *> *hosts;
@property (nonatomic, strong) NSMutableArray<WGSimulationEvent *> *eventLog;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *victimARPTable;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *gatewayARPTable;
@property (nonatomic, assign) WGSimulationScenario activeScenario;
@property (nonatomic, assign) BOOL attackInProgress;
@property (nonatomic, assign) NSTimeInterval elapsedTime;

@end

// Delegate Protocol
@protocol WGSimulationEngineDelegate <NSObject>
@optional
- (void)simulationDidStart:(WGSimulationScenario)scenario;
- (void)simulationDidStop;
- (void)simulationDidGenerateEvent:(WGSimulationEvent *)event;
- (void)simulationStateDidUpdate:(WGSimulationState *)state;
- (void)simulationDidComplete:(WGSimulationScenario)scenario withSummary:(NSDictionary *)summary;
@end

// Main Simulation Engine
@interface WGSimulationEngine : NSObject

@property (nonatomic, weak, nullable) id<WGSimulationEngineDelegate> delegate;
@property (nonatomic, readonly) BOOL isRunning;
@property (nonatomic, readonly) WGSimulationState *currentState;
@property (nonatomic, readonly) WGSimulationScenario currentScenario;

// Initialization
- (instancetype)initWithAuditLogger:(WGAuditLogger *)logger;

// Simulation Control
- (BOOL)startSimulation:(WGSimulationScenario)scenario;
- (void)stopSimulation;
- (void)pauseSimulation;
- (void)resumeSimulation;
- (void)stepForward; // Manual step through simulation

// Scenario Information
+ (NSString *)scenarioName:(WGSimulationScenario)scenario;
+ (NSString *)scenarioDescription:(WGSimulationScenario)scenario;
+ (NSArray<NSNumber *> *)availableScenarios;

// Data Access
- (NSArray<WGSimulationEvent *> *)eventLog;
- (NSDictionary *)currentARPTables;
- (NSArray<WGSimulatedHost *> *)simulatedHosts;

// Export
- (NSDictionary *)exportSimulationResults;

@end

NS_ASSUME_NONNULL_END
