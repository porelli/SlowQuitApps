#import "SQALAppDelegate.h"

@implementation SQALAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)_ {
    BOOL alreadyRunning = NO;
    for (NSRunningApplication *app in NSWorkspace.sharedWorkspace.runningApplications) {
        if ([app.bundleIdentifier isEqualToString:@"com.dteoh.SlowQuitApps"]) {
            alreadyRunning = YES;
            break;
        }
    }

    if (!alreadyRunning) {
        NSString *path = NSBundle.mainBundle.bundlePath;
        path = [path stringByDeletingLastPathComponent];
        path = [path stringByDeletingLastPathComponent];
        path = [path stringByDeletingLastPathComponent];
        path = [path stringByDeletingLastPathComponent];
        
        // Replace deprecated launchApplication: with modern API
        NSURL *appURL = [NSURL fileURLWithPath:path];
        NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration configuration];
        [[NSWorkspace sharedWorkspace] openApplicationAtURL:appURL
                                             configuration:configuration
                                         completionHandler:^(NSRunningApplication * _Nullable app, NSError * _Nullable error) {
            if (error) {
                NSLog(@"Failed to launch SlowQuitApps: %@", error);
            }
        }];
    }
}

@end
