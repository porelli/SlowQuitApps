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

@property (nonatomic, strong) SQADialogs *dialogs;
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
    self.dialogs = [[SQADialogs alloc] init];

    // Handle autostart preferences
    if ([SQAPreferences disableAutostart]) {
        [SQAAutostart disable];
    } else if (![SQAAutostart isEnabled]) {
        [self.dialogs askAboutAutoStart];
    }

    // Check for accessibility permissions
    if (!hasAccessibility()) {
        NSLog(@"Accessibility permissions not granted, showing permissions wizard");
        
        // Show our step-by-step wizard to guide the user through granting permissions
        [self.dialogs showAccessibilityPermissionsWizard:^(BOOL granted) {
            if (granted) {
                // User completed the wizard and permissions were granted
                NSLog(@"Accessibility permissions granted through wizard, continuing setup");
                [self continueSetupWithPermissions];
            } else {
                // User canceled the wizard
                NSLog(@"User canceled permissions wizard, quitting");
                [NSApp terminate:self];
            }
        }];
        
        // Keep the app visible until permissions are granted
        return;
    }
    
    // If we already have permissions, continue with setup
    [self continueSetupWithPermissions];
}

// This method is no longer needed as we're using the interactive dialog approach
// Keeping it commented out for reference
/*
- (void)checkAccessibilityAndContinue {
    // Check if accessibility permissions have been granted
    if (hasAccessibility()) {
        NSLog(@"Accessibility permissions granted, continuing setup");
        
        // Stop the timer
        [self.accessibilityCheckTimer invalidate];
        self.accessibilityCheckTimer = nil;
        
        // Continue with setup now that we have permissions
        [self continueSetupWithPermissions];
    } else {
        NSLog(@"Waiting for accessibility permissions...");
    }
}
*/

