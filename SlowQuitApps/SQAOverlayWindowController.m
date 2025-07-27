#import "SQAOverlayWindowController.h"
#import "SQAOverlayView.h"


@interface SQAOverlayWindowController () {
@private
    SQAOverlayView *overlayView;
    NSTextField *titleView;
}
@end

@implementation SQAOverlayWindowController

- (id)init {
    self = [super initWithWindowNibName:@"SQAOverlayWindow"];
    if (self) {
        // TODO refactor this.
        // 240 = 200 (actual width of bar) + 20 (padding) + (20 padding)
        // 20 is defined in the internals of SQAOverlayView.
        const NSRect overlayFrame = NSMakeRect(0, 0, 240, 240);
        overlayView = [[SQAOverlayView alloc] initWithFrame:overlayFrame];

        titleView = [NSTextField labelWithString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ"];
        titleView.editable = NO;
        titleView.alignment = NSTextAlignmentCenter;
        titleView.font = [NSFont labelFontOfSize:18];
        titleView.textColor = NSColor.labelColor;
        [titleView sizeToFit];

        NSVisualEffectView *titleFxView = [[NSVisualEffectView alloc] init];
        titleFxView.wantsLayer = YES;
        titleFxView.layer.masksToBounds = YES;
        titleFxView.layer.cornerRadius = 2;
        titleFxView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
        titleFxView.material = NSVisualEffectMaterialSheet;
        titleFxView.state = NSVisualEffectStateActive;

        [titleFxView addSubview:titleView];

        // Create a vertical stack view to organize the UI components
        NSStackView *contentStackView = [NSStackView stackViewWithViews:@[overlayView, titleFxView]];
        // Set vertical orientation for stacking components from top to bottom
        contentStackView.orientation = NSUserInterfaceLayoutOrientationVertical;
        // Center align components horizontally
        contentStackView.alignment = NSLayoutAttributeCenterX;
        // Configure distribution for better layout control
        contentStackView.distribution = NSStackViewDistributionGravityAreas;
        // Set spacing between stack view items
        contentStackView.spacing = 0;

        [NSLayoutConstraint activateConstraints:@[
            [overlayView.widthAnchor constraintEqualToConstant:overlayFrame.size.width],
            [overlayView.heightAnchor constraintEqualToConstant:overlayFrame.size.height],

            // Add some horizontal padding to the text field.
            [titleFxView.widthAnchor constraintEqualToAnchor:titleView.widthAnchor constant:5],
            // Not padding vertically because there is no easy way to have vertically centered text...
            [titleFxView.heightAnchor constraintEqualToAnchor:titleView.heightAnchor],
        ]];

        // Create a non-activating, borderless panel that floats above other windows
        // NSWindowStyleMaskNonactivatingPanel ensures the panel won't become key window
        NSPanel *panel = [[NSPanel alloc] initWithContentRect:contentStackView.frame
                                                    styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel
                                                      backing:NSBackingStoreBuffered
                                                        defer:YES];
        panel.opaque = NO;
        panel.backgroundColor = NSColor.clearColor;
        panel.level = NSScreenSaverWindowLevel;
        panel.contentView = contentStackView;

        self.window = panel;
    }
    return self;
}

#pragma mark - SQAOverlayViewInterface implementation

- (void)showOverlay:(CGFloat)duration withTitle:(NSString * _Nonnull)title {
    titleView.stringValue = title;
    [titleView sizeToFit];

    // Show the window without making it key since it's a non-activating panel
    // Don't use showWindow: as it tries to make the window key
    NSWindow *window = [self window];
    if (window) {
        [window center];
        [window orderFront:self]; // Use orderFront instead of makeKeyAndOrderFront
    }

    overlayView.progressDuration = duration;
    [overlayView updateLayer];
}

- (void)hideOverlay {
    [self close];
}

- (void)resetOverlay {
    [overlayView reset];
}

@end
