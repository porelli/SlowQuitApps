#import "SQADialogs.h"
#import "SQAAutostart.h"
#import "SQAPermissionsWizard.h"

@interface SQADialogs ()

@property (nonatomic, strong) SQAPermissionsWizard *permissionsWizard;

@end

@implementation SQADialogs

- (void)askAboutAutoStart {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleInformational;
    alert.messageText = NSLocalizedString(@"Automatically launch SlowQuitApps on login?", nil);
    alert.informativeText = NSLocalizedString(@"Would you like to register SlowQuitApps to automatically launch when you login?", nil);
    [alert addButtonWithTitle:NSLocalizedString(@"Yes", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"No", nil)];
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return;
    }

    if ([self registerLoginItem]) {
        return;
    }

    [self informLoginItemRegistrationFailure];
}

- (void)informLoginItemRegistrationFailure {
    NSAlert *warning = [[NSAlert alloc] init];
    warning.alertStyle = NSAlertStyleWarning;
    warning.messageText = NSLocalizedString(@"Failed to register SlowQuitApps to launch on login", nil);
    [warning addButtonWithTitle:NSLocalizedString(@"OK", nil)];
    [warning runModal];
}

- (BOOL)registerLoginItem {
    return [SQAAutostart enable];
}

- (void)informHotkeyRegistrationFailure {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleCritical;
    alert.messageText = NSLocalizedString(@"SlowQuitApps cannot register ⌘Q", nil);
    alert.informativeText = NSLocalizedString(@"Another application has exclusive control of ⌘Q, SlowQuitApps cannot continue. SlowQuitApps will exit.", nil);
    [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
    [alert runModal];
}

- (void)informAccessibilityRequirement {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleInformational;
    alert.messageText = NSLocalizedString(@"SlowQuitApps requires permissions to control your computer", nil);
    alert.informativeText = NSLocalizedString(@"SlowQuitApps needs accessibility permissions to handle ⌘Q.\r\rAfter adding SlowQuitApps to System Preferences -> Security & Privacy -> Privacy -> Accessibility, please restart the app.", nil);
    [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
    [alert runModal];
}

- (void)showAccessibilityPermissionsDialog:(SQADialogCompletionHandler)completionHandler {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleInformational;
    alert.messageText = NSLocalizedString(@"SlowQuitApps requires Accessibility permissions", nil);
    alert.informativeText = NSLocalizedString(@"SlowQuitApps needs accessibility permissions to handle ⌘Q.\n\nPlease follow these steps:\n\n1. Click \"Open System Preferences\"\n2. Click the lock icon to make changes\n3. Check the box next to SlowQuitApps\n4. Click \"I've granted permission\" to continue", nil);
    
    // Add buttons
    [alert addButtonWithTitle:NSLocalizedString(@"Open System Preferences", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"I've granted permission", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Quit", nil)];
    
    // Run the alert as a sheet
    NSModalResponse response = [alert runModal];
    
    if (response == NSAlertFirstButtonReturn) {
        // User clicked "Open System Preferences"
        [self openAccessibilityPreferences];
        
        // Show the dialog again after a short delay
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self showAccessibilityPermissionsDialog:completionHandler];
        });
    } else if (response == NSAlertSecondButtonReturn) {
        // User clicked "I've granted permission"
        if (completionHandler) {
            completionHandler(YES);
        }
    } else {
        // User clicked "Quit" or closed the dialog
        if (completionHandler) {
            completionHandler(NO);
        }
    }
}

- (void)openAccessibilityPreferences {
    NSURL *prefsURL = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"];
    [[NSWorkspace sharedWorkspace] openURL:prefsURL];
}

- (void)showAccessibilityPermissionsWizard:(SQADialogCompletionHandler)completionHandler {
    // Create the wizard if it doesn't exist
    if (!self.permissionsWizard) {
        self.permissionsWizard = [[SQAPermissionsWizard alloc] init];
    }
    
    // Show the wizard
    [self.permissionsWizard showWizardWithCompletionHandler:^(BOOL granted) {
        // Clean up the wizard
        self.permissionsWizard = nil;
        
        // Call the completion handler
        if (completionHandler) {
            completionHandler(granted);
        }
    }];
}

@end
