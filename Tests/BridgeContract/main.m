// MacMouseGesture observable C-API contracts. Never posts a real system event.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <dlfcn.h>
#import <math.h>
#import "SystemGestureBridge.h"

// Read-only runtime inspection ABI, confined to this test executable.
@interface MGObservedHID : NSObject
- (uint32_t)type;
- (uint32_t)options;
- (NSInteger)integerValueForField:(uint32_t)field;
- (double)doubleValueForField:(uint32_t)field;
- (NSArray *)children;
@end
static CGEventRef captured;
static unsigned posts;
static bool failWrapper;
static unsigned failNativeAt, nativeAllocation;
static unsigned checks, failures;

// The Bridge object is compiled with CGEventPost/CGEventCreate renamed to these
// functions. This translation unit is not; only allocation reaches real CG.
void MGContractPost(CGEventTapLocation location, CGEventRef event) {
    if (captured) CFRelease(captured);
    captured = event ? (CGEventRef)CFRetain(event) : NULL;
    posts++;
    if (location != kCGSessionEventTap) failures++;
}
CGEventRef MGContractCreate(CGEventSourceRef source) {
    if (failWrapper) return NULL;
    return CGEventCreate(source);
}
bool MGContractNativeAllocationAllowed(void) {
    return ++nativeAllocation != failNativeAt;
}
static void check(bool ok, const char *label) {
    checks++;
    printf("%s bridge %s\n", ok ? "PASS" : "FAIL", label);
    if (!ok) failures++;
}
static void reset(void) {
    if (captured) CFRelease(captured);
    captured = NULL; posts = 0;
    failWrapper = false; failNativeAt = 0; nativeAllocation = 0;
}
static bool closeTo(double a, double b) { if (!isfinite(a) || fabs(a - b) >= 0.0001) {
        fprintf(stderr, "native scalar mismatch actual=%.12f expected=%.12f\n", a, b); return false;
    }
    return true; }
static bool inspect(bool vertical, double progress, double velocity, uint32_t phase) {
    if (!captured || CGEventGetType(captured) != 30 || CGEventGetTimestamp(captured) == 0 ||
        CGEventGetIntegerValueField(captured, kCGEventSourceUserData) != 0x4D47504F43) return false;
    static CFTypeRef (*copyPayload)(CGEventRef);
    if (!copyPayload) {
        void *library = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW | RTLD_LOCAL);
        if (library) copyPayload = dlsym(library, "SLEventCopyIOHIDEvent");
    }
    if (!copyPayload) return false;
    CFTypeRef owned = copyPayload(captured);
    if (!owned) return false;
    MGObservedHID *payload = (__bridge MGObservedHID *)owned;
    bool ok = [payload type] == 23 && [payload options] == phase << 24 &&
        [payload integerValueForField:(23 << 16) | 1] == (vertical ? 2 : 1) &&
        [payload integerValueForField:(23 << 16) | 5] == 3 &&
        closeTo([payload doubleValueForField:(23 << 16) | 2], progress);
    NSArray *children = [payload children];
    bool terminal = phase == 4 || phase == 8;
    ok = ok && children.count == (terminal ? 1 : 0);
    if (terminal && children.count == 1) {
        MGObservedHID *vector = children.firstObject;
        ok = ok && [vector type] == 9 &&
            closeTo([vector doubleValueForField:9 << 16], vertical ? 0 : velocity) &&
            closeTo([vector doubleValueForField:(9 << 16) | 1], vertical ? velocity : 0) &&
            closeTo([vector doubleValueForField:(9 << 16) | 2], 0);
    }
    CFRelease(owned);
    return ok;
}
static bool frame(bool vertical, double p, double v, uint32_t phase) {
    unsigned before = posts;
    bool result = vertical ? MGPostVertical(p, v, phase) : MGPostHorizontal(p, v, phase);
    return result && posts == before + 1 && inspect(vertical, p, v, phase);
}
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        bool baseline = argc == 2 && strcmp(argv[1], "--baseline") == 0;
        char message[512];
        check(MGBackendProbe(message, sizeof message) && MGVerticalProbe(message, sizeof message) && posts == 0,
              "both probes construct/read without posting");
        for (unsigned i = 0; i < 4; i++) {
            uint32_t phase = (uint32_t[]){1, 2, 4, 8}[i];
            const char *label = (const char *[]){"horizontal begin", "horizontal update", "horizontal end", "horizontal cancel"}[i];
            check(frame(false, 0.375, -1.25, phase), label);
        }
        reset();
        check(frame(false, 0.2, 0, 1) && frame(false, -0.1, -0.4, 2) && frame(false, -0.6, -1.3, 4),
              "horizontal reversal preserves signed progress/velocity");
        unsigned before = posts;
        check(MGBackendProbe(message, sizeof message) && posts == before &&
              frame(false, -0.6, 0, 2) && frame(false, -0.6, 0, 8),
              "stationary input stays stationary; probe adds no pause event");
        for (unsigned verticalCase = 0; verticalCase < 2; verticalCase++) {
            double sign = verticalCase == 0 ? 1 : -1;
            bool ok = true;
            for (unsigned i = 0; i < 4; i++)
                ok = frame(true, sign * 0.35, sign * 1.1, (uint32_t[]){1,2,4,8}[i]) && ok;
            check(ok, verticalCase == 0 ? "Mission Control four phases" : "App Expose four phases");
        }
        bool ok = true;
        for (unsigned sequence = 0; sequence < 100; sequence++) {
            bool axis = (sequence & 1) != 0;
            ok = frame(axis, -0.25, 0, 1) && frame(axis, 0.1, 0, 2) && frame(axis, 0.1, 0, 8) && ok;
        }
        check(ok, "100 alternating-axis sequences have no field carry-over");
        reset();
        ok = true;
        double invalid[] = {NAN, INFINITY, -INFINITY};
        for (unsigned i = 0; i < 3; i++) {
            ok = !MGPostHorizontal(invalid[i], 0, 1) && !MGPostVertical(invalid[i], 0, 1) && ok;
            ok = !MGPostHorizontal(0, invalid[i], 4) && !MGPostVertical(0, invalid[i], 8) && ok;
        }
        for (unsigned i = 0; i < 5; i++) {
            uint32_t phase = (uint32_t[]){0, 3, 5, 16, UINT32_MAX}[i];
            ok = !MGPostHorizontal(0, 0, phase) && !MGPostVertical(0, 0, phase) && ok;
        }
        check(ok && posts == 0, "invalid numeric/phase inputs fail without posting");
        failWrapper = true;
        check(!MGPostHorizontal(0.2, 0, 1) && !MGPostVertical(-0.2, -1, 4) && posts == 0,
              "CG allocation failure never posts partial output");
        reset();
        if (!baseline) {
            for (unsigned allocation = 1; allocation <= 2; allocation++) {
                failNativeAt = allocation; nativeAllocation = 0;
                bool rejected = !MGPostHorizontal(0.4, 1.2, 4) && posts == 0;
                nativeAllocation = 0;
                rejected = !MGPostVertical(-0.4, -1.2, 8) && posts == 0 && rejected;
                check(rejected, allocation == 1 ? "root HID allocation failure is atomic" : "velocity HID allocation failure is atomic");
            }
            reset();
            check(frame(false, 0.5, 1.2, 4) && frame(true, -0.5, -1.2, 4),
                  "creation recovers after allocation failures");
        }
        reset();
        printf("%u bridge contract checks, %u failures. Posting intercepted; no real gestures.\n", checks, failures);
        return failures ? 1 : 0;
    }
}
