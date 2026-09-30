// Written for MacMouseGesture from docs/system-gesture-bridge-spec.md and the
// project's C-API behavior contracts. No Mac Mouse Fix source was copied into
// this replacement. Earlier research/history is acknowledged in the notices.
// This implementation still relies on undocumented/private macOS interfaces.
#import "SystemGestureBridge.h"
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach/mach_time.h>
#include <math.h>

// Minimal runtime ABI used by construction and non-posting readback only.
@interface MGNativeHID : NSObject
- (instancetype)initWithType:(uint32_t)type timestamp:(uint64_t)time senderID:(uint64_t)sender;
- (void)setOptions:(uint32_t)options;
- (uint32_t)options;
- (uint32_t)type;
- (void)setIntegerValue:(NSInteger)value forField:(uint32_t)field;
- (NSInteger)integerValueForField:(uint32_t)field;
- (void)setDoubleValue:(double)value forField:(uint32_t)field;
- (double)doubleValueForField:(uint32_t)field;
- (void)appendEvent:(id)child;
@end

static Class nativeEventClass;
static void (*attachPayload)(CGEventRef, CFTypeRef);
static CFTypeRef (*copyPayload)(CGEventRef);
static char availabilityReason[192];

static bool MGResolveRuntime(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (@available(macOS 27.0, *)) {
            // Symbols and class objects remain in use for the process lifetime.
            dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW | RTLD_LOCAL);
            dlopen("/System/Library/PrivateFrameworks/HID.framework/HID", RTLD_NOW | RTLD_LOCAL);
            void *library = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW | RTLD_LOCAL);
            if (library) {
                attachPayload = dlsym(library, "SLEventSetIOHIDEvent");
                copyPayload = dlsym(library, "SLEventCopyIOHIDEvent");
            }
            nativeEventClass = NSClassFromString(@"HIDEvent");
            NSArray<NSString *> *methods = @[@"initWithType:timestamp:senderID:", @"setOptions:",
                @"options", @"type", @"setIntegerValue:forField:", @"integerValueForField:",
                @"setDoubleValue:forField:", @"doubleValueForField:", @"appendEvent:"];
            for (NSString *method in methods) {
                if (!nativeEventClass || !class_getInstanceMethod(nativeEventClass, NSSelectorFromString(method))) {
                    snprintf(availabilityReason, sizeof availabilityReason, "Unavailable HID method: %s", method.UTF8String);
                    return;
                }
            }
            if (!attachPayload || !copyPayload)
                snprintf(availabilityReason, sizeof availabilityReason, "Unavailable SkyLight HID attachment/readback");
        } else {
            snprintf(availabilityReason, sizeof availabilityReason, "Requires macOS 27");
        }
    });
    return nativeEventClass && attachPayload && copyPayload && !availabilityReason[0];
}

typedef enum { MGHorizontal = 1, MGVertical = 2 } MGAxis;
typedef struct {
    uint32_t identifier;
    bool integer;
    double value;
} MGFieldValue;
typedef struct {
    uint32_t type, options;
    MGFieldValue fields[3];
} MGNodeDescription;
typedef struct {
    unsigned nodeCount;
    MGNodeDescription nodes[2]; // root, optional terminal vector
} MGEventDescription;

// Pure mapping from the public request to the independently recorded contract.
// Construction order and native object ownership are not part of this mapping.
static bool MGDescribe(MGAxis axis, double progress, double velocity, uint32_t phase,
                       MGEventDescription *description) {
    if (!isfinite(progress) || !isfinite(velocity) ||
        !(phase == 1 || phase == 2 || phase == 4 || phase == 8)) return false;
    *description = (MGEventDescription){
        .nodeCount = (phase == 4 || phase == 8) ? 2 : 1,
        .nodes = {
            { .type = 23, .options = phase << 24, .fields = {
                { (23u << 16) | 1, true, axis },
                { (23u << 16) | 2, false, progress },
                { (23u << 16) | 5, true, 3 }
            } },
            { .type = 9, .options = 0, .fields = {
                { (9u << 16) | 0, false, axis == MGHorizontal ? velocity : 0 },
                { (9u << 16) | 1, false, axis == MGVertical ? velocity : 0 },
                { (9u << 16) | 2, false, 0 }
            } }
        }
    };
    return true;
}

#ifdef MG_BRIDGE_CONTRACT_TESTS
// Linked only by the non-posting test executable; absent from shipping builds.
extern bool MGContractNativeAllocationAllowed(void);
#endif

