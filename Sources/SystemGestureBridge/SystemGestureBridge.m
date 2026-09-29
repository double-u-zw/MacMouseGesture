#import "SystemGestureBridge.h"
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach/mach_time.h>
#include <math.h>

// Minimal ABI declarations, independently expressed from Apple's HIDEvent interface.
// Research provenance and upstream license: docs/research.md, THIRD_PARTY_NOTICES.md.
@interface MGHIDContract : NSObject
- (instancetype)initWithType:(uint32_t)type timestamp:(uint64_t)timestamp senderID:(uint64_t)sender;
- (void)setOptions:(uint32_t)options;
- (uint32_t)options;
- (uint32_t)type;
- (void)setIntegerValue:(NSInteger)value forField:(uint32_t)field;
- (NSInteger)integerValueForField:(uint32_t)field;
- (void)setDoubleValue:(double)value forField:(uint32_t)field;
- (double)doubleValueForField:(uint32_t)field;
- (void)appendEvent:(id)event;
@end

typedef void (*AttachFunction)(CGEventRef, const void *);
typedef CFTypeRef (*CopyFunction)(CGEventRef);
static Class eventClass;
static AttachFunction attachHID;
static CopyFunction copyHID;
static bool ready;
static char failure[256];
// Apple IOHIDEventTypes/FieldDefs: DockSwipe=23, Velocity=9, field base = type << 16.
enum { Dock = 23, Velocity = 9, Motion = (23 << 16) | 1,
       Progress = (23 << 16) | 2, Flavor = (23 << 16) | 5 };

static void loadAPI(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (@available(macOS 27.0, *)) {} else {
            snprintf(failure, sizeof failure, "Requires macOS 27; legacy injection is not implemented in this POC"); return;
        }
        // Keep loaded for process lifetime: function pointers and Objective-C class use them.
        dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW | RTLD_LOCAL);
        dlopen("/System/Library/PrivateFrameworks/HID.framework/HID", RTLD_NOW | RTLD_LOCAL);
        void *sky = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW | RTLD_LOCAL);
        eventClass = NSClassFromString(@"HIDEvent");
        if (sky) {
            attachHID = (AttachFunction)dlsym(sky, "SLEventSetIOHIDEvent");
            copyHID = (CopyFunction)dlsym(sky, "SLEventCopyIOHIDEvent");
        }
        if (!eventClass || !attachHID || !copyHID) {
            snprintf(failure, sizeof failure, "Missing HIDEvent or SkyLight bridge symbols"); return;
        }
        const char *selectors[] = {"initWithType:timestamp:senderID:", "setOptions:", "options", "type",
            "setIntegerValue:forField:", "integerValueForField:", "setDoubleValue:forField:",
            "doubleValueForField:", "appendEvent:"};
        for (unsigned i = 0; i < sizeof selectors / sizeof *selectors; ++i) {
            if (!class_getInstanceMethod(eventClass, sel_registerName(selectors[i]))) {
                snprintf(failure, sizeof failure, "Missing HID selector %s", selectors[i]); return;
            }
        }
        ready = true;
    });
}

static CGEventRef createEvent(double progress, double velocity, uint32_t phase) {
    MGHIDContract *payload = [[eventClass alloc] initWithType:Dock timestamp:mach_absolute_time() senderID:0];
    if (!payload) return NULL;
    [payload setOptions:phase << 24];
    [payload setIntegerValue:1 forField:Motion]; // HorizontalX
    [payload setIntegerValue:3 forField:Flavor]; // DockPrimary
    [payload setDoubleValue:progress forField:Progress];
    if (phase == 4 || phase == 8) {
        MGHIDContract *speed = [[eventClass alloc] initWithType:Velocity timestamp:mach_absolute_time() senderID:0];
        if (!speed) return NULL;
        [speed setDoubleValue:velocity forField:(Velocity << 16)];
        [speed setDoubleValue:0 forField:(Velocity << 16) | 1];
        [speed setDoubleValue:0 forField:(Velocity << 16) | 2];
        [payload appendEvent:speed];
    }
    CGEventRef event = CGEventCreate(NULL);
    if (!event) return NULL;
    CGEventSetType(event, (CGEventType)30);
    CGEventSetTimestamp(event, clock_gettime_nsec_np(CLOCK_UPTIME_RAW));
    CGEventSetIntegerValueField(event, kCGEventSourceUserData, 0x4D47504F43);
    attachHID(event, (__bridge const void *)payload);
    return event;
}

