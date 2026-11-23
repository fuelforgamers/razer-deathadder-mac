#import "ControlWindow.h"
#import "RazerDevice.h"

@interface ControlWindow ()

@property (nonatomic, strong) NSBox *permBannerBox;
@property (nonatomic, strong) NSTextField *statusBadge;
@property (nonatomic, strong) NSTextField *deviceTitleLabel;
@property (nonatomic, strong) NSButton *refreshButton;

@property (nonatomic, strong) NSTextField *dpiValueLabel;
@property (nonatomic, strong) NSSlider *dpiSlider;
@property (nonatomic, strong) NSTextField *customDpiField;
@property (nonatomic, strong) NSButton *customDpiApplyBtn;
@property (nonatomic, strong) NSMutableArray<NSButton *> *presetButtons;

@property (nonatomic, strong) NSSegmentedControl *effectControl;
@property (nonatomic, strong) NSSlider *brightnessSlider;
@property (nonatomic, strong) NSTextField *brightnessLabel;

@property (nonatomic, strong) NSButton *startAtLoginCheckbox;
@property (nonatomic, strong) NSTextField *feedbackLabel;

@end

@implementation ControlWindow

+ (instancetype)sharedController {
    static ControlWindow *sInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sInstance = [[self alloc] init];
    });
    return sInstance;
}

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, 420, 580);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:(NSWindowStyleMaskTitled |
                                                              NSWindowStyleMaskClosable |
                                                              NSWindowStyleMaskMiniaturizable)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    [window setTitle:@"Razer DeathAdder Essential"];
    [window center];
    [window setReleasedWhenClosed:NO];
    
    self = [super initWithWindow:window];
    if (self) {
        [self buildUI];
        [self updateUIFromDevice];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(deviceConnectionChanged:)
                                                     name:RazerDeviceConnectionChangedNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(deviceSettingsChanged:)
                                                     name:RazerDeviceSettingsChangedNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)bringToFront {
    [self updateUIFromDevice];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)buildUI {
    NSView *content = self.window.contentView;
    _presetButtons = [NSMutableArray array];
    
    // 0. Permission Warning Banner
    _permBannerBox = [[NSBox alloc] initWithFrame:NSMakeRect(20, 495, 380, 52)];
    _permBannerBox.boxType = NSBoxCustom;
    _permBannerBox.borderColor = [NSColor systemOrangeColor];
    _permBannerBox.borderWidth = 1.5;
    _permBannerBox.cornerRadius = 8.0;
    _permBannerBox.fillColor = [NSColor colorWithCalibratedRed:0.2 green:0.15 blue:0.05 alpha:0.3];
    [content addSubview:_permBannerBox];
    
    NSTextField *permText = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 24, 250, 22)];
    permText.editable = NO;
    permText.bordered = NO;
    permText.drawsBackground = NO;
    permText.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    permText.textColor = [NSColor systemOrangeColor];
    permText.stringValue = @"⚠️ Input Monitoring Permission Required";
    [_permBannerBox addSubview:permText];
    
    NSButton *permBtn = [[NSButton alloc] initWithFrame:NSMakeRect(265, 12, 105, 28)];
    permBtn.title = @"Grant Access";
    permBtn.bezelStyle = NSBezelStyleRounded;
    permBtn.target = self;
    permBtn.action = @selector(onGrantPermissionClicked:);
    [_permBannerBox addSubview:permBtn];
    
    // 1. Header Box
    NSBox *headerBox = [[NSBox alloc] initWithFrame:NSMakeRect(20, 420, 380, 65)];
    headerBox.boxType = NSBoxCustom;
    headerBox.borderColor = [NSColor separatorColor];
    headerBox.borderWidth = 1.0;
    headerBox.cornerRadius = 8.0;
    headerBox.fillColor = [NSColor controlBackgroundColor];
    [content addSubview:headerBox];
    
    _deviceTitleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 34, 260, 22)];
    _deviceTitleLabel.editable = NO;
    _deviceTitleLabel.bordered = NO;
    _deviceTitleLabel.drawsBackground = NO;
    _deviceTitleLabel.font = [NSFont systemFontOfSize:15 weight:NSFontWeightBold];
    _deviceTitleLabel.stringValue = @"DeathAdder Essential";
    [headerBox addSubview:_deviceTitleLabel];
    
    _statusBadge = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 12, 260, 18)];
    _statusBadge.editable = NO;
    _statusBadge.bordered = NO;
    _statusBadge.drawsBackground = NO;
    _statusBadge.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    [headerBox addSubview:_statusBadge];
    
    _refreshButton = [[NSButton alloc] initWithFrame:NSMakeRect(284, 18, 82, 30)];
    _refreshButton.title = @"Refresh";
    _refreshButton.bezelStyle = NSBezelStyleRounded;
    _refreshButton.target = self;
    _refreshButton.action = @selector(onRefreshClicked:);
    [headerBox addSubview:_refreshButton];
    
    // 2. DPI Section Box
    NSBox *dpiBox = [[NSBox alloc] initWithFrame:NSMakeRect(20, 210, 380, 200)];
    dpiBox.boxType = NSBoxCustom;
    dpiBox.borderColor = [NSColor separatorColor];
    dpiBox.borderWidth = 1.0;
    dpiBox.cornerRadius = 8.0;
    dpiBox.fillColor = [NSColor controlBackgroundColor];
    [content addSubview:dpiBox];
    
    NSTextField *dpiSecTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 168, 200, 20)];
    dpiSecTitle.editable = NO;
    dpiSecTitle.bordered = NO;
    dpiSecTitle.drawsBackground = NO;
    dpiSecTitle.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
    dpiSecTitle.stringValue = @"DPI Sensitivity";
    [dpiBox addSubview:dpiSecTitle];
    
    _dpiValueLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(240, 164, 125, 26)];
    _dpiValueLabel.alignment = NSTextAlignmentRight;
    _dpiValueLabel.editable = NO;
    _dpiValueLabel.bordered = NO;
    _dpiValueLabel.drawsBackground = NO;
    _dpiValueLabel.font = [NSFont monospacedDigitSystemFontOfSize:18 weight:NSFontWeightBold];
    _dpiValueLabel.textColor = [NSColor colorWithCalibratedRed:0.0 green:0.85 blue:0.25 alpha:1.0];
    [dpiBox addSubview:_dpiValueLabel];
    
    // Preset Buttons [400] [800] [1600] [3200] [6400]
    NSArray *presets = @[@400, @800, @1600, @3200, @6400];
    CGFloat btnWidth = 66.0;
    CGFloat gap = 6.0;
    CGFloat startX = 14.0;
    for (int i = 0; i < presets.count; i++) {
        NSNumber *val = presets[i];
        NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(startX + i * (btnWidth + gap), 126, btnWidth, 30)];
        btn.title = [NSString stringWithFormat:@"%@", val];
        btn.bezelStyle = NSBezelStyleRounded;
        btn.tag = [val integerValue];
        btn.target = self;
        btn.action = @selector(onPresetClicked:);
        [dpiBox addSubview:btn];
        [_presetButtons addObject:btn];
    }
    
    // DPI Slider (200 - 6400)
    _dpiSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(14, 80, 352, 24)];
    _dpiSlider.minValue = 200;
    _dpiSlider.maxValue = 6400;
    _dpiSlider.numberOfTickMarks = 0;
    _dpiSlider.continuous = YES;
    _dpiSlider.target = self;
    _dpiSlider.action = @selector(onDpiSliderChanged:);
    [dpiBox addSubview:_dpiSlider];
    
    NSTextField *minDpiLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 60, 60, 16)];
    minDpiLabel.editable = NO;
    minDpiLabel.bordered = NO;
    minDpiLabel.drawsBackground = NO;
    minDpiLabel.font = [NSFont systemFontOfSize:10];
    minDpiLabel.textColor = [NSColor secondaryLabelColor];
    minDpiLabel.stringValue = @"200 DPI";
    [dpiBox addSubview:minDpiLabel];
    
    NSTextField *maxDpiLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(306, 60, 60, 16)];
    maxDpiLabel.alignment = NSTextAlignmentRight;
    maxDpiLabel.editable = NO;
    maxDpiLabel.bordered = NO;
    maxDpiLabel.drawsBackground = NO;
    maxDpiLabel.font = [NSFont systemFontOfSize:10];
    maxDpiLabel.textColor = [NSColor secondaryLabelColor];
    maxDpiLabel.stringValue = @"6400 DPI";
    [dpiBox addSubview:maxDpiLabel];
    
    // Custom Direct DPI Input
    NSTextField *customLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 22, 100, 20)];
    customLabel.editable = NO;
    customLabel.bordered = NO;
    customLabel.drawsBackground = NO;
    customLabel.font = [NSFont systemFontOfSize:12];
    customLabel.stringValue = @"Custom DPI:";
    [dpiBox addSubview:customLabel];
    
    _customDpiField = [[NSTextField alloc] initWithFrame:NSMakeRect(115, 20, 175, 24)];
    _customDpiField.placeholderString = @"200 - 6400";
    _customDpiField.target = self;
    _customDpiField.action = @selector(onCustomDpiApply:);
    [dpiBox addSubview:_customDpiField];
    
    _customDpiApplyBtn = [[NSButton alloc] initWithFrame:NSMakeRect(298, 17, 68, 28)];
    _customDpiApplyBtn.title = @"Set";
    _customDpiApplyBtn.bezelStyle = NSBezelStyleRounded;
    _customDpiApplyBtn.target = self;
    _customDpiApplyBtn.action = @selector(onCustomDpiApply:);
    [dpiBox addSubview:_customDpiApplyBtn];
    
    // 3. Lighting Section Box
    NSBox *lightBox = [[NSBox alloc] initWithFrame:NSMakeRect(20, 68, 380, 160)];
    lightBox.boxType = NSBoxCustom;
    lightBox.borderColor = [NSColor separatorColor];
    lightBox.borderWidth = 1.0;
    lightBox.cornerRadius = 8.0;
    lightBox.fillColor = [NSColor controlBackgroundColor];
    [content addSubview:lightBox];
    
    NSTextField *lightSecTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 130, 200, 20)];
    lightSecTitle.editable = NO;
    lightSecTitle.bordered = NO;
    lightSecTitle.drawsBackground = NO;
    lightSecTitle.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
    lightSecTitle.stringValue = @"Lighting & Effects";
    [lightBox addSubview:lightSecTitle];
    
    _effectControl = [NSSegmentedControl segmentedControlWithLabels:@[@"Static", @"Breathing", @"Off"]
                                                       trackingMode:NSSegmentSwitchTrackingSelectOne
                                                             target:self
                                                             action:@selector(onEffectChanged:)];
    _effectControl.frame = NSMakeRect(14, 94, 352, 28);
    [lightBox addSubview:_effectControl];
    
    NSTextField *brightTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 58, 120, 18)];
    brightTitle.editable = NO;
    brightTitle.bordered = NO;
    brightTitle.drawsBackground = NO;
    brightTitle.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    brightTitle.stringValue = @"LED Brightness:";
    [lightBox addSubview:brightTitle];
    
    _brightnessLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(286, 58, 80, 18)];
    _brightnessLabel.alignment = NSTextAlignmentRight;
    _brightnessLabel.editable = NO;
    _brightnessLabel.bordered = NO;
    _brightnessLabel.drawsBackground = NO;
    _brightnessLabel.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightBold];
    [lightBox addSubview:_brightnessLabel];
    
    _brightnessSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(14, 28, 352, 24)];
    _brightnessSlider.minValue = 0;
    _brightnessSlider.maxValue = 100;
    _brightnessSlider.continuous = YES;
    _brightnessSlider.target = self;
    _brightnessSlider.action = @selector(onBrightnessChanged:);
    [lightBox addSubview:_brightnessSlider];
    
    NSTextField *minBright = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 10, 60, 16)];
    minBright.editable = NO;
    minBright.bordered = NO;
    minBright.drawsBackground = NO;
    minBright.font = [NSFont systemFontOfSize:10];
    minBright.textColor = [NSColor secondaryLabelColor];
    minBright.stringValue = @"0% (Off)";
    [lightBox addSubview:minBright];
    
    NSTextField *maxBright = [[NSTextField alloc] initWithFrame:NSMakeRect(306, 10, 60, 16)];
    maxBright.alignment = NSTextAlignmentRight;
    maxBright.editable = NO;
    maxBright.bordered = NO;
    maxBright.drawsBackground = NO;
    maxBright.font = [NSFont systemFontOfSize:10];
    maxBright.textColor = [NSColor secondaryLabelColor];
    maxBright.stringValue = @"100% (Max)";
    [lightBox addSubview:maxBright];
    
    // 4. Start at Login Checkbox
    _startAtLoginCheckbox = [NSButton checkboxWithTitle:@"Start automatically at login (always active in menu bar)"
                                                 target:self
                                                 action:@selector(onToggleStartAtLogin:)];
    _startAtLoginCheckbox.frame = NSMakeRect(20, 36, 380, 20);
    _startAtLoginCheckbox.font = [NSFont systemFontOfSize:12];
    [content addSubview:_startAtLoginCheckbox];

    // 5. Bottom Feedback Label
    _feedbackLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 10, 380, 20)];
    _feedbackLabel.editable = NO;
    _feedbackLabel.bordered = NO;
    _feedbackLabel.drawsBackground = NO;
    _feedbackLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    _feedbackLabel.textColor = [NSColor secondaryLabelColor];
    _feedbackLabel.stringValue = @"Ready";
    [content addSubview:_feedbackLabel];
}

