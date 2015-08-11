//
//  BeaconViewController.m
//  iOS7Sampler
//
//  Created by shuichi on 12/5/13.
//  Copyright (c) 2013 Shuichi Tsutsumi. All rights reserved.
//

#import "BeaconViewController.h"
#import <CoreLocation/CoreLocation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "PulsingHaloLayer.h"


#define kProximityUUID  @"B9407F30-F5F8-466E-AFF9-25556B57FE6D"
#define kIdentifier     @"com.shu223.ios7sampler"


@interface BeaconViewController ()
<CLLocationManagerDelegate, CBPeripheralManagerDelegate>

// for central
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLBeaconRegion *beaconRegion;
@property (nonatomic, weak) IBOutlet UILabel *statusLabel;
@property (nonatomic, weak) IBOutlet UILabel *proximityLabel;
@property (nonatomic, weak) IBOutlet UILabel *rssiLabel;
@property (nonatomic, weak) IBOutlet UILabel *accuracyLabel;

// for peripheral
@property (nonatomic, strong) CBPeripheralManager *peripheralManager;
@property (nonatomic, weak) IBOutlet UIView *overlayView;
@property (nonatomic, weak) IBOutlet UILabel *stateLabel;
@property (nonatomic, weak) IBOutlet UITableView *tableView;

@property (nonatomic, strong) NSArray *beacons;

@end


@implementation BeaconViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.overlayView.hidden = YES;
    [self resetLabels];
    
    [self startRegionMonitoring];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


// =============================================================================
#pragma mark - for central

- (void)resetLabels {
    
    self.statusLabel.text = @"No Beacons";
    
    self.proximityLabel.text = nil;
    self.rssiLabel.text = nil;
    self.accuracyLabel.text = nil;
}

- (void)startRegionMonitoring {

    if ([CLLocationManager isMonitoringAvailableForClass:[CLBeaconRegion class]]) {
        
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        
        NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:kProximityUUID];
        
        self.beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:uuid
                                                               identifier:kIdentifier];
        
        [self.locationManager startMonitoringForRegion:self.beaconRegion];
    }
}

- (void)startRangingInRegion:(CLRegion *)region {

    if ([region isMemberOfClass:[CLBeaconRegion class]] && [CLLocationManager isRangingAvailable]) {

        self.statusLabel.text = @"Beacon in range:";

        [self.locationManager startRangingBeaconsInRegion:self.beaconRegion];
    }
}


// =============================================================================
#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    
    NSLog(@"status:%d", status);
    
    switch (status) {
        case kCLAuthorizationStatusNotDetermined:
        {
            if ([self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
                [self.locationManager requestAlwaysAuthorization];
            }
            break;
        }
        case kCLAuthorizationStatusAuthorizedWhenInUse:
        case kCLAuthorizationStatusAuthorizedAlways:
            break;
            
        default:
            break;
    }
}

- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region {
    
    NSLog(@"Start monitoring for region");
    [self.locationManager requestStateForRegion:self.beaconRegion];
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error {
    
    NSLog(@"Failed monitoring with error:%@", error);
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    
    NSLog(@"didFailWithError:%@", error);
}

- (void)locationManager:(CLLocationManager *)manager
      didDetermineState:(CLRegionState)state
              forRegion:(CLRegion *)region
{
    switch (state) {
        case CLRegionStateInside:
        {
            [self startRangingInRegion:region];
            break;
        }
        case CLRegionStateOutside:
        case CLRegionStateUnknown:
        default:
            break;
    }
}

- (void)locationManager:(CLLocationManager *)manager
         didEnterRegion:(CLRegion *)region
{
    [self startRangingInRegion:region];
}

- (void)locationManager:(CLLocationManager *)manager
          didExitRegion:(CLRegion *)region
{
    [self resetLabels];
    
    // stop ranging
    if ([region isMemberOfClass:[CLBeaconRegion class]] && [CLLocationManager isRangingAvailable]) {
        
        [self.locationManager stopRangingBeaconsInRegion:(CLBeaconRegion *)region];
    }
}

- (void)locationManager:(CLLocationManager *)manager
        didRangeBeacons:(NSArray *)beacons
               inRegion:(CLBeaconRegion *)region
{

    
    self.beacons = [beacons sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        CLBeacon *beacon1 = (CLBeacon*)obj1;
        CLBeacon *beacon2 = (CLBeacon*)obj2;
        
        return [beacon1.major compare:beacon2.major]; //&& [beacon1.minor compare:beacon2.minor];
        
    }];
    [self.tableView reloadData];
    
    CLBeacon *beacon = beacons.firstObject;
    

    
    self.proximityLabel.text = [self convertToProximityString:beacon.proximity];

    self.rssiLabel.text = [NSString stringWithFormat:@"%ld [dB]", (long)beacon.rssi];
    self.accuracyLabel.text = [NSString stringWithFormat:@"%.0f [m]", beacon.accuracy];
}