bool MGBackendProbe(char *message, unsigned long capacity) {
    @autoreleasepool {
        loadAPI();
        if (!ready) { snprintf(message, capacity, "%s", failure); return false; }
        @try {
            uint32_t phases[] = {1, 2, 4, 8};
            for (unsigned i = 0; i < 4; ++i) {
                CGEventRef event = createEvent(0.25, 0.5, phases[i]);
                if (!event) { snprintf(message, capacity, "Event allocation failed"); return false; }
                CFTypeRef ref = copyHID(event);
                MGHIDContract *roundtrip = (__bridge MGHIDContract *)ref;
                bool valid = roundtrip && [roundtrip type] == Dock &&
                    [roundtrip options] == (phases[i] << 24) &&
                    [roundtrip integerValueForField:Motion] == 1 &&
                    [roundtrip integerValueForField:Flavor] == 3 &&
                    fabs([roundtrip doubleValueForField:Progress] - 0.25) < 0.0001;
                if (ref) CFRelease(ref);
                CFRelease(event);
                if (!valid) { snprintf(message, capacity, "HID attachment round-trip failed"); return false; }
            }
            snprintf(message, capacity, "macOS 27 HID: symbols + 4-phase attachment round-trip PASS; Dock response UNVERIFIED");
            return true;
        } @catch (NSException *exception) {
            snprintf(message, capacity, "HID probe exception: %s", exception.name.UTF8String); return false;
        }
    }
}

bool MGPostHorizontal(double progress, double velocity, uint32_t phase) {
    if (!isfinite(progress) || !isfinite(velocity) ||
        !(phase == 1 || phase == 2 || phase == 4 || phase == 8)) return false;
    @autoreleasepool {
        loadAPI();
        if (!ready) return false;
        @try {
            CGEventRef event = createEvent(progress, velocity, phase);
            if (!event) return false;
            CGEventPost(kCGSessionEventTap, event); // Posting has no delivery acknowledgment.
            CFRelease(event);
            return true;
        } @catch (NSException *exception) { return false; }
    }
}

// Kept separate from createEvent/MGPostHorizontal so the confirmed Build 7
// Spaces payload above remains byte-for-byte the same at the field level.
static CGEventRef createVerticalEvent(double progress, double velocity, uint32_t phase) {
    MGHIDContract *payload = [[eventClass alloc] initWithType:Dock timestamp:mach_absolute_time() senderID:0];
    if (!payload) return NULL;
    [payload setOptions:phase << 24];
    [payload setIntegerValue:2 forField:Motion]; // VerticalY
    [payload setIntegerValue:3 forField:Flavor]; // DockPrimary
    [payload setDoubleValue:progress forField:Progress];
    if (phase == 4 || phase == 8) {
        MGHIDContract *speed = [[eventClass alloc] initWithType:Velocity timestamp:mach_absolute_time() senderID:0];
        if (!speed) return NULL;
        [speed setDoubleValue:0 forField:(Velocity << 16)];
        [speed setDoubleValue:velocity forField:(Velocity << 16) | 1];
        [speed setDoubleValue:0 forField:(Velocity << 16) | 2];
        [payload appendEvent:speed];
    }
    CGEventRef event = CGEventCreate(NULL);
    if (!event) return NULL;
    CGEventSetType(event, (CGEventType)30);
    CGEventSetTimestamp(event, clock_gettime_nsec_np(CLOCK_UPTIME_RAW));
    CGEventSetIntegerValueField(event, kCGEventSourceUserData, 0x4D47504F43);
    attachHID(event, (__bridge const void *)payload);
    return event;
}

bool MGVerticalProbe(char *message, unsigned long capacity) {
    @autoreleasepool {
        loadAPI();
        if (!ready) { snprintf(message, capacity, "%s", failure); return false; }
        @try {
            uint32_t phases[] = {1, 2, 4, 8};
            for (unsigned i = 0; i < 4; ++i) {
                // Exercise both directions without sending any event to Dock.
                double progress = i & 1 ? -0.25 : 0.25;
                CGEventRef event = createVerticalEvent(progress, 0.5, phases[i]);
                if (!event) { snprintf(message, capacity, "Vertical event allocation failed"); return false; }
                CFTypeRef ref = copyHID(event);
                MGHIDContract *roundtrip = (__bridge MGHIDContract *)ref;
                bool valid = roundtrip && [roundtrip type] == Dock &&
                    [roundtrip options] == (phases[i] << 24) &&
                    [roundtrip integerValueForField:Motion] == 2 &&
                    [roundtrip integerValueForField:Flavor] == 3 &&
                    fabs([roundtrip doubleValueForField:Progress] - progress) < 0.0001;
                if (ref) CFRelease(ref);
                CFRelease(event);
                if (!valid) { snprintf(message, capacity, "Vertical HID attachment round-trip failed"); return false; }
            }
            snprintf(message, capacity, "Vertical backend: interactive HID; 4-phase attachment round-trip PASS; Dock response UNVERIFIED");
            return true;
        } @catch (NSException *exception) {
            snprintf(message, capacity, "Vertical HID probe exception: %s", exception.name.UTF8String); return false;
        }
    }
}

bool MGPostVertical(double progress, double velocity, uint32_t phase) {
    if (!isfinite(progress) || !isfinite(velocity) ||
        !(phase == 1 || phase == 2 || phase == 4 || phase == 8)) return false;
    @autoreleasepool {
        loadAPI();
        if (!ready) return false;
        @try {
            CGEventRef event = createVerticalEvent(progress, velocity, phase);
            if (!event) return false;
            CGEventPost(kCGSessionEventTap, event); // No Dock delivery acknowledgment.
            CFRelease(event);
            return true;
        } @catch (NSException *exception) { return false; }
    }
}
