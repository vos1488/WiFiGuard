/*
 * WGMainViewController.m - Main Interface Implementation
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 */

#import "WGMainViewController.h"
#import "WGScanResultsView.h"
#import "WGRSSIGraphView.h"
#import "WGChannelSummaryView.h"
#import "WGARPAlertView.h"
#import "WGSettingsViewController.h"
#import "../Core/WGWiFiScanner.h"
#import "../Core/WGARPDetector.h"
#import "../Core/WGAuditLogger.h"
#import "../Core/WGDataExporter.h"
#import "../Core/WGSimulationEngine.h"

@interface WGMainViewController () <UITableViewDelegate, UITableViewDataSource, 
                                     WGWiFiScannerDelegate, WGARPDetectorDelegate>

@property (nonatomic, strong) UISegmentedControl *segmentControl;
@property (nonatomic, strong) UITableView *networksTableView;
@property (nonatomic, strong) WGRSSIGraphView *rssiGraphView;
@property (nonatomic, strong) WGChannelSummaryView *channelView;
@property (nonatomic, strong) UIView *arpAlertBanner;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *startStopButton;
@property (nonatomic, strong) UIButton *killSwitchButton;

@property (nonatomic, strong) NSArray<WGNetworkInfo *> *networks;
@property (nonatomic, assign) BOOL isMonitoring;

@end

@implementation WGMainViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"WiFiGuard";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    [self setupNavigationBar];
    [self setupUI];
    [self setupDelegates];
    
    self.networks = @[];
    self.isMonitoring = NO;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // Ensure monitoring is stopped when view is dismissed
    if (self.isMonitoring) {
        [self stopMonitoring];
    }
}

#pragma mark - Setup

- (void)setupNavigationBar {
    // Settings button on the right
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"gear"]
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(settingsButtonTapped)];
    
    // Title with icon
    self.navigationItem.title = @"WiFiGuard";
}

