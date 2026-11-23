#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"
#import "RazerDevice.h"

static void print_usage(const char *prog) {
    printf("Razer DeathAdder Essential Control Tool for macOS\n");
    printf("Usage: %s [options]\n\n", prog);
    printf("Options:\n");
    printf("  --dpi <200-6400>             Set DPI sensitivity\n");
    printf("  --effect <static|breathing|off> Set lighting effect\n");
    printf("  --brightness <0-100>         Set LED brightness percentage\n");
    printf("  --status                     Show connected device and settings\n");
    printf("  --help                       Show this help message\n\n");
    printf("If run without arguments, launches the menu bar GUI application.\n");
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc > 1) {
            // CLI Mode
            RazerDevice *dev = [RazerDevice sharedInstance];
            
            for (int i = 1; i < argc; i++) {
                NSString *arg = [NSString stringWithUTF8String:argv[i]];
                
                if ([arg isEqualToString:@"--help"] || [arg isEqualToString:@"-h"]) {
                    print_usage(argv[0]);
                    return 0;
                } else if ([arg isEqualToString:@"--status"] || [arg isEqualToString:@"-s"]) {
                    printf("Device:     %s\n", dev.isConnected ? [dev.productName UTF8String] : "Disconnected");
                    printf("Product ID: 0x%04x\n", dev.productId);
                    printf("DPI:        %ld\n", (long)dev.currentDPI);
                    const char *effStr = "Static";
                    if (dev.currentEffect == RazerLightEffectBreathing) effStr = "Breathing";
                    else if (dev.currentEffect == RazerLightEffectOff) effStr = "Off";
                    printf("Lighting:   %s\n", effStr);
                    printf("Brightness: %ld%%\n", (long)dev.currentBrightness);
                    return dev.isConnected ? 0 : 1;
                } else if ([arg isEqualToString:@"--dpi"] && i + 1 < argc) {
                    NSInteger dpi = atoi(argv[++i]);
                    if (dpi < 200 || dpi > 6400) {
                        fprintf(stderr, "Error: DPI must be between 200 and 6400\n");
                        return 1;
                    }
                    if (!dev.isConnected) {
                        fprintf(stderr, "Error: Razer DeathAdder Essential not connected\n");
                        return 1;
                    }
                    BOOL ok = [dev setDPI:dpi];
                    if (ok) {
                        printf("Successfully set DPI to %ld\n", (long)dpi);
                    } else {
                        fprintf(stderr, "Failed to set DPI over USB\n");
                        return 1;
                    }
                } else if ([arg isEqualToString:@"--effect"] && i + 1 < argc) {
                    NSString *eff = [NSString stringWithUTF8String:argv[++i]].lowercaseString;
                    RazerLightEffect mode = RazerLightEffectStatic;
                    if ([eff isEqualToString:@"breathing"] || [eff isEqualToString:@"breath"]) {
                        mode = RazerLightEffectBreathing;
                    } else if ([eff isEqualToString:@"off"] || [eff isEqualToString:@"none"]) {
                        mode = RazerLightEffectOff;
                    } else if (![eff isEqualToString:@"static"]) {
                        fprintf(stderr, "Error: Effect must be static, breathing, or off\n");
                        return 1;
                    }
                    if (!dev.isConnected) {
                        fprintf(stderr, "Error: Razer DeathAdder Essential not connected\n");
                        return 1;
                    }
                    BOOL ok = [dev setEffect:mode];
                    if (ok) {
                        printf("Successfully set effect to %s\n", [eff UTF8String]);
                    } else {
                        fprintf(stderr, "Failed to set effect over USB\n");
                        return 1;
                    }
                } else if ([arg isEqualToString:@"--brightness"] && i + 1 < argc) {
                    NSInteger b = atoi(argv[++i]);
                    if (b < 0 || b > 100) {
                        fprintf(stderr, "Error: Brightness must be between 0 and 100\n");
                        return 1;
                    }
                    if (!dev.isConnected) {
                        fprintf(stderr, "Error: Razer DeathAdder Essential not connected\n");
                        return 1;
                    }
                    BOOL ok = [dev setBrightness:b];
                    if (ok) {
                        printf("Successfully set brightness to %ld%%\n", (long)b);
                    } else {
                        fprintf(stderr, "Failed to set brightness over USB\n");
                        return 1;
                    }
                } else {
                    fprintf(stderr, "Unknown option: %s\n", argv[i]);
                    print_usage(argv[0]);
                    return 1;
                }
            }
            return 0;
        }
        
        // GUI Mode
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        return NSApplicationMain(argc, argv);
    }
}
