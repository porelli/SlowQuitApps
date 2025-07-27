@import QuartzCore;
#import "SQAOverlayView.h"

// Constants for layout and appearance
static const CGFloat kPaddingSize = 20.0;
static const CGFloat kTrackLineWidth = 30.0;
static const CGFloat kBarLineWidth = 27.0;

// Helper function declarations
static CGFloat deg2Rad(const CGFloat deg);
static CGRect smallerCenteredRect(const CGRect rect, const CGFloat pixels);
static CAShapeLayer * makeTemplate(const CGRect frame);

@interface SQAOverlayView() {
@private
    CAShapeLayer *bar;
    CAShapeLayer *outline;
    CAShapeLayer *track;
    CABasicAnimation *strokeAnimation;
}
@end

@implementation SQAOverlayView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        CALayer *layer = [CALayer layer];
        self.wantsLayer = YES;
        self.layer = layer;

        // Create chart rect with padding
        CGRect chartRect = smallerCenteredRect(frameRect, kPaddingSize);

        // Create track layer (background circle)
        track = makeTemplate(chartRect);
        track.fillColor = NSColor.clearColor.CGColor;
        track.strokeColor = [[NSColor colorWithRed:0.11 green:0.11 blue:0.11 alpha:0.8] CGColor];
        track.lineWidth = kTrackLineWidth;
        [layer addSublayer:track];

        // Create outline layer (colored progress indicator)
        outline = makeTemplate(chartRect);
        outline.fillColor = NSColor.clearColor.CGColor;
        outline.strokeColor = NSColor.controlAccentColor.CGColor;
        outline.lineWidth = kTrackLineWidth;
        outline.lineCap = @"round";
        outline.strokeEnd = 0;
        [layer addSublayer:outline];

        // Create bar layer (inner progress indicator)
        bar = makeTemplate(chartRect);
        bar.fillColor = NSColor.clearColor.CGColor;
        bar.strokeColor = [[NSColor colorWithRed:0.04 green:0.04 blue:0.04 alpha:1] CGColor];
        bar.lineWidth = kBarLineWidth;
        bar.lineCap = @"round";
        bar.strokeEnd = 0;
        [layer addSublayer:bar];
        
        // Pre-create the animation that will be reused
        strokeAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        strokeAnimation.fromValue = @0.0f;
        strokeAnimation.toValue = @1.0f;
        strokeAnimation.fillMode = kCAFillModeForwards;
        strokeAnimation.removedOnCompletion = NO;
    }
    return self;
}

- (BOOL)wantsUpdateLayer {
    return YES;
}

- (void)updateLayer {
    // Remove any existing animations
    [outline removeAllAnimations];
    [bar removeAllAnimations];

    // Update the animation duration based on current progress duration
    strokeAnimation.duration = self.progressDuration;
    
    // Apply the animation to both layers
    [outline addAnimation:strokeAnimation forKey:@"strokeAnim"];
    [bar addAnimation:strokeAnimation forKey:@"strokeAnim"];
}

- (void)reset {
    [bar removeAllAnimations];
    bar.strokeEnd = 0;
}

#pragma mark - Helpers

static CGFloat deg2Rad(const CGFloat deg) {
    return deg * M_PI / 180;
}

static CGRect smallerCenteredRect(const CGRect rect, const CGFloat pixels) {
    return CGRectMake(CGRectGetMinX(rect) + pixels,
                      CGRectGetMinY(rect) + pixels,
                      CGRectGetWidth(rect) - (pixels * 2),
                      CGRectGetHeight(rect) - (pixels * 2));
}

static CAShapeLayer * makeTemplate(const CGRect frame) {
    CAShapeLayer *layer = [CAShapeLayer layer];
    layer.bounds = frame;
    layer.position = CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));

    {
        CGPathRef circle = CGPathCreateWithEllipseInRect(frame, NULL);
        layer.path = circle;
        CFRelease(circle);
    }

    // These transformations make the stroke start at 12 o'clock and move
    // clockwise.
    CATransform3D flip = CATransform3DIdentity;
    flip.m22 = -1;
    CGAffineTransform rotate2d = CGAffineTransformMakeRotation(deg2Rad(90));
    CATransform3D rotate = CATransform3DMakeAffineTransform(rotate2d);
    layer.transform = CATransform3DConcat(flip, rotate);

    return layer;
}

@end