- (void)setupUI {
    // Status bar
    UIView *statusBar = [[UIView alloc] init];
    statusBar.translatesAutoresizingMaskIntoConstraints = NO;
    statusBar.backgroundColor = [UIColor systemGray6Color];
    statusBar.layer.cornerRadius = 8;
    [self.view addSubview:statusBar];
    
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.text = @"⚪ Monitoring: OFF";
    self.statusLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [statusBar addSubview:self.statusLabel];
    
    // Segment control
    self.segmentControl = [[UISegmentedControl alloc] initWithItems:@[@"Networks", @"RSSI Graph", @"Channels", @"ARP"]];
    self.segmentControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.segmentControl.selectedSegmentIndex = 0;
    [self.segmentControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.segmentControl];
    
    // Networks table
    self.networksTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.networksTableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.networksTableView.delegate = self;
    self.networksTableView.dataSource = self;
    [self.networksTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"NetworkCell"];
    [self.view addSubview:self.networksTableView];
    
    // RSSI Graph View
    self.rssiGraphView = [[WGRSSIGraphView alloc] init];
    self.rssiGraphView.translatesAutoresizingMaskIntoConstraints = NO;
    self.rssiGraphView.hidden = YES;
    [self.view addSubview:self.rssiGraphView];
    
    // Channel Summary View
    self.channelView = [[WGChannelSummaryView alloc] init];
    self.channelView.translatesAutoresizingMaskIntoConstraints = NO;
    self.channelView.hidden = YES;
    [self.view addSubview:self.channelView];
    
    // ARP Alert Banner (initially hidden)
    self.arpAlertBanner = [[UIView alloc] init];
    self.arpAlertBanner.translatesAutoresizingMaskIntoConstraints = NO;
    self.arpAlertBanner.backgroundColor = [UIColor systemRedColor];
    self.arpAlertBanner.layer.cornerRadius = 8;
    self.arpAlertBanner.hidden = YES;
    [self.view addSubview:self.arpAlertBanner];
    
    UILabel *arpAlertLabel = [[UILabel alloc] init];
    arpAlertLabel.translatesAutoresizingMaskIntoConstraints = NO;
    arpAlertLabel.text = @"⚠️ ARP Anomaly Detected!";
    arpAlertLabel.textColor = [UIColor whiteColor];
    arpAlertLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    arpAlertLabel.tag = 100;
    [self.arpAlertBanner addSubview:arpAlertLabel];
    
    // Control buttons
    UIStackView *buttonStack = [[UIStackView alloc] init];
    buttonStack.translatesAutoresizingMaskIntoConstraints = NO;
    buttonStack.axis = UILayoutConstraintAxisHorizontal;
    buttonStack.spacing = 12;
    buttonStack.distribution = UIStackViewDistributionFillEqually;
    [self.view addSubview:buttonStack];
    
    self.startStopButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.startStopButton setTitle:@"▶️ Start Monitoring" forState:UIControlStateNormal];
    self.startStopButton.backgroundColor = [UIColor systemGreenColor];
    [self.startStopButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.startStopButton.layer.cornerRadius = 8;
    [self.startStopButton addTarget:self action:@selector(startStopButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [buttonStack addArrangedSubview:self.startStopButton];
    
    self.killSwitchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.killSwitchButton setTitle:@"🛑 Kill Switch" forState:UIControlStateNormal];
    self.killSwitchButton.backgroundColor = [UIColor systemRedColor];
    [self.killSwitchButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.killSwitchButton.layer.cornerRadius = 8;
    [self.killSwitchButton addTarget:self action:@selector(killSwitchTapped) forControlEvents:UIControlEventTouchUpInside];
    [buttonStack addArrangedSubview:self.killSwitchButton];
    
    // Layout constraints
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    
    [NSLayoutConstraint activateConstraints:@[
        // Status bar
        [statusBar.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:8],
        [statusBar.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:16],
        [statusBar.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-16],
        [statusBar.heightAnchor constraintEqualToConstant:36],
        
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:statusBar.centerYAnchor],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:statusBar.leadingAnchor constant:12],
        
        // ARP Alert Banner
        [self.arpAlertBanner.topAnchor constraintEqualToAnchor:statusBar.bottomAnchor constant:8],
        [self.arpAlertBanner.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:16],
        [self.arpAlertBanner.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-16],
        [self.arpAlertBanner.heightAnchor constraintEqualToConstant:40],
        
        [arpAlertLabel.centerYAnchor constraintEqualToAnchor:self.arpAlertBanner.centerYAnchor],
        [arpAlertLabel.centerXAnchor constraintEqualToAnchor:self.arpAlertBanner.centerXAnchor],
        
        // Segment control
        [self.segmentControl.topAnchor constraintEqualToAnchor:statusBar.bottomAnchor constant:16],
        [self.segmentControl.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:16],
        [self.segmentControl.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-16],
        
        // Table view
        [self.networksTableView.topAnchor constraintEqualToAnchor:self.segmentControl.bottomAnchor constant:8],
        [self.networksTableView.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor],
        [self.networksTableView.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor],
        [self.networksTableView.bottomAnchor constraintEqualToAnchor:buttonStack.topAnchor constant:-8],
        
        // RSSI Graph View (same constraints as table)
        [self.rssiGraphView.topAnchor constraintEqualToAnchor:self.segmentControl.bottomAnchor constant:8],
        [self.rssiGraphView.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:16],
        [self.rssiGraphView.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-16],
        [self.rssiGraphView.bottomAnchor constraintEqualToAnchor:buttonStack.topAnchor constant:-8],
        
        // Channel View
        [self.channelView.topAnchor constraintEqualToAnchor:self.segmentControl.bottomAnchor constant:8],
        [self.channelView.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:16],
        [self.channelView.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-16],
        [self.channelView.bottomAnchor constraintEqualToAnchor:buttonStack.topAnchor constant:-8],
        
        // Button stack
        [buttonStack.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:16],
        [buttonStack.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-16],
        [buttonStack.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor constant:-8],
        [buttonStack.heightAnchor constraintEqualToConstant:50]
    ]];
}

- (void)setupDelegates {
    // Initialize singletons if needed
    if (!self.wifiScanner) {
        self.wifiScanner = [WGWiFiScanner sharedInstance];
    }
    if (!self.arpDetector) {
        self.arpDetector = [WGARPDetector sharedInstance];
    }
    if (!self.auditLogger) {
        self.auditLogger = [WGAuditLogger sharedInstance];
    }
    
    self.wifiScanner.delegate = self;
    self.arpDetector.delegate = self;
}

#pragma mark - Actions

