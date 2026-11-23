#import "RazerDevice.h"
#import <IOKit/IOKitLib.h>
#import <IOKit/hid/IOHIDManager.h>
#import <IOKit/hid/IOHIDKeys.h>
#import <IOKit/hidsystem/IOHIDLib.h>
#import <Cocoa/Cocoa.h>

NSString * const RazerDeviceConnectionChangedNotification = @"RazerDeviceConnectionChangedNotification";
NSString * const RazerDeviceSettingsChangedNotification   = @"RazerDeviceSettingsChangedNotification";

static NSString * const kPrefDPI        = @"RazerDPI_Value";
static NSString * const kPrefEffect     = @"RazerDPI_Effect";
static NSString * const kPrefBrightness = @"RazerDPI_Brightness";

@interface RazerDevice () {
    IOHIDManagerRef _hidManager;
    IOHIDDeviceRef  _hidDevice;
    BOOL            _isDeviceOpen;
}

@property (nonatomic, readwrite) BOOL isConnected;
@property (nonatomic, readwrite) BOOL hasPermission;
@property (nonatomic, readwrite, copy) NSString *productName;
@property (nonatomic, readwrite) uint16_t productId;

@end

static void HandleDeviceMatched(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    RazerDevice *selfObj = (__bridge RazerDevice *)context;
    dispatch_async(dispatch_get_main_queue(), ^{
        [selfObj refreshDevice];
        if (selfObj.isConnected) {
            [selfObj applyCurrentProfile];
        }
    });
}

static void HandleDeviceRemoved(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    RazerDevice *selfObj = (__bridge RazerDevice *)context;
    dispatch_async(dispatch_get_main_queue(), ^{
        [selfObj refreshDevice];
    });
}

@implementation RazerDevice

+ (instancetype)sharedInstance {
    static RazerDevice *sInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sInstance = [[self alloc] init];
    });
    return sInstance;
}

+ (BOOL)hasInputMonitoringPermission {
    IOHIDAccessType access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent);
    return (access == kIOHIDAccessTypeGranted);
}

+ (void)requestInputMonitoringPermission {
    IOHIDRequestAccess(kIOHIDRequestTypeListenEvent);
}

+ (void)openInputMonitoringSettings {
    NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentDPI = 800;
        _currentEffect = RazerLightEffectStatic;
        _currentBrightness = 100;
        
        [self loadSavedSettings];
        [self setupHIDManager];
        [self refreshDevice];
        
        if (_isConnected) {
            [self applyCurrentProfile];
        }
    }
    return self;
}

