#import "AppDelegate.h"
#import "RazerDevice.h"
#import "ControlWindow.h"

@interface AppDelegate ()

@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSMenu *menu;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory]; // Menu bar app
    
    // Check permission
    if (![RazerDevice hasInputMonitoringPermission]) {
        [RazerDevice requestInputMonitoringPermission];
    }
    
    // Initialize RazerDevice
    [RazerDevice sharedInstance];
    
    // Setup Menu Bar Status Item
    [self setupStatusItem];
    
    // Listen to device notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onDeviceUpdate:)
                                                 name:RazerDeviceConnectionChangedNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onDeviceUpdate:)
                                                 name:RazerDeviceSettingsChangedNotification
                                               object:nil];
}

- (void)setupStatusItem {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    
    // Create mouse template icon
    NSImage *icon = [self createMouseIcon];
    [self.statusItem.button setImage:icon];
    [self.statusItem.button setImagePosition:NSImageLeft];
    
    [self updateStatusItemText];
    [self rebuildMenu];
}

- (NSImage *)createMouseIcon {
    NSSize size = NSMakeSize(18, 18);
    NSImage *image = [NSImage imageWithSize:size flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        NSBezierPath *path = [NSBezierPath bezierPath];
        NSRect body = NSMakeRect(3.5, 1.5, 11, 15);
        path = [NSBezierPath bezierPathWithRoundedRect:body xRadius:5 yRadius:5];
        [path setLineWidth:1.5];
        [[NSColor labelColor] setStroke];
        [path stroke];
        
        NSBezierPath *wheel = [NSBezierPath bezierPath];
        [wheel moveToPoint:NSMakePoint(9.0, 11.5)];
        [wheel lineToPoint:NSMakePoint(9.0, 14.0)];
        [wheel setLineWidth:1.5];
        [wheel stroke];
        return YES;
    }];
    [image setTemplate:YES];
    return image;
}

- (void)updateStatusItemText {
    RazerDevice *dev = [RazerDevice sharedInstance];
    BOOL hasPerm = [RazerDevice hasInputMonitoringPermission];
    
    if (dev.isConnected) {
        self.statusItem.button.title = [NSString stringWithFormat:@" %ld", (long)dev.currentDPI];
        self.statusItem.button.toolTip = [NSString stringWithFormat:@"%@: %ld DPI", dev.productName, (long)dev.currentDPI];
    } else {
        if (!hasPerm) {
            self.statusItem.button.title = @" ⚠️";
            self.statusItem.button.toolTip = @"Razer DPI: Input Monitoring Permission Required";
        } else {
            self.statusItem.button.title = @"";
            self.statusItem.button.toolTip = @"Razer Mouse Disconnected";
        }
    }
}

