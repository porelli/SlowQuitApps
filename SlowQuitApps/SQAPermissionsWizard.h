//
//  SQAPermissionsWizard.h
//  SlowQuitApps
//
//  Created on 2025-07-27.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Completion handler for the permissions wizard.
 * @param granted YES if permissions were granted, NO otherwise.
 */
typedef void (^SQAPermissionsWizardCompletionHandler)(BOOL granted);

/**
 * A wizard that guides the user through setting up accessibility permissions.
 * This class provides a simple interface with a status indicator to help users
 * understand and grant the necessary permissions for SlowQuitApps to function properly.
 */
@interface SQAPermissionsWizard : NSWindowController

/**
 * Shows the permissions wizard and calls the completion handler when done.
 * @param completionHandler Called when the wizard is dismissed, with a boolean
 *                         indicating whether permissions were granted.
 */
- (void)showWizardWithCompletionHandler:(SQAPermissionsWizardCompletionHandler)completionHandler;

/**
 * Checks if accessibility permissions are granted.
 * @return YES if permissions are granted, NO otherwise.
 */
- (BOOL)hasAccessibilityPermissions;

/**
 * Opens the Accessibility preferences pane in System Preferences.
 */
- (void)openAccessibilityPreferences;

@end

NS_ASSUME_NONNULL_END