- (void)dealloc {
    [self closeDevice];
    if (_hidManager) {
        IOHIDManagerUnscheduleFromRunLoop(_hidManager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        CFRelease(_hidManager);
        _hidManager = NULL;
    }
}

- (void)setupHIDManager {
    _hidManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if (!_hidManager) return;
    
    // Only match Generic Desktop (0x01) -> Mouse (0x02) to NEVER touch keyboard interfaces!
    NSDictionary *matching = @{
        @(kIOHIDVendorIDKey): @(RAZER_VENDOR_ID),
        @(kIOHIDPrimaryUsagePageKey): @(0x01),
        @(kIOHIDPrimaryUsageKey): @(0x02)
    };
    IOHIDManagerSetDeviceMatching(_hidManager, (__bridge CFDictionaryRef)matching);
    
    IOHIDManagerRegisterDeviceMatchingCallback(_hidManager, HandleDeviceMatched, (__bridge void *)self);
    IOHIDManagerRegisterDeviceRemovalCallback(_hidManager, HandleDeviceRemoved, (__bridge void *)self);
    
    IOHIDManagerScheduleWithRunLoop(_hidManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    // CRITICAL: DO NOT CALL IOHIDManagerOpen! Opening the manager grabs all interfaces
    // and causes macOS TCC to deny device access.
}

- (void)closeDevice {
    if (_hidDevice && _isDeviceOpen) {
        IOHIDDeviceClose(_hidDevice, kIOHIDOptionsTypeNone);
        _isDeviceOpen = NO;
    }
    _hidDevice = NULL;
}

- (BOOL)refreshDevice {
    [self closeDevice];
    
    self.hasPermission = [RazerDevice hasInputMonitoringPermission];
    
    if (!_hidManager) {
        self.isConnected = NO;
        self.productName = @"No Device";
        self.productId = 0;
        [[NSNotificationCenter defaultCenter] postNotificationName:RazerDeviceConnectionChangedNotification object:self];
        return NO;
    }
    
    CFSetRef devSet = IOHIDManagerCopyDevices(_hidManager);
    if (!devSet) {
        self.isConnected = NO;
        self.productName = @"Disconnected";
        self.productId = 0;
        [[NSNotificationCenter defaultCenter] postNotificationName:RazerDeviceConnectionChangedNotification object:self];
        return NO;
    }
    
    IOHIDDeviceRef matched = NULL;
    for (id devObj in (__bridge NSSet *)devSet) {
        IOHIDDeviceRef dev = (__bridge IOHIDDeviceRef)devObj;
        NSNumber *vid = (__bridge NSNumber *)IOHIDDeviceGetProperty(dev, (CFStringRef)@(kIOHIDVendorIDKey));
        NSNumber *pid = (__bridge NSNumber *)IOHIDDeviceGetProperty(dev, (CFStringRef)@(kIOHIDProductIDKey));
        NSNumber *feat = (__bridge NSNumber *)IOHIDDeviceGetProperty(dev, (CFStringRef)@(kIOHIDMaxFeatureReportSizeKey));
        
        // Razer 90-byte feature report interface
        if ([vid intValue] == RAZER_VENDOR_ID && [feat intValue] == RAZER_REPORT_LEN) {
            matched = dev;
            self.productId = [pid unsignedShortValue];
            break;
        }
    }
    CFRelease(devSet);
    
    if (matched) {
        _hidDevice = matched;
        NSString *name = (__bridge NSString *)IOHIDDeviceGetProperty(matched, (CFStringRef)@(kIOHIDProductKey));
        self.productName = name ?: @"Razer DeathAdder Essential";
        
        // Test opening the device
        IOReturn r = IOHIDDeviceOpen(_hidDevice, kIOHIDOptionsTypeNone);
        if (r == kIOReturnSuccess) {
            _isDeviceOpen = YES;
            self.isConnected = YES;
            // Query current hardware DPI
            [self queryHardwareDPI];
        } else {
            _isDeviceOpen = NO;
            self.isConnected = NO;
            NSLog(@"IOHIDDeviceOpen failed: 0x%08x (TCC permission needed)", r);
        }
    } else {
        self.isConnected = NO;
        self.productName = @"Disconnected";
        self.productId = 0;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:RazerDeviceConnectionChangedNotification object:self];
    return self.isConnected;
}

- (BOOL)sendReportWithTxId:(uint8_t)txId
                     class:(uint8_t)cls
                 commandId:(uint8_t)cmd
                  dataSize:(uint8_t)size
                 arguments:(const uint8_t *)args
                  response:(uint8_t *)outResp {
    if (!_hidDevice) {
        if (![self refreshDevice]) return NO;
    }
    if (!_isDeviceOpen) {
        IOReturn r = IOHIDDeviceOpen(_hidDevice, kIOHIDOptionsTypeNone);
        if (r == kIOReturnSuccess) {
            _isDeviceOpen = YES;
        } else {
            self.hasPermission = [RazerDevice hasInputMonitoringPermission];
            NSLog(@"IOHIDDeviceOpen failed: 0x%08x", r);
            return NO;
        }
    }
    
    uint8_t req[RAZER_REPORT_LEN] = {0};
    req[0] = RAZER_STATUS_NEW;
    req[1] = txId;
    req[4] = 0x00;
    req[5] = size;
    req[6] = cls;
    req[7] = cmd;
    if (args && size > 0) {
        memcpy(&req[8], args, size);
    }
    req[88] = razer_calculate_checksum(req);
    req[89] = 0x00;
    
    IOReturn r = IOHIDDeviceSetReport(_hidDevice, kIOHIDReportTypeFeature, 0, req, sizeof(req));
    if (r != kIOReturnSuccess) {
        NSLog(@"SetReport error: 0x%08x", r);
        return NO;
    }
    
    // Hardware delay between SetReport and GetReport
    usleep(15000);
    
    // Read response
    for (int retry = 0; retry < 5; retry++) {
        uint8_t resp[RAZER_REPORT_LEN] = {0};
        CFIndex respSize = sizeof(resp);
        IOReturn gr = IOHIDDeviceGetReport(_hidDevice, kIOHIDReportTypeFeature, 0, resp, &respSize);
        if (gr == kIOReturnSuccess) {
            if (resp[0] == RAZER_STATUS_SUCCESS) {
                if (outResp) {
                    memcpy(outResp, resp, sizeof(resp));
                }
                return YES;
            } else if (resp[0] == RAZER_STATUS_BUSY) {
                usleep(5000);
                continue;
            } else {
                NSLog(@"Razer response status: 0x%02x (tx=0x%02x, cls=0x%02x, cmd=0x%02x)", resp[0], resp[1], resp[6], resp[7]);
                return NO;
            }
        }
        usleep(5000);
    }
    
    return NO;
}

- (BOOL)queryHardwareDPI {
    uint8_t args[1] = { RAZER_VARSTORE };
    uint8_t resp[RAZER_REPORT_LEN] = {0};
    BOOL ok = [self sendReportWithTxId:0x1F
                                 class:RAZER_CMD_CLASS_DPI
                             commandId:RAZER_CMD_DPI_GET
                              dataSize:0x07
                             arguments:args
                              response:resp];
    if (ok) {
        uint16_t dpiX = ((uint16_t)resp[9] << 8) | resp[10];
        if (dpiX >= 200 && dpiX <= 6400) {
            _currentDPI = dpiX;
            [[NSNotificationCenter defaultCenter] postNotificationName:RazerDeviceSettingsChangedNotification object:self];
            return YES;
        }
    }
    return NO;
}

- (BOOL)setDPI:(NSInteger)dpi {
    if (dpi < 200) dpi = 200;
    if (dpi > 6400) dpi = 6400;
    
    uint16_t d = (uint16_t)dpi;
    
    // 1. Send NOSTORE (0x00) with tx 0xFF for instantaneous RAM sensor switch
    uint8_t nostoreArgs[7] = {
        0x00, // NOSTORE
        (uint8_t)((d >> 8) & 0xFF),
        (uint8_t)(d & 0xFF),
        (uint8_t)((d >> 8) & 0xFF),
        (uint8_t)(d & 0xFF),
        0x00,
        0x00
    };
    BOOL ok1 = [self sendReportWithTxId:0xFF
                                  class:RAZER_CMD_CLASS_DPI
                              commandId:RAZER_CMD_DPI_SET
                               dataSize:0x07
                              arguments:nostoreArgs
                               response:NULL];
    
    // 2. Also send VARSTORE (0x01) with tx 0x1F
    uint8_t varstoreArgs[7] = {
        RAZER_VARSTORE,
        (uint8_t)((d >> 8) & 0xFF),
        (uint8_t)(d & 0xFF),
        (uint8_t)((d >> 8) & 0xFF),
        (uint8_t)(d & 0xFF),
        0x00,
        0x00
    };
    BOOL ok2 = [self sendReportWithTxId:0x1F
                                  class:RAZER_CMD_CLASS_DPI
                              commandId:RAZER_CMD_DPI_SET
                               dataSize:0x07
                              arguments:varstoreArgs
                               response:NULL];
    
    if (ok1 || ok2) {
        _currentDPI = dpi;
        [self saveSettings];
        [[NSNotificationCenter defaultCenter] postNotificationName:RazerDeviceSettingsChangedNotification object:self];
        return YES;
    }
    return NO;
}

- (BOOL)setEffect:(RazerLightEffect)effect {
    BOOL ok = NO;
    if (effect == RazerLightEffectStatic) {
        // OpenRazer Static: tx 0x3F, cls 0x0F, cmd 0x02, size 9, LOGO_LED (0x04)
        uint8_t args[9] = { RAZER_VARSTORE, RAZER_LED_LOGO, 0x01, 0x00, 0x00, 0x01, 0x00, 0xFF, 0x00 };
        ok = [self sendReportWithTxId:0x3F
                                class:RAZER_CMD_CLASS_MATRIX
                            commandId:RAZER_CMD_MATRIX_EFFECT
                             dataSize:9
                            arguments:args
                             response:NULL];
    } else if (effect == RazerLightEffectBreathing) {
        // OpenRazer Breathing: tx 0x3F, cls 0x0F, cmd 0x02, size 9, LOGO_LED (0x04)
        uint8_t args[9] = { RAZER_VARSTORE, RAZER_LED_LOGO, 0x02, 0x01, 0x00, 0x01, 0x00, 0xFF, 0x00 };
        ok = [self sendReportWithTxId:0x3F
                                class:RAZER_CMD_CLASS_MATRIX
                            commandId:RAZER_CMD_MATRIX_EFFECT
                             dataSize:9
                            arguments:args
                             response:NULL];
    } else {
        // OpenRazer None/Off: tx 0x3F, cls 0x0F, cmd 0x02, size 6, LOGO_LED (0x04)
        uint8_t args[6] = { RAZER_VARSTORE, RAZER_LED_LOGO, 0x00, 0x00, 0x00, 0x00 };
        ok = [self sendReportWithTxId:0x3F
                                class:RAZER_CMD_CLASS_MATRIX
                            commandId:RAZER_CMD_MATRIX_EFFECT
                             dataSize:6
                            arguments:args
                             response:NULL];
    }
    
    if (ok) {
        _currentEffect = effect;
        [self saveSettings];
        [[NSNotificationCenter defaultCenter] postNotificationName:RazerDeviceSettingsChangedNotification object:self];
    }
    return ok;
}

- (BOOL)setBrightness:(NSInteger)percent {
    if (percent < 0) percent = 0;
    if (percent > 100) percent = 100;
    
    uint8_t bVal = (uint8_t)((percent * 255) / 100);
    // OpenRazer Brightness: tx 0x3F, cls 0x0F, cmd 0x04, size 3, LOGO_LED (0x04)
    uint8_t args[3] = { RAZER_VARSTORE, RAZER_LED_LOGO, bVal };
    BOOL ok = [self sendReportWithTxId:0x3F
                                 class:RAZER_CMD_CLASS_MATRIX
                             commandId:RAZER_CMD_MATRIX_BRIGHTNESS
                              dataSize:3
                             arguments:args
                              response:NULL];
    if (ok) {
        _currentBrightness = percent;
        [self saveSettings];
        [[NSNotificationCenter defaultCenter] postNotificationName:RazerDeviceSettingsChangedNotification object:self];
    }
    return ok;
}

- (BOOL)applyCurrentProfile {
    BOOL okDPI = [self setDPI:_currentDPI];
    BOOL okEffect = [self setEffect:_currentEffect];
    BOOL okBright = [self setBrightness:_currentBrightness];
    return okDPI || okEffect || okBright;
}

- (void)loadSavedSettings {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    if ([defs objectForKey:kPrefDPI]) {
        _currentDPI = [defs integerForKey:kPrefDPI];
    }
    if ([defs objectForKey:kPrefEffect]) {
        _currentEffect = (RazerLightEffect)[defs integerForKey:kPrefEffect];
    }
    if ([defs objectForKey:kPrefBrightness]) {
        _currentBrightness = [defs integerForKey:kPrefBrightness];
    }
}

- (void)saveSettings {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setInteger:_currentDPI forKey:kPrefDPI];
    [defs setInteger:_currentEffect forKey:kPrefEffect];
    [defs setInteger:_currentBrightness forKey:kPrefBrightness];
    [defs synchronize];
}

@end
