/*
 * WGSettingsViewController.m - Settings Implementation
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 */

#import "WGSettingsViewController.h"
#import "../Core/WGWiFiScanner.h"
#import "../Core/WGARPDetector.h"
#import "../Core/WGAuditLogger.h"
#import "../Core/WGDataExporter.h"
#import "../Core/WGSimulationEngine.h"
#import "../Utils/WGSecureStorage.h"

typedef NS_ENUM(NSInteger, WGSettingsSection) {
    WGSettingsSectionScan = 0,
    WGSettingsSectionARP,
    WGSettingsSectionExport,
    WGSettingsSectionSimulation,
    WGSettingsSectionData,
    WGSettingsSectionAbout,
    WGSettingsSectionCount
};

@interface WGSettingsViewController () <WGSimulationEngineDelegate>

@property (nonatomic, strong) WGSimulationEngine *simulationEngine;

@end

@implementation WGSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Settings";
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] 
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone 
        target:self 
        action:@selector(doneTapped)];
    
    self.simulationEngine = [[WGSimulationEngine alloc] initWithAuditLogger:self.auditLogger];
    self.simulationEngine.delegate = self;
}

- (void)doneTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return WGSettingsSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case WGSettingsSectionScan: return 2;
        case WGSettingsSectionARP: return 3;
        case WGSettingsSectionExport: return 3;
        case WGSettingsSectionSimulation: return 5;
        case WGSettingsSectionData: return 2;
        case WGSettingsSectionAbout: return 3;
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case WGSettingsSectionScan: return @"Scan Settings";
        case WGSettingsSectionARP: return @"ARP Detection";
        case WGSettingsSectionExport: return @"Export Data";
        case WGSettingsSectionSimulation: return @"Educational Simulation";
        case WGSettingsSectionData: return @"Data Management";
        case WGSettingsSectionAbout: return @"About";
        default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == WGSettingsSectionSimulation) {
        return @"⚠️ Simulation mode demonstrates ARP spoofing effects using SYNTHETIC data only. No real attacks are performed.";
    }
    if (section == WGSettingsSectionData) {
        return @"Secure delete overwrites data before deletion.";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 
                                                   reuseIdentifier:@"SettingsCell"];
    
    switch (indexPath.section) {
        case WGSettingsSectionScan: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Scan Interval";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.0f sec", self.wifiScanner.scanInterval];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            } else {
                cell.textLabel.text = @"Show Hidden Networks";
                UISwitch *toggle = [[UISwitch alloc] init];
                toggle.on = YES;
                cell.accessoryView = toggle;
            }
            break;
        }
        
        case WGSettingsSectionARP: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Alert on Gateway Change";
                UISwitch *toggle = [[UISwitch alloc] init];
                toggle.on = self.arpDetector.alertOnGatewayChange;
                toggle.tag = 100;
                [toggle addTarget:self action:@selector(arpToggleChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = toggle;
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"Alert on MAC Change";
                UISwitch *toggle = [[UISwitch alloc] init];
                toggle.on = self.arpDetector.alertOnMACChange;
                toggle.tag = 101;
                [toggle addTarget:self action:@selector(arpToggleChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = toggle;
            } else {
                cell.textLabel.text = @"Check Interval";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.0f sec", self.arpDetector.checkInterval];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
            break;
        }
        
        case WGSettingsSectionExport: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Export Networks (CSV)";
                cell.textLabel.textColor = [UIColor systemBlueColor];
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"Export ARP Log";
                cell.textLabel.textColor = [UIColor systemBlueColor];
            } else {
                cell.textLabel.text = @"Export All (Encrypted)";
                cell.textLabel.textColor = [UIColor systemBlueColor];
            }
            break;
        }
        
        case WGSettingsSectionSimulation: {
            NSArray *scenarios = @[@"Basic ARP Spoofing", @"MITM Attack", @"Duplicate MAC", 
                                   @"Rapid Changes", @"Gratuitous ARP"];
            cell.textLabel.text = scenarios[indexPath.row];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.imageView.image = [UIImage systemImageNamed:@"play.circle"];
            cell.imageView.tintColor = [UIColor systemOrangeColor];
            break;
        }
        
        case WGSettingsSectionData: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Clear Cache";
                cell.textLabel.textColor = [UIColor systemOrangeColor];
            } else {
                cell.textLabel.text = @"Secure Delete All Data";
                cell.textLabel.textColor = [UIColor systemRedColor];
            }
            break;
        }
        
        case WGSettingsSectionAbout: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Version";
                cell.detailTextLabel.text = @"1.0.0";
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"View Audit Log";
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            } else {
                cell.textLabel.text = @"View Disclaimer";
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
            break;
        }
    }
    
    return cell;
}

