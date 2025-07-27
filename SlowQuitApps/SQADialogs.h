@import Foundation;

typedef void (^SQADialogCompletionHandler)(BOOL granted);

@interface SQADialogs : NSObject

- (void)askAboutAutoStart;
- (void)informHotkeyRegistrationFailure;
- (void)informAccessibilityRequirement;

// Shows an interactive dialog for accessibility permissions with options to open System Preferences
// and retry after granting permissions. The completion handler is called with YES if the user
// indicates they've granted permissions, or NO if they cancel.
- (void)showAccessibilityPermissionsDialog:(SQADialogCompletionHandler)completionHandler;

// Shows a step-by-step wizard to guide the user through granting accessibility permissions.
// This provides a more interactive and user-friendly experience than the simple dialog.
- (void)showAccessibilityPermissionsWizard:(SQADialogCompletionHandler)completionHandler;

// Opens System Preferences to the Accessibility pane
- (void)openAccessibilityPreferences;

@end