- (void)settingsButtonTapped {
    WGSettingsViewController *settingsVC = [[WGSettingsViewController alloc] init];
    settingsVC.wifiScanner = self.wifiScanner;
    settingsVC.arpDetector = self.arpDetector;
    settingsVC.auditLogger = self.auditLogger;
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    self.networksTableView.hidden = sender.selectedSegmentIndex != 0;
    self.rssiGraphView.hidden = sender.selectedSegmentIndex != 1;
    self.channelView.hidden = sender.selectedSegmentIndex != 2;
    
    if (sender.selectedSegmentIndex == 3) {
        // Show ARP details
        [self showARPDetails];
    }
}

- (void)startStopButtonTapped {
    if (self.isMonitoring) {
        [self stopMonitoring];
    } else {
        [self startMonitoring];
    }
}

- (void)startMonitoring {
    self.isMonitoring = YES;
    
    [self.wifiScanner startScanning];
    [self.arpDetector startMonitoring];
    
    [self.auditLogger logMonitoringStart];
    
    [self updateUIForMonitoringState];
}

- (void)stopMonitoring {
    self.isMonitoring = NO;
    
    [self.wifiScanner stopScanning];
    [self.arpDetector stopMonitoring];
    
    [self.auditLogger logMonitoringStop];
    
    [self updateUIForMonitoringState];
}