- (void)continueSetupWithPermissions {
    // Double-check that we have accessibility permissions before proceeding
    if (!hasAccessibility()) {
        NSLog(@"Accessibility permissions still not granted, showing wizard again");
        
        // Show our step-by-step wizard to guide the user through granting permissions
        [self.dialogs showAccessibilityPermissionsWizard:^(BOOL granted) {
            if (granted) {
                // User completed the wizard and permissions were granted
                NSLog(@"Accessibility permissions granted through wizard, continuing setup");
                [self continueSetupWithPermissions];
            } else {
                // User canceled the wizard
                NSLog(@"User canceled permissions wizard, quitting");
                [NSApp terminate:self];
            }
        }];
        
        return;
    }
    
    // Register the global hotkey
    if ([self registerGlobalHotkeyCG]) {
        // Hide from dock, command tab, etc.
        // Not using LSBackgroundOnly so that we can display NSAlerts beforehand
        [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
    } else {
        // Always show the permissions wizard first when hotkey registration fails
        // This ensures we catch all possible permission-related issues
        NSLog(@"Hotkey registration failed, showing permissions wizard");
        
        // Show our step-by-step wizard to guide the user through granting permissions
        [self.dialogs showAccessibilityPermissionsWizard:^(BOOL granted) {
            if (granted) {
                // User completed the wizard and permissions were granted
                NSLog(@"Accessibility permissions granted through wizard, trying to register hotkey again");
                [self continueSetupWithPermissions];
            } else {
                // User canceled the wizard
                NSLog(@"User canceled permissions wizard, quitting");
                [NSApp terminate:self];
            }
        }];
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
    // First, explicitly check for accessibility permissions
    if (!hasAccessibility()) {
        NSLog(@"Cannot register global hotkey - accessibility permissions not granted");
        
        // Show the permissions wizard
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.dialogs showAccessibilityPermissionsWizard:^(BOOL granted) {
                if (granted) {
                    // User completed the wizard and permissions were granted
                    NSLog(@"Accessibility permissions granted through wizard, trying to register hotkey again");
                    [self continueSetupWithPermissions];
                } else {
                    // User canceled the wizard
                    NSLog(@"User canceled permissions wizard, quitting");
                    [NSApp terminate:self];
                }
            }];
        });
        
        return false;
    }
    
    // Create event mask for keyboard events
    CGEventMask eventMask = CGEventMaskBit(kCGEventFlagsChanged) |
                           CGEventMaskBit(kCGEventKeyDown) |
                           CGEventMaskBit(kCGEventKeyUp);
    
    NSLog(@"Attempting to create event tap...");
    
    // Create event tap
    CFMachPortRef port = CGEventTapCreate(kCGHIDEventTap,
                                         kCGHeadInsertEventTap,
                                         kCGEventTapOptionDefault,
                                         eventMask,
                                         &eventTapHandler,
                                         (__bridge void *)self);
    if (!port) {
        NSLog(@"Failed to create event tap - this typically happens when accessibility permissions are not granted");
        
        // Show the permissions wizard since this is likely a permissions issue
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.dialogs showAccessibilityPermissionsWizard:^(BOOL granted) {
                if (granted) {
                    // User completed the wizard and permissions were granted
                    NSLog(@"Accessibility permissions granted through wizard, trying to register hotkey again");
                    [self continueSetupWithPermissions];
                } else {
                    // User canceled the wizard
                    NSLog(@"User canceled permissions wizard, quitting");
                    [NSApp terminate:self];
                }
            }];
        });
        
        return false;
    }

    NSLog(@"Event tap created successfully");
    
    // Create run loop source
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0);
    if (!runLoopSource) {
        NSLog(@"Failed to create run loop source");
        CFRelease(port);
        return false;
    }
    
    NSLog(@"Run loop source created successfully");
    
    // Add to current run loop
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
    
    // Enable the event tap
    CGEventTapEnable(port, true);
    
    NSLog(@"Event tap enabled, starting run loop");
    
    // Start the run loop
    CFRunLoopRun();

    // Store references for cleanup
    eventTapPort = port;
    eventRunLoop = runLoopSource;
    
    // Create event source
    appEventSource = CGEventSourceCreate(kCGEventSourceStatePrivate);
    if (!appEventSource) {
        NSLog(@"Failed to create event source - continuing anyway as this is not critical");
        // Continue anyway as this is not critical
    } else {
        NSLog(@"Event source created successfully");
    }

    NSLog(@"Global hotkey registration completed successfully");
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

// Check if accessibility permissions are granted without showing the prompt
static BOOL hasAccessibility(void) {
    // Track the last known state to reduce logging
    static BOOL lastKnownState = NO;
    static BOOL initialized = NO;
    
    // Always check the actual permissions status
    BOOL trusted = AXIsProcessTrusted();
    
    // Only log when the state changes or on first check
    if (!initialized || trusted != lastKnownState) {
        if (trusted) {
            NSLog(@"Accessibility permissions check: GRANTED");
        } else {
            NSLog(@"Accessibility permissions check: NOT GRANTED");
        }
        
        // Update the last known state
        lastKnownState = trusted;
        initialized = YES;
    }
    
    return trusted;
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
    
    // Check if we still have accessibility permissions
    // This handles the case where permissions are revoked while the app is running
    if (!hasAccessibility()) {
        NSLog(@"Accessibility permissions have been revoked while app is running");
        
        // Get delegate from user info
        SQAAppDelegate *delegate = (__bridge SQAAppDelegate *)userInfo;
        if (delegate) {
            // Show the permissions wizard
            dispatch_async(dispatch_get_main_queue(), ^{
                [delegate.dialogs showAccessibilityPermissionsWizard:^(BOOL granted) {
                    if (granted) {
                        // User completed the wizard and permissions were granted
                        NSLog(@"Accessibility permissions granted through wizard, continuing");
                    } else {
                        // User canceled the wizard
                        NSLog(@"User canceled permissions wizard, quitting");
                        [NSApp terminate:delegate];
                    }
                }];
            });
        }
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
