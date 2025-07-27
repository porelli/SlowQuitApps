@import Carbon;
#import "SQAAppDelegate.h"
#import "SQADialogs.h"
#import "SQAOverlayWindowController.h"
#import "SQAPreferences.h"
#import "SQAStateMachine.h"
#import "SQAAutostart.h"

// Forward declarations of static helper functions
static NSRunningApplication* _Nullable findActiveApp(void);
static BOOL hasAccessibility(void);
static CGEventRef eventTapHandler(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo);
static NSString * _Nullable stringFromCGKeyboardEvent(CGEventRef event);

@interface SQAAppDelegate() {
@private
    SQAStateMachine * _Nullable stateMachine;
    id<SQAOverlayViewInterface> _Nullable overlayView;
    CFMachPortRef _Nullable eventTapPort;
    CFRunLoopSourceRef _Nullable eventRunLoop;
    CGEventSourceRef _Nullable appEventSource;
    BOOL appSwitcherActive;
}
@end

@implementation SQAAppDelegate

- (instancetype)init {
    self = [super init];
    if (!self) { return self; }

    if ([SQAPreferences displayOverlay]) {
        overlayView = [[SQAOverlayWindowController alloc] init];
    }

    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    SQADialogs *dialogs = [[SQADialogs alloc] init];

    if (!hasAccessibility()) {
        [dialogs informAccessibilityRequirement];
        // If we terminate now, the special accesibility alert/dialog
        // from the framework/OS will dissappear immediately.
        return;
    }

    if ([SQAPreferences disableAutostart]) {
        [SQAAutostart disable];
    } else if (![SQAAutostart isEnabled]) {
        [dialogs askAboutAutoStart];
    }

    if ([self registerGlobalHotkeyCG]) {
        // Hide from dock, command tab, etc.
        // Not using LSBackgroundOnly so that we can display NSAlerts beforehand
        [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
    } else {
        [dialogs informHotkeyRegistrationFailure];
        [NSApp terminate:self];
    }
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    if (eventTapPort) {
        CFRelease(eventTapPort);
    }
    if (eventRunLoop) {
        CFRelease(eventRunLoop);
    }
    if (appEventSource) {
        CFRelease(appEventSource);
    }
}

- (BOOL)registerGlobalHotkeyCG {
    // Create event mask for keyboard events
    CGEventMask eventMask = CGEventMaskBit(kCGEventFlagsChanged) |
                           CGEventMaskBit(kCGEventKeyDown) |
                           CGEventMaskBit(kCGEventKeyUp);
    
    // Create event tap
    CFMachPortRef port = CGEventTapCreate(kCGHIDEventTap,
                                         kCGHeadInsertEventTap,
                                         kCGEventTapOptionDefault,
                                         eventMask,
                                         &eventTapHandler,
                                         (__bridge void *)self);
    if (!port) {
        NSLog(@"Failed to create event tap");
        return false;
    }

    // Create run loop source
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0);
    if (!runLoopSource) {
        NSLog(@"Failed to create run loop source");
        CFRelease(port);
        return false;
    }
    
    // Add to current run loop
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
    
    // Enable the event tap
    CGEventTapEnable(port, true);
    
    // Start the run loop
    CFRunLoopRun();

    // Store references for cleanup
    eventTapPort = port;
    eventRunLoop = runLoopSource;
    
    // Create event source
    appEventSource = CGEventSourceCreate(kCGEventSourceStatePrivate);
    if (!appEventSource) {
        NSLog(@"Failed to create event source");
        // Continue anyway as this is not critical
    }

    return true;
}

- (void)cmdQPressed {
    if (stateMachine) {
        [stateMachine holding];
        return;
    }

    stateMachine = [[SQAStateMachine alloc] initWithEventSource:appEventSource];
    __weak typeof(stateMachine) weakSM = stateMachine;
    __weak typeof(overlayView) weakOverlay = overlayView;
    __weak typeof(self) weakSelf = self;

    if (overlayView) {
        stateMachine.onStart = ^{
            NSString *appTitle = @"";
            NSRunningApplication *app = findActiveApp();
            if (app) {
                appTitle = [app localizedName] ?: @"";
            }
            [weakOverlay showOverlay:weakSM.completionDurationInSeconds
                           withTitle:appTitle];
        };
        stateMachine.onCompletion = ^{
            NSRunningApplication *app = findActiveApp();
            if (app) {
                [app terminate];
            }
            [weakOverlay hideOverlay];
            [weakOverlay resetOverlay];
        };
        stateMachine.onCancelled = ^{
            [weakOverlay hideOverlay];
            [weakOverlay resetOverlay];
            [weakSelf destroyStateMachine];
        };
    } else {
        stateMachine.onCompletion = ^{
            NSRunningApplication *app = findActiveApp();
            if (app) {
                [app terminate];
            }
        };
        stateMachine.onCancelled = ^{
            [weakSelf destroyStateMachine];
        };
    }

    [stateMachine holding];
}