#pragma mark - UITableViewDataSource
- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return kProximityUUID;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.beacons.count;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
        
    }
    
    CLBeacon *beacon = self.beacons[indexPath.row];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"proximity:%@  accuracy:%f rssi:%d",
                                   [self convertToProximityString:beacon.proximity],
                                    beacon.accuracy,
                                 beacon.rssi]
                                   ;
    cell.textLabel.text = [NSString stringWithFormat:@"major:%d minor:%d",beacon.major.integerValue, beacon.minor.integerValue];
    
    return cell;
}

- (NSString*)convertToProximityString:(CLProximity)proximity
{
    NSString *proximityStr;
    
    switch (proximity) {
            
        case CLProximityImmediate:
        {
            proximityStr = @"Immediate";
            
            break;
        }
        case CLProximityNear:
        {
            proximityStr = @"Near";
            
            break;
        }
        case CLProximityFar:
        {
            proximityStr = @"Far";
            
            break;
        }
        default:
        {
            proximityStr = @"Unknown";
            
            break;
        }
    }
    
    return proximityStr;
}

// =============================================================================
#pragma mark - for peripheral

- (void)startAdvertising {
    
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:kProximityUUID];
    
    CLBeaconRegion *beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:uuid
                                                                      identifier:kIdentifier];
    
    NSDictionary *beaconPeripheralData = [beaconRegion peripheralDataWithMeasuredPower:nil];
    
    [self.peripheralManager startAdvertising:beaconPeripheralData];
}

- (IBAction)pressTurnIntoBeacon {
    
    self.locationManager.delegate = nil;
    [self.locationManager stopMonitoringForRegion:self.beaconRegion];
    [self resetLabels];
    self.statusLabel.text = nil;
    
    self.overlayView.hidden = NO;
    
    self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self
                                                                     queue:nil
                                                                   options:nil];
    
    if (self.peripheralManager.state == CBPeripheralManagerStatePoweredOn) {
        
        [self startAdvertising];
    }
}


// =============================================================================
#pragma mark - CBPeripheralManagerDelegate

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error {
    
    if (error) {
        
        NSLog(@"Failed to start advertising with error:%@", error);
    }
    else {
        
        NSLog(@"Start advertising");
        
        // Show beacon's pulse
        PulsingHaloLayer *layer = [PulsingHaloLayer layer];
        layer.position = self.overlayView.center;
        layer.radius = 160.;
        [self.overlayView.layer insertSublayer:layer atIndex:0];
    }
}

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    NSString *stateStr;
    
    switch (peripheral.state) {
        case CBPeripheralManagerStatePoweredOff:
        {
            stateStr = @"PoweredOff";
            break;
        }
        case CBPeripheralManagerStatePoweredOn:
        {
            stateStr = @"PoweredOn";
            
            [self startAdvertising];
            
            break;
        }
        case CBPeripheralManagerStateResetting:
        {
            stateStr = @"Resetting";
            break;
        }
        case CBPeripheralManagerStateUnauthorized:
        {
            stateStr = @"Unauthorized";
            break;
        }
        case CBPeripheralManagerStateUnknown:
        {
            stateStr = @"Unknown";
            break;
        }
        case CBPeripheralManagerStateUnsupported:
        {
            stateStr = @"Unsupported";
            break;
        }
        default:
        {
            stateStr = nil;
            break;
        }
    }
    
    self.stateLabel.text = [NSString stringWithFormat:@"%@", stateStr];
}

@end
