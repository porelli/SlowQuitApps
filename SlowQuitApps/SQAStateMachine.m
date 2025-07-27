#import "SQAStateMachine.h"
#import "SQAPreferences.h"
@import Carbon.HIToolbox;

// Constants for timer configuration
static const NSUInteger kTimerIntervalMs = 15;

typedef NS_ENUM(NSInteger, SQAMachineState) {
    SQAStateMachineInitialized,
    SQAStateMachineHolding,
    SQAStateMachineCompleted,
    SQAStateMachineCancelled
};

@interface SQAStateMachine() {
@private
    CGEventSourceRef eventSource;
    SQAMachineState currentState;
    CFTimeInterval start;
    CFTimeInterval lastUpdate;
    dispatch_source_t timer;
}

// Private property for progress calculation
@property (nonatomic, readonly) CGFloat progress;
@end

@implementation SQAStateMachine
@synthesize onStart;
@synthesize onHolding;
@synthesize onCancelled;
@synthesize onCompletion;

- (void)dealloc {
    // Clean up timer if it exists
    if (timer) {
        dispatch_source_cancel(timer);
        // Set to nil to avoid potential use-after-free issues
        timer = nil;
    }
}

- (instancetype)initWithEventSource:(CGEventSourceRef)eventSource {
    self = [super init];
    if (!self) return self;

    // Store the event source
    self->eventSource = eventSource;
    
    // Initialize state
    currentState = SQAStateMachineInitialized;

    // Create timer on high priority queue
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    if (!timer) {
        NSLog(@"Failed to create timer for state machine");
        return nil;
    }

    // Configure timer interval
    const NSUInteger interval = kTimerIntervalMs * NSEC_PER_MSEC;
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 0), interval, 0);
    dispatch_source_set_event_handler(timer, ^{ [self checkRemap]; });

    return self;
}

- (void)holding {
    switch (currentState) {
        case SQAStateMachineInitialized:
            start = lastUpdate = CACurrentMediaTime();
            dispatch_resume(timer);
            currentState = SQAStateMachineHolding;
            if (onStart) {
                onStart();
            }
            break;
        case SQAStateMachineHolding:
            lastUpdate = CACurrentMediaTime();
            if (onHolding) {
                onHolding();
            }
            if (self.progress < 1) {
                return;
            }
            dispatch_source_cancel(timer);
            currentState = SQAStateMachineCompleted;
            if (onCompletion) {
                onCompletion();
            }
            break;
        default:
            break;
    }
}

- (void)cancelled {
    if (currentState == SQAStateMachineCancelled) {
        return;
    }
    dispatch_source_cancel(timer);
    currentState = SQAStateMachineCancelled;
    if (onCancelled) {
        onCancelled();
    }
}

- (void)checkRemap {
    BOOL isRemapPressed = CGEventSourceKeyState(CGEventSourceGetSourceStateID(eventSource), kVK_Command);
    if (isRemapPressed) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf cancelled];
    });
}

- (CGFloat)completionDurationInMilliseconds {
    return (CGFloat)[SQAPreferences delay];
}

- (CGFloat)completionDurationInSeconds {
    return self.completionDurationInMilliseconds / 1000.0;
}

- (CGFloat)progress {
    CFTimeInterval elapsed = (lastUpdate - start) * 1000;
    return elapsed / self.completionDurationInMilliseconds;
}

@end
