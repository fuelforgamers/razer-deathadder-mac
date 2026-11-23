#import <Foundation/Foundation.h>
#import "RazerProtocol.h"

extern NSString * const RazerDeviceConnectionChangedNotification;
extern NSString * const RazerDeviceSettingsChangedNotification;

@interface RazerDevice : NSObject

@property (nonatomic, readonly) BOOL isConnected;
@property (nonatomic, readonly) BOOL hasPermission;
@property (nonatomic, readonly, copy) NSString *productName;
@property (nonatomic, readonly) uint16_t productId;

@property (nonatomic, assign) NSInteger currentDPI;
@property (nonatomic, assign) RazerLightEffect currentEffect;
@property (nonatomic, assign) NSInteger currentBrightness; // 0 - 100%

+ (instancetype)sharedInstance;

+ (BOOL)hasInputMonitoringPermission;
+ (void)requestInputMonitoringPermission;
+ (void)openInputMonitoringSettings;

- (BOOL)refreshDevice;
- (BOOL)setDPI:(NSInteger)dpi;
- (BOOL)setEffect:(RazerLightEffect)effect;
- (BOOL)setBrightness:(NSInteger)percent;
- (BOOL)applyCurrentProfile;

- (void)loadSavedSettings;
- (void)saveSettings;

@end