- (void)updateUIFromDevice {
    RazerDevice *dev = [RazerDevice sharedInstance];
    BOOL hasPerm = [RazerDevice hasInputMonitoringPermission];
    _permBannerBox.hidden = hasPerm;
    
    BOOL connected = dev.isConnected;
    
    if (connected) {
        _statusBadge.stringValue = @"● Connected (USB)";
        _statusBadge.textColor = [NSColor colorWithCalibratedRed:0.0 green:0.85 blue:0.25 alpha:1.0];
        _deviceTitleLabel.stringValue = dev.productName ?: @"Razer DeathAdder Essential";
    } else {
        if (!hasPerm) {
            _statusBadge.stringValue = @"⚠️ Needs Input Monitoring Permission";
            _statusBadge.textColor = [NSColor systemOrangeColor];
        } else {
            _statusBadge.stringValue = @"○ Disconnected";
            _statusBadge.textColor = [NSColor systemRedColor];
        }
        _deviceTitleLabel.stringValue = @"Razer DeathAdder Essential";
    }
    
    _dpiValueLabel.stringValue = [NSString stringWithFormat:@"%ld DPI", (long)dev.currentDPI];
    _dpiSlider.integerValue = dev.currentDPI;
    _customDpiField.stringValue = [NSString stringWithFormat:@"%ld", (long)dev.currentDPI];
    
    for (NSButton *btn in _presetButtons) {
        if (btn.tag == dev.currentDPI) {
            btn.contentTintColor = [NSColor colorWithCalibratedRed:0.0 green:0.85 blue:0.25 alpha:1.0];
        } else {
            btn.contentTintColor = nil;
        }
    }
    
    if (dev.currentEffect == RazerLightEffectStatic) {
        _effectControl.selectedSegment = 0;
    } else if (dev.currentEffect == RazerLightEffectBreathing) {
        _effectControl.selectedSegment = 1;
    } else {
        _effectControl.selectedSegment = 2;
    }
    
    _brightnessSlider.integerValue = dev.currentBrightness;
    _brightnessLabel.stringValue = [NSString stringWithFormat:@"%ld%%", (long)dev.currentBrightness];
    
    // Check login item state
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:
        @"tell application \"System Events\" to return (exists (login items whose name is \"Razer DPI\" or name is \"RazerDPI\"))"];
    NSAppleEventDescriptor *desc = [script executeAndReturnError:nil];
    _startAtLoginCheckbox.state = [desc booleanValue] ? NSControlStateValueOn : NSControlStateValueOff;
}

