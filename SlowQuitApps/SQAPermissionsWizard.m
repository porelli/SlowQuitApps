//
//  SQAPermissionsWizard.m
//  SlowQuitApps
//
//  Created on 2025-07-27.
//

#import "SQAPermissionsWizard.h"
@import QuartzCore;

@interface SQAPermissionsWizard () {
    NSTimer *verificationTimer;
}

// UI Elements
@property (nonatomic, strong) NSTextField *titleTextField;
@property (nonatomic, strong) NSTextField *descriptionTextField;
@property (nonatomic, strong) NSButton *continueButton;
@property (nonatomic, strong) NSButton *openPrefsButton;
@property (nonatomic, strong) NSButton *cancelButton;
@property (nonatomic, strong) NSView *statusIndicator;

// Completion handler
@property (nonatomic, copy) SQAPermissionsWizardCompletionHandler completionHandler;

@end

@implementation SQAPermissionsWizard

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupWindow];
        [self setupUI];
    }
    return self;
}

- (void)setupWindow {
    // Create a panel instead of a window - panels are more constrained in size
    NSRect panelRect = NSMakeRect(0, 0, 250, 300);
    NSPanel *panel = [[NSPanel alloc] initWithContentRect:panelRect
                                               styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                 backing:NSBackingStoreBuffered
                                                   defer:NO];
    
    // Configure the panel
    panel.title = @"Permissions";
    panel.titleVisibility = NSWindowTitleVisible;
    panel.titlebarAppearsTransparent = NO;
    panel.becomesKeyOnlyIfNeeded = YES;
    panel.worksWhenModal = YES;
    panel.backgroundColor = [NSColor windowBackgroundColor];
    
    // Disable resizing
    panel.styleMask &= ~NSWindowStyleMaskResizable;
    
    // Set fixed size
    panel.contentSize = NSMakeSize(250, 300);
    
    self.window = panel;
}