@interface SystemGestureEventBuilder : NSObject
+ (CGEventRef)copyEventForDescription:(const MGEventDescription *)description CF_RETURNS_RETAINED;
@end
@implementation SystemGestureEventBuilder
+ (CGEventRef)copyEventForDescription:(const MGEventDescription *)description {
    CGEventRef output = CGEventCreate(NULL);
    if (!output) return NULL;
    bool complete = false;
    @try {
        MGNativeHID *objects[2] = {nil, nil};
        // First acquire the entire bounded object set. Failure never publishes
        // a partially populated payload, including a missing terminal vector.
        for (unsigned i = 0; i < description->nodeCount; ++i) {
#ifdef MG_BRIDGE_CONTRACT_TESTS
            if (!MGContractNativeAllocationAllowed()) return NULL;
#endif
            objects[i] = [[nativeEventClass alloc] initWithType:description->nodes[i].type
                timestamp:mach_absolute_time() senderID:0];
            if (!objects[i]) return NULL;
        }
        for (unsigned i = 0; i < description->nodeCount; ++i) {
            const MGNodeDescription *node = &description->nodes[i];
            [objects[i] setOptions:node->options];
            for (unsigned fieldIndex = 0; fieldIndex < 3; ++fieldIndex) {
                MGFieldValue field = node->fields[fieldIndex];
                if (field.integer) [objects[i] setIntegerValue:(NSInteger)field.value forField:field.identifier];
                else [objects[i] setDoubleValue:field.value forField:field.identifier];
            }
        }
        if (description->nodeCount == 2) [objects[0] appendEvent:objects[1]];
        attachPayload(output, (__bridge CFTypeRef)objects[0]);
        CGEventSetType(output, (CGEventType)30);
        CGEventSetIntegerValueField(output, kCGEventSourceUserData, 0x4D47504F43);
        CGEventSetTimestamp(output, clock_gettime_nsec_np(CLOCK_UPTIME_RAW));
        complete = true;
        return output;
    } @finally {
        if (!complete) CFRelease(output);
    }
}
@end

static bool MGSend(MGAxis axis, double progress, double velocity, uint32_t phase) {
    @autoreleasepool {
        MGEventDescription description;
        if (!MGDescribe(axis, progress, velocity, phase, &description)) return false;
        @try {
            if (!MGResolveRuntime()) return false;
            CGEventRef output = [SystemGestureEventBuilder copyEventForDescription:&description];
            if (!output) return false;
            @try { CGEventPost(kCGSessionEventTap, output); }
            @finally { CFRelease(output); }
            return true; // CGEventPost provides no delivery acknowledgement.
        } @catch (NSException *exception) { return false; }
    }
}

static bool MGInspect(const MGEventDescription *description) {
    CGEventRef output = [SystemGestureEventBuilder copyEventForDescription:description];
    if (!output) return false;
    CFTypeRef owned = NULL;
    @try {
        owned = copyPayload(output);
        if (!owned) return false;
        MGNativeHID *root = (__bridge MGNativeHID *)owned;
        const MGNodeDescription *expected = &description->nodes[0];
        if ([root type] != expected->type || [root options] != expected->options) return false;
        for (unsigned i = 0; i < 3; ++i) {
            MGFieldValue field = expected->fields[i];
            double actual = field.integer ? [root integerValueForField:field.identifier] :
                                           [root doubleValueForField:field.identifier];
            if (!isfinite(actual) || fabs(actual - field.value) >= 0.0001) return false;
        }
        return true;
    } @finally {
        if (owned) CFRelease(owned);
        CFRelease(output);
    }
}

static bool MGProbe(MGAxis axis, char *message, unsigned long capacity) {
    @autoreleasepool {
        const char *result = "Native HID contract readback PASS; Dock response UNVERIFIED";
        bool passed = false;
        @try {
            if (!MGResolveRuntime()) result = availabilityReason;
            else {
                passed = true;
                const uint32_t phases[] = {1, 2, 4, 8};
                for (unsigned i = 0; i < 4 && passed; ++i) {
                    for (unsigned sign = 0; sign < 2 && passed; ++sign) {
                        MGEventDescription description;
                        MGDescribe(axis, sign ? -0.25 : 0.25, sign ? -0.5 : 0.5, phases[i], &description);
                        passed = MGInspect(&description);
                    }
                }
                if (!passed) result = "Native HID allocation/field readback failed";
            }
        } @catch (NSException *exception) { result = "Native HID probe exception"; passed = false; }
        if (message && capacity) snprintf(message, capacity, "%s", result);
        return passed;
    }
}

bool MGBackendProbe(char *message, unsigned long capacity) { return MGProbe(MGHorizontal, message, capacity); }
bool MGVerticalProbe(char *message, unsigned long capacity) { return MGProbe(MGVertical, message, capacity); }
bool MGPostHorizontal(double progress, double velocity, uint32_t phase) { return MGSend(MGHorizontal, progress, velocity, phase); }
bool MGPostVertical(double progress, double velocity, uint32_t phase) { return MGSend(MGVertical, progress, velocity, phase); }
