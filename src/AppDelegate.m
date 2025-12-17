//
//  AppDelegate.m
//  WiFiGuard
//
//  Application delegate for WiFiGuard
//

#import "AppDelegate.h"
#import "WGMainViewController.h"
#import "WGDisclaimerView.h"
#import "WGWiFiScanner.h"
#import "WGARPDetector.h"
#import "WGAuditLogger.h"
#import "WGSecureStorage.h"

static AppDelegate *_sharedInstance = nil;

@interface AppDelegate ()
@property (nonatomic, assign) BOOL disclaimerAccepted;
@property (nonatomic, strong) UILongPressGestureRecognizer *killSwitchGesture;
@end

@implementation AppDelegate

#pragma mark - Shared Instance

+ (instancetype)sharedInstance {
    return _sharedInstance;
}

#pragma mark - Application Lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    _sharedInstance = self;
    
    // Initialize audit logger
    [[WGAuditLogger sharedInstance] logEvent:@"APP_LAUNCH" details:@"WiFiGuard started"];
    
    // Create main window
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor systemBackgroundColor];
    
    // Create main view controller
    self.mainViewController = [[WGMainViewController alloc] init];
    self.navigationController = [[UINavigationController alloc] initWithRootViewController:self.mainViewController];
    
    // Configure navigation bar appearance
    if (@available(iOS 15.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundColor = [UIColor systemBackgroundColor];
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    }
    
    self.window.rootViewController = self.navigationController;
    [self.window makeKeyAndVisible];
    
    // Setup kill switch gesture (3-finger long press anywhere)
    [self setupKillSwitchGesture];
    
    // Check if disclaimer needs to be shown
    self.disclaimerAccepted = [[NSUserDefaults standardUserDefaults] boolForKey:@"WGDisclaimerAccepted"];
    
    if (!self.disclaimerAccepted) {
        [self showDisclaimerView];
    }
    
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [[WGAuditLogger sharedInstance] logEvent:@"APP_ACTIVE" details:@"Application became active"];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    [[WGAuditLogger sharedInstance] logEvent:@"APP_INACTIVE" details:@"Application will resign active"];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [[WGAuditLogger sharedInstance] logEvent:@"APP_BACKGROUND" details:@"Application entered background"];
    
    // Stop scanning when entering background
    if ([[WGWiFiScanner sharedInstance] isScanning]) {
        [[WGWiFiScanner sharedInstance] stopScanning];
    }
    
    if ([[WGARPDetector sharedInstance] isMonitoring]) {
        [[WGARPDetector sharedInstance] stopMonitoring];
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    [[WGAuditLogger sharedInstance] logEvent:@"APP_FOREGROUND" details:@"Application will enter foreground"];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [[WGAuditLogger sharedInstance] logEvent:@"APP_TERMINATE" details:@"Application will terminate"];
    [[WGAuditLogger sharedInstance] endSession];
}

#pragma mark - Kill Switch

- (void)setupKillSwitchGesture {
    self.killSwitchGesture = [[UILongPressGestureRecognizer alloc] 
                               initWithTarget:self 
                               action:@selector(killSwitchTriggered:)];
    self.killSwitchGesture.numberOfTouchesRequired = 3;
    self.killSwitchGesture.minimumPressDuration = 2.0;
    [self.window addGestureRecognizer:self.killSwitchGesture];
}

- (void)killSwitchTriggered:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [self activateKillSwitch];
    }
}

- (void)activateKillSwitch {
    [[WGAuditLogger sharedInstance] logEvent:@"KILL_SWITCH" details:@"Emergency kill switch activated"];
    
    // Stop all operations immediately
    [[WGWiFiScanner sharedInstance] stopScanning];
    [[WGARPDetector sharedInstance] stopMonitoring];
    
    // Show confirmation alert
    UIAlertController *alert = [UIAlertController 
        alertControllerWithTitle:@"⚠️ Kill Switch Activated"
        message:@"All scanning operations have been stopped.\n\nDo you want to securely delete all collected data?"
        preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Delete All Data" 
                                              style:UIAlertActionStyleDestructive 
                                            handler:^(UIAlertAction *action) {
        [self deleteAllData];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Keep Data" 
                                              style:UIAlertActionStyleCancel 
                                            handler:nil]];
    
    [self.navigationController presentViewController:alert animated:YES completion:nil];
}

- (void)deleteAllData {
    [[WGAuditLogger sharedInstance] logEvent:@"DATA_DELETION" details:@"User initiated secure data deletion"];
    
    // Securely delete all data files
    NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *files = [fm contentsOfDirectoryAtPath:documentsPath error:nil];
    
    for (NSString *file in files) {
        NSString *filePath = [documentsPath stringByAppendingPathComponent:file];
        [WGSecureStorage secureDeleteFile:filePath];
    }
    
    // Clear preferences
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"WGDisclaimerAccepted"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    self.disclaimerAccepted = NO;
    
    // Show confirmation
    UIAlertController *confirm = [UIAlertController 
        alertControllerWithTitle:@"Data Deleted"
        message:@"All data has been securely deleted."
        preferredStyle:UIAlertControllerStyleAlert];
    
    [confirm addAction:[UIAlertAction actionWithTitle:@"OK" 
                                                style:UIAlertActionStyleDefault 
                                              handler:^(UIAlertAction *action) {
        [self showDisclaimerView];
    }]];
    
    [self.navigationController presentViewController:confirm animated:YES completion:nil];
}

#pragma mark - Disclaimer

- (void)showDisclaimerView {
    WGDisclaimerView *disclaimerView = [[WGDisclaimerView alloc] initWithFrame:self.window.bounds];
    disclaimerView.tag = 9999;
    
    __weak typeof(self) weakSelf = self;
    disclaimerView.onAccept = ^{
        [weakSelf setDisclaimerAccepted:YES];
        UIView *view = [weakSelf.window viewWithTag:9999];
        [UIView animateWithDuration:0.3 animations:^{
            view.alpha = 0;
        } completion:^(BOOL finished) {
            [view removeFromSuperview];
        }];
    };
    
    disclaimerView.onDecline = ^{
        [[WGAuditLogger sharedInstance] logEvent:@"DISCLAIMER_DECLINED" details:@"User declined disclaimer"];
        exit(0);
    };
    
    disclaimerView.alpha = 0;
    [self.window addSubview:disclaimerView];
    
    [UIView animateWithDuration:0.3 animations:^{
        disclaimerView.alpha = 1;
    }];
}

- (BOOL)isDisclaimerAccepted {
    return self.disclaimerAccepted;
}

- (void)setDisclaimerAccepted:(BOOL)accepted {
    _disclaimerAccepted = accepted;
    [[NSUserDefaults standardUserDefaults] setBool:accepted forKey:@"WGDisclaimerAccepted"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if (accepted) {
        [[WGAuditLogger sharedInstance] logEvent:@"DISCLAIMER_ACCEPTED" 
                                         details:@"User accepted terms and confirmed network ownership"];
    }
}

@end
