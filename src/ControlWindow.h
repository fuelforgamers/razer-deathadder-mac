#import <Cocoa/Cocoa.h>

@interface ControlWindow : NSWindowController

+ (instancetype)sharedController;
- (void)bringToFront;

@end