#pragma mark - Table View Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    switch (indexPath.section) {
        case WGSettingsSectionScan:
            if (indexPath.row == 0) {
                [self showScanIntervalPicker];
            }
            break;
            
        case WGSettingsSectionExport:
            [self handleExportAtIndex:indexPath.row];
            break;
            
        case WGSettingsSectionSimulation:
            [self startSimulation:indexPath.row + 1]; // +1 because enum starts at 1
            break;
            
        case WGSettingsSectionData:
            if (indexPath.row == 0) {
                [self clearCache];
            } else {
                [self secureDeleteAll];
            }
            break;
            
        case WGSettingsSectionAbout:
            if (indexPath.row == 1) {
                [self showAuditLog];
            } else if (indexPath.row == 2) {
                [self showDisclaimer];
            }
            break;
    }
}

#pragma mark - Actions

- (void)arpToggleChanged:(UISwitch *)sender {
    if (sender.tag == 100) {
        self.arpDetector.alertOnGatewayChange = sender.isOn;
    } else if (sender.tag == 101) {
        self.arpDetector.alertOnMACChange = sender.isOn;
    }
}

- (void)showScanIntervalPicker {
    UIAlertController *alert = [UIAlertController 
        alertControllerWithTitle:@"Scan Interval"
        message:@"Select scan interval in seconds"
        preferredStyle:UIAlertControllerStyleActionSheet];
    
    for (NSNumber *interval in @[@3, @5, @10, @30]) {
        [alert addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@ seconds", interval]
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            self.wifiScanner.scanInterval = interval.doubleValue;
            [self.tableView reloadData];
        }]];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)handleExportAtIndex:(NSInteger)index {
    WGDataExporter *exporter = [[WGDataExporter alloc] initWithScanner:self.wifiScanner
                                                           arpDetector:self.arpDetector
                                                           auditLogger:self.auditLogger];
    
    NSString *exportDir = [exporter defaultExportDirectory];
    NSError *error;
    
    if (index == 2) {
        // Encrypted export - ask for password
        UIAlertController *alert = [UIAlertController 
            alertControllerWithTitle:@"Encryption Password"
            message:@"Enter a password to encrypt the export"
            preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            textField.placeholder = @"Password";
            textField.secureTextEntry = YES;
        }];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"Export" 
                                                  style:UIAlertActionStyleDefault 
                                                handler:^(UIAlertAction *action) {
            NSString *password = alert.textFields.firstObject.text;
            NSError *err;
            NSString *path = [exportDir stringByAppendingPathComponent:
                             [exporter generateFilename:@"wifiguard_export" extension:@"encrypted"]];
            
            if ([exporter exportAllDataToPath:path password:password error:&err]) {
                [self showExportSuccess:path];
            } else {
                [self showExportError:err];
            }
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    NSString *filename = [exporter generateFilename:index == 0 ? @"networks" : @"arp_log" extension:@"csv"];
    NSString *path = [exportDir stringByAppendingPathComponent:filename];
    
    BOOL success;
    if (index == 0) {
        success = [exporter exportNetworksToPath:path format:WGExportFormatCSV password:nil error:&error];
    } else {
        success = [exporter exportARPTableToPath:path format:WGExportFormatCSV password:nil error:&error];
    }
    
    if (success) {
        [self showExportSuccess:path];
    } else {
        [self showExportError:error];
    }
}

- (void)showExportSuccess:(NSString *)path {
    UIAlertController *alert = [UIAlertController 
        alertControllerWithTitle:@"✅ Export Complete"
        message:[NSString stringWithFormat:@"Saved to:\n%@", path]
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showExportError:(NSError *)error {
    UIAlertController *alert = [UIAlertController 
        alertControllerWithTitle:@"❌ Export Failed"
        message:error.localizedDescription
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)startSimulation:(NSInteger)scenario {
    UIAlertController *alert = [UIAlertController 
        alertControllerWithTitle:@"🎓 Educational Simulation"
        message:[NSString stringWithFormat:@"%@\n\n%@\n\n⚠️ This uses SYNTHETIC data only. No real network attacks will be performed.",
                [WGSimulationEngine scenarioName:scenario],
                [WGSimulationEngine scenarioDescription:scenario]]
        preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Start Simulation" 
                                              style:UIAlertActionStyleDefault 
                                            handler:^(UIAlertAction *action) {
        [self.simulationEngine startSimulation:scenario];
        [self showSimulationProgress];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showSimulationProgress {
    UIAlertController *progress = [UIAlertController 
        alertControllerWithTitle:@"🔄 Simulation Running..."
        message:@"Generating synthetic attack demonstration...\n\nThis is for EDUCATIONAL purposes only."
        preferredStyle:UIAlertControllerStyleAlert];
    
    [progress addAction:[UIAlertAction actionWithTitle:@"Stop" 
                                                 style:UIAlertActionStyleDestructive 
                                               handler:^(UIAlertAction *action) {
        [self.simulationEngine stopSimulation];
    }]];
    
    [self presentViewController:progress animated:YES completion:nil];
}

- (void)clearCache {
    UIAlertController *alert = [UIAlertController 
        alertControllerWithTitle:@"Clear Cache"
        message:@"This will clear all cached network data. Continue?"
        preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Clear" 
                                              style:UIAlertActionStyleDestructive 
                                            handler:^(UIAlertAction *action) {
        [self.wifiScanner clearCache];
        [self.arpDetector clearAnomalyHistory];
        
        UIAlertController *confirm = [UIAlertController 
            alertControllerWithTitle:@"✅ Cache Cleared"
            message:nil
            preferredStyle:UIAlertControllerStyleAlert];
        [confirm addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:confirm animated:YES completion:nil];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)secureDeleteAll {
    UIAlertController *alert = [UIAlertController 
        alertControllerWithTitle:@"⚠️ Secure Delete All Data"
        message:@"This will permanently and securely delete ALL WiFiGuard data including:\n\n• Scan history\n• ARP logs\n• Audit logs\n• Preferences\n\nThis action CANNOT be undone."
        preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Delete Everything" 
                                              style:UIAlertActionStyleDestructive 
                                            handler:^(UIAlertAction *action) {
        [WGSecureStorage secureDeleteAllData];
        
        UIAlertController *confirm = [UIAlertController 
            alertControllerWithTitle:@"✅ All Data Deleted"
            message:@"All WiFiGuard data has been securely deleted."
            preferredStyle:UIAlertControllerStyleAlert];
        [confirm addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:confirm animated:YES completion:nil];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showAuditLog {
    NSArray *entries = self.auditLogger.allEntries;
    
    NSMutableString *logText = [NSMutableString string];
    for (WGAuditLogEntry *entry in [entries reverseObjectEnumerator]) {
        [logText appendFormat:@"[%@] %@: %@\n", 
         entry.timestamp, entry.eventType, entry.details ?: @""];
    }
    
    UIAlertController *alert = [UIAlertController 
        alertControllerWithTitle:@"Audit Log"
        message:logText.length > 0 ? logText : @"No entries yet."
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showDisclaimer {
    UIAlertController *alert = [UIAlertController 
        alertControllerWithTitle:@"⚠️ Legal Disclaimer"
        message:@"WiFiGuard is designed for PASSIVE ANALYSIS ONLY of networks you own or have explicit permission to test.\n\n"
                @"NO ACTIVE ATTACKS are implemented.\n\n"
                @"Unauthorized network monitoring is illegal. The developer accepts no responsibility for misuse.\n\n"
                @"By using this tool, you confirm compliance with all applicable laws."
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"I Understand" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - WGSimulationEngineDelegate

- (void)simulationDidComplete:(WGSimulationScenario)scenario withSummary:(NSDictionary *)summary {
    [self dismissViewControllerAnimated:YES completion:^{
        UIAlertController *alert = [UIAlertController 
            alertControllerWithTitle:@"✅ Simulation Complete"
            message:[NSString stringWithFormat:@"Scenario: %@\nDuration: %.0f seconds\nEvents: %@\n\n%@",
                    summary[@"scenario"],
                    [summary[@"duration"] doubleValue],
                    summary[@"eventCount"],
                    summary[@"educational"]]
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }];
}

@end