- (void)setupUI {
    NSView *contentView = self.window.contentView;
    
    // Create the title label
    self.titleTextField = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 250, 210, 30)];
    self.titleTextField.stringValue = @"Permissions";
    self.titleTextField.font = [NSFont boldSystemFontOfSize:16];
    self.titleTextField.bezeled = NO;
    self.titleTextField.drawsBackground = NO;
    self.titleTextField.editable = NO;
    self.titleTextField.selectable = NO;
    self.titleTextField.textColor = [NSColor labelColor];
    self.titleTextField.alignment = NSTextAlignmentCenter;
    self.titleTextField.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.titleTextField];
    
    // Create the description text field
    self.descriptionTextField = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 150, 210, 80)];
    self.descriptionTextField.stringValue = @"SlowQuitApps needs accessibility permissions.\n\nPlease click \"Open Prefs\" and check the box next to SlowQuitApps.";
    self.descriptionTextField.font = [NSFont systemFontOfSize:12];
    self.descriptionTextField.bezeled = NO;
    self.descriptionTextField.drawsBackground = NO;
    self.descriptionTextField.editable = NO;
    self.descriptionTextField.selectable = NO;
    self.descriptionTextField.lineBreakMode = NSLineBreakByWordWrapping;
    self.descriptionTextField.textColor = [NSColor labelColor];
    self.descriptionTextField.usesSingleLineMode = NO;
    self.descriptionTextField.cell.wraps = YES;
    self.descriptionTextField.cell.scrollable = NO;
    self.descriptionTextField.alignment = NSTextAlignmentCenter;
    self.descriptionTextField.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.descriptionTextField];
    
    // Create the status indicator (LED)
    self.statusIndicator = [[NSView alloc] initWithFrame:NSMakeRect(115, 130, 20, 20)];
    self.statusIndicator.wantsLayer = YES;
    self.statusIndicator.layer.cornerRadius = 10;
    self.statusIndicator.layer.borderWidth = 1;
    self.statusIndicator.layer.borderColor = [NSColor grayColor].CGColor;
    self.statusIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.statusIndicator];
    
    // Create the open preferences button
    self.openPrefsButton = [[NSButton alloc] initWithFrame:NSMakeRect(50, 90, 150, 30)];
    self.openPrefsButton.title = @"Open Prefs";
    self.openPrefsButton.bezelStyle = NSBezelStyleRounded;
    self.openPrefsButton.target = self;
    self.openPrefsButton.action = @selector(openPrefsButtonClicked:);
    self.openPrefsButton.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.openPrefsButton];
    
    // Create the continue button
    self.continueButton = [[NSButton alloc] initWithFrame:NSMakeRect(50, 50, 150, 30)];
    self.continueButton.title = @"Continue";
    self.continueButton.bezelStyle = NSBezelStyleRounded;
    self.continueButton.target = self;
    self.continueButton.action = @selector(continueButtonClicked:);
    self.continueButton.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.continueButton];
    
    // Create the cancel button
    self.cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(50, 10, 150, 30)];
    self.cancelButton.title = @"Cancel";
    self.cancelButton.bezelStyle = NSBezelStyleRounded;
    self.cancelButton.target = self;
    self.cancelButton.action = @selector(cancelButtonClicked:);
    self.cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.cancelButton];
    
    // Set up auto layout constraints
    [NSLayoutConstraint activateConstraints:@[
        // Title constraints
        [self.titleTextField.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:20],
        [self.titleTextField.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.titleTextField.widthAnchor constraintEqualToConstant:210],
        
        // Description constraints
        [self.descriptionTextField.topAnchor constraintEqualToAnchor:self.titleTextField.bottomAnchor constant:20],
        [self.descriptionTextField.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.descriptionTextField.widthAnchor constraintEqualToConstant:210],
        
        // Status indicator constraints
        [self.statusIndicator.topAnchor constraintEqualToAnchor:self.descriptionTextField.bottomAnchor constant:20],
        [self.statusIndicator.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.statusIndicator.widthAnchor constraintEqualToConstant:20],
        [self.statusIndicator.heightAnchor constraintEqualToConstant:20],
        
        // Open preferences button constraints
        [self.openPrefsButton.topAnchor constraintEqualToAnchor:self.statusIndicator.bottomAnchor constant:20],
        [self.openPrefsButton.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.openPrefsButton.widthAnchor constraintEqualToConstant:150],
        
        // Continue button constraints
        [self.continueButton.topAnchor constraintEqualToAnchor:self.openPrefsButton.bottomAnchor constant:10],
        [self.continueButton.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.continueButton.widthAnchor constraintEqualToConstant:150],
        
        // Cancel button constraints
        [self.cancelButton.topAnchor constraintEqualToAnchor:self.continueButton.bottomAnchor constant:10],
        [self.cancelButton.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.cancelButton.widthAnchor constraintEqualToConstant:150],
        [self.cancelButton.bottomAnchor constraintLessThanOrEqualToAnchor:contentView.bottomAnchor constant:-20]
    ]];
}

- (void)showWizardWithCompletionHandler:(SQAPermissionsWizardCompletionHandler)completionHandler {
    self.completionHandler = completionHandler;
    
    // Show the window
    [self showWindow:nil];
    [self.window center];
    [self.window orderFront:nil];
    
    // Make sure the window is key to receive events
    [self.window makeKeyAndOrderFront:nil];
    
    // Start checking for permissions
    [self startVerificationTimer];
    
    // Check permissions after a short delay to ensure UI is updated
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self updateStatusIndicator];
        
        // If permissions are already granted, update UI immediately
        if (AXIsProcessTrusted()) {
            NSLog(@"Permissions already granted on wizard display");
            self.statusIndicator.layer.backgroundColor = [NSColor systemGreenColor].CGColor;
            self.continueButton.enabled = YES;
            self.continueButton.keyEquivalent = @"\r";
        }
    });
}