#pragma mark - Actions

- (void)onToggleStartAtLogin:(NSButton *)sender {
    BOOL enabled = (sender.state == NSControlStateValueOn);
    NSString *source;
    if (enabled) {
        source = @"tell application \"System Events\"\n"
                 @"  if not (exists (login items whose name is \"Razer DPI\" or name is \"RazerDPI\")) then\n"
                 @"    make login item at end with properties {path:\"/Applications/RazerDPI.app\", hidden:false, name:\"Razer DPI\"}\n"
                 @"  end if\n"
                 @"end tell";
    } else {
        source = @"tell application \"System Events\"\n"
                 @"  delete (login items whose name is \"Razer DPI\" or name is \"RazerDPI\")\n"
                 @"end tell";
    }
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:source];
    [script executeAndReturnError:nil];
}

- (void)onGrantPermissionClicked:(id)sender {
    [RazerDevice requestInputMonitoringPermission];
    [RazerDevice openInputMonitoringSettings];
    _feedbackLabel.stringValue = @"After enabling Razer DPI in Settings, restart the app.";
}

- (void)onRefreshClicked:(id)sender {
    [[RazerDevice sharedInstance] refreshDevice];
    [self updateUIFromDevice];
    _feedbackLabel.stringValue = [RazerDevice sharedInstance].isConnected ?
        @"Mouse refreshed & profile active." : @"No Razer DeathAdder found.";
}