- (void)killSwitchTapped {
    UIAlertController *alert = [UIAlertController 
        alertControllerWithTitle:@"🛑 Kill Switch"
        message:@"This will immediately stop all monitoring and securely delete temporary files. Continue?"
        preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Activate Kill Switch" 
                                              style:UIAlertActionStyleDestructive 
                                            handler:^(UIAlertAction *action) {
        // Send kill switch notification
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFSTR("com.wifiguard.killswitch"),
            NULL, NULL, YES);
        
        self.isMonitoring = NO;
        [self updateUIForMonitoringState];
        
        // Show confirmation
        UIAlertController *confirm = [UIAlertController 
            alertControllerWithTitle:@"✅ Kill Switch Activated"
            message:@"All monitoring stopped. Temporary files deleted."
            preferredStyle:UIAlertControllerStyleAlert];
        [confirm addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:confirm animated:YES completion:nil];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" 
                                              style:UIAlertActionStyleCancel 
                                            handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)updateUIForMonitoringState {
    if (self.isMonitoring) {
        self.statusLabel.text = @"🟢 Monitoring: ON";
        [self.startStopButton setTitle:@"⏹ Stop Monitoring" forState:UIControlStateNormal];
        self.startStopButton.backgroundColor = [UIColor systemOrangeColor];
    } else {
        self.statusLabel.text = @"⚪ Monitoring: OFF";
        [self.startStopButton setTitle:@"▶️ Start Monitoring" forState:UIControlStateNormal];
        self.startStopButton.backgroundColor = [UIColor systemGreenColor];
    }
}

- (void)showARPDetails {
    UIAlertController *alert = [UIAlertController 
        alertControllerWithTitle:@"ARP Monitoring"
        message:[NSString stringWithFormat:@"Gateway IP: %@\nGateway MAC: %@\nAnomalies: %ld\n\nMonitoring: %@",
                self.arpDetector.gatewayIP ?: @"Unknown",
                [self.arpDetector gatewayMAC] ?: @"Unknown",
                (long)self.arpDetector.statistics.anomaliesDetected,
                self.arpDetector.isMonitoring ? @"Active" : @"Inactive"]
        preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"View Anomalies" 
                                              style:UIAlertActionStyleDefault 
                                            handler:^(UIAlertAction *action) {
        [self showAnomalies];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" 
                                              style:UIAlertActionStyleCancel 
                                            handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showAnomalies {
    NSArray *anomalies = self.arpDetector.detectedAnomalies;
    
    NSMutableString *message = [NSMutableString string];
    if (anomalies.count == 0) {
        [message appendString:@"No anomalies detected."];
    } else {
        for (WGARPAnomaly *anomaly in [anomalies reverseObjectEnumerator]) {
            [message appendFormat:@"%@\n\n", [anomaly localizedDescription]];
            if (message.length > 500) break; // Limit for alert
        }
    }
    
    UIAlertController *alert = [UIAlertController 
        alertControllerWithTitle:@"Detected Anomalies"
        message:message
        preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.networks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"NetworkCell" forIndexPath:indexPath];
    
    WGNetworkInfo *network = self.networks[indexPath.row];
    
    cell.textLabel.text = network.ssid ?: @"<Hidden Network>";
    cell.detailTextLabel.text = [NSString stringWithFormat:@"Ch:%ld RSSI:%ld %@",
                                 (long)network.channel, (long)network.rssi, network.securityType];
    
    // RSSI indicator
    if (network.rssi >= -50) {
        cell.imageView.image = [UIImage systemImageNamed:@"wifi"];
        cell.imageView.tintColor = [UIColor systemGreenColor];
    } else if (network.rssi >= -70) {
        cell.imageView.image = [UIImage systemImageNamed:@"wifi"];
        cell.imageView.tintColor = [UIColor systemYellowColor];
    } else {
        cell.imageView.image = [UIImage systemImageNamed:@"wifi.exclamationmark"];
        cell.imageView.tintColor = [UIColor systemRedColor];
    }
    
    if (network.isHidden) {
        cell.accessoryType = UITableViewCellAccessoryDetailButton;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [NSString stringWithFormat:@"Discovered Networks (%lu)", (unsigned long)self.networks.count];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    WGNetworkInfo *network = self.networks[indexPath.row];
    [self showNetworkDetails:network];
}

- (void)showNetworkDetails:(WGNetworkInfo *)network {
    NSString *message = [NSString stringWithFormat:
        @"SSID: %@\n"
        @"BSSID: %@\n"
        @"Channel: %ld (%@)\n"
        @"RSSI: %ld dBm\n"
        @"Width: %ld MHz\n"
        @"Security: %@\n"
        @"Hidden: %@\n"
        @"Last Seen: %@",
        network.ssid ?: @"<Hidden>",
        network.bssid,
        (long)network.channel,
        network.channel > 14 ? @"5 GHz" : @"2.4 GHz",
        (long)network.rssi,
        (long)network.channelWidth,
        network.securityType,
        network.isHidden ? @"Yes" : @"No",
        network.lastSeen];
    
    UIAlertController *alert = [UIAlertController 
        alertControllerWithTitle:@"Network Details"
        message:message
        preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Track RSSI" 
                                              style:UIAlertActionStyleDefault 
                                            handler:^(UIAlertAction *action) {
        [self.rssiGraphView trackNetwork:network];
        self.segmentControl.selectedSegmentIndex = 1;
        [self segmentChanged:self.segmentControl];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" 
                                              style:UIAlertActionStyleCancel 
                                            handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - WGWiFiScannerDelegate

- (void)wifiScanner:(WGWiFiScanner *)scanner didFindNetworks:(NSArray<WGNetworkInfo *> *)networks {
    self.networks = networks;
    [self.networksTableView reloadData];
    [self.channelView updateWithStatistics:scanner.channelStatistics];
}

- (void)wifiScanner:(WGWiFiScanner *)scanner didUpdateNetwork:(WGNetworkInfo *)network {
    [self.rssiGraphView updateNetwork:network];
}

- (void)wifiScanner:(WGWiFiScanner *)scanner didEncounterError:(NSError *)error {
    UIAlertController *alert = [UIAlertController 
        alertControllerWithTitle:@"Scan Error"
        message:error.localizedDescription
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - WGARPDetectorDelegate

- (void)arpDetector:(WGARPDetector *)detector didDetectAnomaly:(WGARPAnomaly *)anomaly {
    // Show alert banner
    self.arpAlertBanner.hidden = NO;
    UILabel *label = [self.arpAlertBanner viewWithTag:100];
    label.text = [NSString stringWithFormat:@"⚠️ %@", [anomaly localizedDescription]];
    
    // Auto-hide after 5 seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.arpAlertBanner.hidden = YES;
    });
    
    // Haptic feedback
    UINotificationFeedbackGenerator *feedback = [[UINotificationFeedbackGenerator alloc] init];
    [feedback notificationOccurred:UINotificationFeedbackTypeWarning];
}

- (void)arpDetector:(WGARPDetector *)detector didUpdateTable:(NSArray<WGARPEntry *> *)entries {
    // Update UI if needed
}

@end
