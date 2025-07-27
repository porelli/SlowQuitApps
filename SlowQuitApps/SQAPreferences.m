#import "SQAPreferences.h"

// Default values
static NSString * const kDelayKey = @"delay";
static NSString * const kWhitelistKey = @"whitelist";
static NSString * const kInvertListKey = @"invertList";
static NSString * const kDisplayOverlayKey = @"displayOverlay";
static NSString * const kDisableAutostartKey = @"disableAutostart";

// Class extension for private methods
@interface SQAPreferences ()

// Private method to access defaults
+ (NSUserDefaults *)defaults;

// Method to reset cached values
+ (void)resetCachedPreferences;

@end

@implementation SQAPreferences

#pragma mark - Private Methods

+ (NSUserDefaults *)defaults {
    static BOOL defaultsRegistered;
    if (!defaultsRegistered) {
        NSDictionary *defaults = @{
            kDelayKey: @1000,
            kWhitelistKey: @[],
            kInvertListKey: @NO,
            kDisplayOverlayKey: @YES,
            kDisableAutostartKey: @NO
        };
        [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
        defaultsRegistered = YES;
    }
    return [NSUserDefaults standardUserDefaults];
}

+ (void)resetCachedPreferences {
    // Reset all static variables to force reload from defaults
    // This method should be called when preferences might have changed
    // outside of this class's control
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Only implement this once to avoid potential threading issues
        [[NSNotificationCenter defaultCenter] addObserverForName:NSUserDefaultsDidChangeNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
            // Force reload of all preferences on next access
            // Implementation note: we're setting these to their initial values
            // which will trigger a reload on next access
            _displayOverlayValue = NO;
            _delayValue = 0;
            _whitelistValue = nil;
            _invertListValue = NO;
            _disableAutostartValue = NO;
        }];
    });
}

#pragma mark - Public Methods

// Static variables to cache preference values
static BOOL _displayOverlayValue = NO;
static BOOL _displayOverlayInitialized = NO;

+ (BOOL)displayOverlay {
    if (!_displayOverlayInitialized) {
        _displayOverlayValue = [[self defaults] boolForKey:kDisplayOverlayKey];
        _displayOverlayInitialized = YES;
    }
    return _displayOverlayValue;
}

// Static variables to cache delay value
static NSInteger _delayValue = 0;
static BOOL _delayInitialized = NO;

+ (NSInteger)delay {
    if (!_delayInitialized) {
        _delayValue = [[self defaults] integerForKey:kDelayKey];
        if (_delayValue <= 0) {
            _delayValue = 1000;
        }
        _delayInitialized = YES;
    }
    return _delayValue;
}

// Static variables to cache whitelist value
static NSArray<NSString *> *_whitelistValue = nil;
static BOOL _whitelistInitialized = NO;

+ (NSArray<NSString *> *)whitelist {
    if (!_whitelistInitialized) {
        _whitelistValue = [[self defaults] stringArrayForKey:kWhitelistKey];
        _whitelistInitialized = YES;
    }
    return _whitelistValue;
}

// Static variables to cache invertList value
static BOOL _invertListValue = NO;
static BOOL _invertListInitialized = NO;

+ (BOOL)invertList {
    if (!_invertListInitialized) {
        _invertListValue = [[self defaults] boolForKey:kInvertListKey];
        _invertListInitialized = YES;
    }
    return _invertListValue;
}

// Static variables to cache disableAutostart value
static BOOL _disableAutostartValue = NO;
static BOOL _disableAutostartInitialized = NO;

+ (BOOL)disableAutostart {
    if (!_disableAutostartInitialized) {
        _disableAutostartValue = [[self defaults] boolForKey:kDisableAutostartKey];
        _disableAutostartInitialized = YES;
    }
    return _disableAutostartValue;
}

@end