- (void)onPresetClicked:(NSButton *)sender {
    NSInteger dpi = sender.tag;
    BOOL ok = [[RazerDevice sharedInstance] setDPI:dpi];
    if (ok) {
        _feedbackLabel.stringValue = [NSString stringWithFormat:@"Applied %ld DPI successfully.", (long)dpi];
    } else {
        _feedbackLabel.stringValue = @"Failed to apply DPI over USB.";
    }
    [self updateUIFromDevice];
}

- (void)onDpiSliderChanged:(NSSlider *)sender {
    NSInteger raw = sender.integerValue;
    NSInteger dpi = (raw / 100) * 100;
    if (dpi < 200) dpi = 200;
    if (dpi > 6400) dpi = 6400;
    
    _dpiValueLabel.stringValue = [NSString stringWithFormat:@"%ld DPI", (long)dpi];
    _customDpiField.stringValue = [NSString stringWithFormat:@"%ld", (long)dpi];
    
    [[RazerDevice sharedInstance] setDPI:dpi];
    _feedbackLabel.stringValue = [NSString stringWithFormat:@"Applied %ld DPI.", (long)dpi];
}

- (void)onCustomDpiApply:(id)sender {
    NSInteger val = [_customDpiField.stringValue integerValue];
    if (val < 200 || val > 6400) {
        _feedbackLabel.stringValue = @"DPI must be between 200 and 6400.";
        return;
    }
    BOOL ok = [[RazerDevice sharedInstance] setDPI:val];
    if (ok) {
        _feedbackLabel.stringValue = [NSString stringWithFormat:@"Applied %ld DPI successfully.", (long)val];
    } else {
        _feedbackLabel.stringValue = @"Failed to apply DPI over USB.";
    }
    [self updateUIFromDevice];
}

- (void)onEffectChanged:(NSSegmentedControl *)sender {
    RazerLightEffect effect = RazerLightEffectStatic;
    if (sender.selectedSegment == 1) {
        effect = RazerLightEffectBreathing;
    } else if (sender.selectedSegment == 2) {
        effect = RazerLightEffectOff;
    }
    
    BOOL ok = [[RazerDevice sharedInstance] setEffect:effect];
    if (ok) {
        _feedbackLabel.stringValue = @"Lighting effect updated.";
    } else {
        _feedbackLabel.stringValue = @"Failed to set lighting effect.";
    }
    [self updateUIFromDevice];
}

- (void)onBrightnessChanged:(NSSlider *)sender {
    NSInteger val = sender.integerValue;
    _brightnessLabel.stringValue = [NSString stringWithFormat:@"%ld%%", (long)val];
    [[RazerDevice sharedInstance] setBrightness:val];
}

#pragma mark - Notifications

- (void)deviceConnectionChanged:(NSNotification *)note {
    [self updateUIFromDevice];
}

- (void)deviceSettingsChanged:(NSNotification *)note {
    [self updateUIFromDevice];
}

@end