- (BOOL)hasAccessibilityPermissions {
    // Always check the actual permissions status
    BOOL trusted = AXIsProcessTrusted();
    
    // Log the result with more details
    if (trusted) {
        NSLog(@"Accessibility permissions check in wizard: GRANTED");
    } else {
        NSLog(@"Accessibility permissions check in wizard: NOT GRANTED");
    }
    
    // Force a UI update on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateStatusIndicator];
    });
    
    return trusted;
}

- (void)openAccessibilityPreferences {
    NSURL *prefsURL = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"];
    [[NSWorkspace sharedWorkspace] openURL:prefsURL];
}

#pragma mark - Actions

- (IBAction)continueButtonClicked:(id)sender {
    // Double-check permissions before continuing
    if ([self hasAccessibilityPermissions]) {
        [self closeWizardWithSuccess:YES];
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.alertStyle = NSAlertStyleWarning;
        alert.messageText = @"Permissions Not Granted";
        alert.informativeText = @"SlowQuitApps still doesn't have accessibility permissions. Please make sure you've checked the box next to SlowQuitApps in System Preferences.";
        [alert addButtonWithTitle:@"OK"];
        [alert beginSheetModalForWindow:self.window completionHandler:nil];
    }
}

- (IBAction)openPrefsButtonClicked:(id)sender {
    [self openAccessibilityPreferences];
}

- (IBAction)cancelButtonClicked:(id)sender {
    [self closeWizardWithSuccess:NO];
}

#pragma mark - Private Methods

- (void)updateStatusIndicator {
    // Get permissions status directly
    BOOL hasPermissions = AXIsProcessTrusted();
    
    // Log the update for debugging
    NSLog(@"Updating status indicator - permissions: %@", hasPermissions ? @"GRANTED" : @"NOT GRANTED");
    
    // Update the status indicator color with animation
    [CATransaction begin];
    [CATransaction setAnimationDuration:0.3];
    
    if (hasPermissions) {
        self.statusIndicator.layer.backgroundColor = [NSColor systemGreenColor].CGColor;
        NSLog(@"Setting indicator to GREEN");
    } else {
        self.statusIndicator.layer.backgroundColor = [NSColor systemRedColor].CGColor;
        NSLog(@"Setting indicator to RED");
    }
    
    [CATransaction commit];
    
    // Enable/disable the continue button based on permissions
    self.continueButton.enabled = hasPermissions;
    
    // Update the button appearance to make the enabled state more obvious
    if (hasPermissions) {
        self.continueButton.keyEquivalent = @"\r"; // Make it the default button
    } else {
        self.continueButton.keyEquivalent = @"";
    }
}

- (void)startVerificationTimer {
    // Stop any existing timer
    [self stopVerificationTimer];
    
    // Start a timer to periodically check for permissions - use a shorter interval
    verificationTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                       repeats:YES
                                                         block:^(NSTimer * _Nonnull timer) {
        // Always run UI updates on the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateStatusIndicator];
        });
    }];
    
    // Add the timer to the run loop with multiple modes for better responsiveness
    [[NSRunLoop currentRunLoop] addTimer:verificationTimer forMode:NSRunLoopCommonModes];
    [[NSRunLoop currentRunLoop] addTimer:verificationTimer forMode:NSEventTrackingRunLoopMode];
    
    // Update the status indicator immediately
    [self updateStatusIndicator];
    
    // Also check again after a short delay to catch quick changes
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self updateStatusIndicator];
    });
}

- (void)stopVerificationTimer {
    if (verificationTimer) {
        [verificationTimer invalidate];
        verificationTimer = nil;
    }
}

- (void)closeWizardWithSuccess:(BOOL)success {
    [self stopVerificationTimer];
    
    // Close the window
    [self.window orderOut:nil];
    
    // Double-check that permissions are actually granted before reporting success
    if (success) {
        success = [self hasAccessibilityPermissions];
        if (!success) {
            NSLog(@"Warning: Wizard completed but permissions are still not granted");
        }
    }
    
    // Call the completion handler
    if (self.completionHandler) {
        self.completionHandler(success);
    }
}

@end