- (void)rebuildMenu {
    RazerDevice *dev = [RazerDevice sharedInstance];
    BOOL hasPerm = [RazerDevice hasInputMonitoringPermission];
    
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Razer DPI"];
    menu.delegate = self;
    
    if (!hasPerm) {
        NSMenuItem *permAlert = [[NSMenuItem alloc] initWithTitle:@"⚠️ Input Monitoring Permission Needed" action:nil keyEquivalent:@""];
        permAlert.enabled = NO;
        [menu addItem:permAlert];
        
        NSMenuItem *grantItem = [[NSMenuItem alloc] initWithTitle:@"    Grant Permission in Settings..." action:@selector(onOpenPermissionSettings:) keyEquivalent:@""];
        grantItem.target = self;
        [menu addItem:grantItem];
        
        [menu addItem:[NSMenuItem separatorItem]];
    }
    
    // Header
    NSString *headerText = dev.isConnected ?
        [NSString stringWithFormat:@"%@  ●", dev.productName] :
        @"Razer Mouse Disconnected  ○";
    NSMenuItem *headerItem = [[NSMenuItem alloc] initWithTitle:headerText action:nil keyEquivalent:@""];
    headerItem.enabled = NO;
    [menu addItem:headerItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // DPI Section
    NSMenuItem *dpiHeader = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"DPI: %ld", (long)dev.currentDPI] action:nil keyEquivalent:@""];
    dpiHeader.enabled = NO;
    [menu addItem:dpiHeader];
    
    NSArray *presets = @[@400, @800, @1600, @3200, @6400];
    for (NSNumber *p in presets) {
        NSInteger val = [p integerValue];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"    %ld DPI", (long)val]
                                                      action:@selector(onSelectDPI:)
                                               keyEquivalent:@""];
        item.target = self;
        item.tag = val;
        if (dev.isConnected && dev.currentDPI == val) {
            item.state = NSControlStateValueOn;
        }
        item.enabled = dev.isConnected;
        [menu addItem:item];
    }
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Lighting Section
    NSString *effectStr = @"Static";
    if (dev.currentEffect == RazerLightEffectBreathing) effectStr = @"Breathing";
    else if (dev.currentEffect == RazerLightEffectOff) effectStr = @"Off";
    
    NSMenuItem *lightHeader = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Lighting: %@", effectStr] action:nil keyEquivalent:@""];
    lightHeader.enabled = NO;
    [menu addItem:lightHeader];
    
    NSMenuItem *staticItem = [[NSMenuItem alloc] initWithTitle:@"    Static (Solid Green)" action:@selector(onSelectEffect:) keyEquivalent:@""];
    staticItem.target = self;
    staticItem.tag = RazerLightEffectStatic;
    staticItem.state = (dev.currentEffect == RazerLightEffectStatic) ? NSControlStateValueOn : NSControlStateValueOff;
    staticItem.enabled = dev.isConnected;
    [menu addItem:staticItem];
    
    NSMenuItem *breathItem = [[NSMenuItem alloc] initWithTitle:@"    Breathing (Pulse)" action:@selector(onSelectEffect:) keyEquivalent:@""];
    breathItem.target = self;
    breathItem.tag = RazerLightEffectBreathing;
    breathItem.state = (dev.currentEffect == RazerLightEffectBreathing) ? NSControlStateValueOn : NSControlStateValueOff;
    breathItem.enabled = dev.isConnected;
    [menu addItem:breathItem];
    
    NSMenuItem *offItem = [[NSMenuItem alloc] initWithTitle:@"    Turn Off Light" action:@selector(onSelectEffect:) keyEquivalent:@""];
    offItem.target = self;
    offItem.tag = RazerLightEffectOff;
    offItem.state = (dev.currentEffect == RazerLightEffectOff) ? NSControlStateValueOn : NSControlStateValueOff;
    offItem.enabled = dev.isConnected;
    [menu addItem:offItem];
    
    // Brightness submenu
    NSMenuItem *brightMenu = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"    Brightness: %ld%%", (long)dev.currentBrightness] action:nil keyEquivalent:@""];
    brightMenu.enabled = dev.isConnected;
    NSMenu *subBright = [[NSMenu alloc] initWithTitle:@"Brightness"];
    NSArray *brightLevels = @[@100, @75, @50, @25, @0];
    for (NSNumber *b in brightLevels) {
        NSInteger bVal = [b integerValue];
        NSMenuItem *bItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%ld%%", (long)bVal]
                                                       action:@selector(onSelectBrightness:)
                                                keyEquivalent:@""];
        bItem.target = self;
        bItem.tag = bVal;
        if (dev.currentBrightness == bVal) bItem.state = NSControlStateValueOn;
        [subBright addItem:bItem];
    }
    brightMenu.submenu = subBright;
    [menu addItem:brightMenu];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Open Control Panel
    NSMenuItem *panelItem = [[NSMenuItem alloc] initWithTitle:@"Open Control Panel..." action:@selector(openControlPanel:) keyEquivalent:@"o"];
    panelItem.target = self;
    [menu addItem:panelItem];
    
    // Start at Login toggle
    BOOL isLoginItem = [AppDelegate isStartAtLoginEnabled];
    NSMenuItem *loginItem = [[NSMenuItem alloc] initWithTitle:@"Start at Login" action:@selector(toggleStartAtLogin:) keyEquivalent:@""];
    loginItem.target = self;
    loginItem.state = isLoginItem ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:loginItem];

    // Refresh Device
    NSMenuItem *refreshItem = [[NSMenuItem alloc] initWithTitle:@"Refresh Device" action:@selector(onRefreshDevice:) keyEquivalent:@"r"];
    refreshItem.target = self;
    [menu addItem:refreshItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Quit
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit Razer DPI" action:@selector(quitApp:) keyEquivalent:@"q"];
    quitItem.target = self;
    [menu addItem:quitItem];
    
    self.menu = menu;
    self.statusItem.menu = menu;
}

#pragma mark - Menu Delegate

- (void)menuWillOpen:(NSMenu *)menu {
    [self rebuildMenu];
}

#pragma mark - Actions

+ (BOOL)isStartAtLoginEnabled {
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:
        @"tell application \"System Events\" to return (exists (login items whose name is \"Razer DPI\" or name is \"RazerDPI\"))"];
    NSAppleEventDescriptor *desc = [script executeAndReturnError:nil];
    return [desc booleanValue];
}

+ (void)setStartAtLoginEnabled:(BOOL)enabled {
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

- (void)toggleStartAtLogin:(NSMenuItem *)sender {
    BOOL current = [AppDelegate isStartAtLoginEnabled];
    [AppDelegate setStartAtLoginEnabled:!current];
    [self rebuildMenu];
}

- (void)onOpenPermissionSettings:(id)sender {
    [RazerDevice requestInputMonitoringPermission];
    [RazerDevice openInputMonitoringSettings];
}

- (void)onSelectDPI:(NSMenuItem *)sender {
    [[RazerDevice sharedInstance] setDPI:sender.tag];
    [self updateStatusItemText];
}

- (void)onSelectEffect:(NSMenuItem *)sender {
    [[RazerDevice sharedInstance] setEffect:(RazerLightEffect)sender.tag];
}

- (void)onSelectBrightness:(NSMenuItem *)sender {
    [[RazerDevice sharedInstance] setBrightness:sender.tag];
}

- (void)openControlPanel:(id)sender {
    [[ControlWindow sharedController] bringToFront];
}

- (void)onRefreshDevice:(id)sender {
    [[RazerDevice sharedInstance] refreshDevice];
    [self updateStatusItemText];
    [self rebuildMenu];
}

- (void)quitApp:(id)sender {
    [NSApp terminate:nil];
}

- (void)onDeviceUpdate:(NSNotification *)note {
    [self updateStatusItemText];
    [self rebuildMenu];
}

@end