- (void)cmdQNotPressed {
    if (stateMachine) {
        [stateMachine cancelled];
    }
    [self destroyStateMachine];
}

- (void)appSwitcherOpened {
    appSwitcherActive = YES;
}

- (void)appSwitcherClosed {
    appSwitcherActive = NO;
}

- (void)destroyStateMachine {
    stateMachine = nil;
}

- (CGEventSourceRef)appEventSource {
    return appEventSource;
}

- (BOOL)shouldHandleCmdQ {
    if (appSwitcherActive) {
        return NO;
    }

    NSRunningApplication *activeApp = findActiveApp();
    if (activeApp == NULL) {
        return NO;
    }
    if ([activeApp.bundleIdentifier isEqualToString:@"com.apple.finder"]) {
        return NO;
    }

    BOOL invertList = [SQAPreferences invertList];
    for (NSString *bundleId in [SQAPreferences whitelist]) {
        if ([activeApp.bundleIdentifier isEqualToString:bundleId]) {
            return (invertList ? YES : NO);
        }
    }
    return (invertList ? NO : YES);
}

#pragma mark - Helper Functions

static NSRunningApplication* _Nullable findActiveApp(void) {
    return [[NSWorkspace sharedWorkspace] menuBarOwningApplication];
}

static BOOL hasAccessibility(void) {
#if defined(DEBUG)
    return YES;
#else
    NSDictionary *options = @{(__bridge id)kAXTrustedCheckOptionPrompt: @YES};
    return AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
#endif
}

static NSString * _Nullable stringFromCGKeyboardEvent(CGEventRef event) {
    if (!event) return nil;
    
    UniCharCount actualStringLength = 0;
    UniChar unicodeString[4] = {0, 0, 0, 0};
    CGEventKeyboardGetUnicodeString(event, 1, &actualStringLength, unicodeString);
    return [NSString stringWithCharacters:unicodeString length:actualStringLength];
}

// Constants for key detection
static NSString * const kQKey = @"q";
static NSString * const kTabKey = @"\t";

static CGEventRef eventTapHandler(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    // Early return for non-keyboard events
    if (type != kCGEventFlagsChanged && type != kCGEventKeyDown && type != kCGEventKeyUp) {
        return event;
    }
    
    // Get delegate from user info
    SQAAppDelegate *delegate = (__bridge SQAAppDelegate *)userInfo;
    if (!delegate) return event;

    // Get key as string
    NSString *stringedKey = stringFromCGKeyboardEvent(event);
    if (!stringedKey) return event;
    
    // Get modifier flags
    CGEventFlags flags = CGEventGetFlags(event);
    BOOL command = (flags & kCGEventFlagMaskCommand) == kCGEventFlagMaskCommand;
    BOOL ctrl = (flags & kCGEventFlagMaskControl) == kCGEventFlagMaskControl;
    
    // Check for specific keys
    BOOL q = [kQKey isEqualToString:stringedKey];
    BOOL tab = [kTabKey isEqualToString:stringedKey];

    // App switcher detection
    if (command && tab) {
        [delegate appSwitcherOpened];
    } else if (!command && !tab) {
        [delegate appSwitcherClosed];
    }

    // Ignore:
    // * something that wont start Cmd + Q
    // * key sequence for starting screen lock activation (Cmd + ^ + Q)
    if (!command || !q || (command && ctrl)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate cmdQNotPressed];
        });
        return event;
    }

    // Handle Cmd+Q if needed
    if ([delegate shouldHandleCmdQ]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate cmdQPressed];
        });

        // Modify the event to prevent standard Cmd+Q behavior
        CGEventSetFlags(event, 0);
        CGEventSetIntegerValueField(event, kCGKeyboardEventKeycode, kVK_Command);
        
        // Set the source state ID
        CGEventSourceRef eventSource = [delegate appEventSource];
        if (eventSource) {
            CGEventSetIntegerValueField(event, kCGEventSourceStateID,
                                       CGEventSourceGetSourceStateID(eventSource));
        }
        
        return event;
    }

    // Default case - not handling Cmd+Q
    dispatch_async(dispatch_get_main_queue(), ^{
        [delegate cmdQNotPressed];
    });
    return event;
}

@end
