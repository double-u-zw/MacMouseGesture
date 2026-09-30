# SystemGestureBridge functional contract — Build 15

Specification recorded before replacement on 2026-09-30. Baseline: Build 14, commit `856891d`. Inputs used: public C header; MacOS27GestureBackend call sites; existing GestureMachine/MissionControl tests and recorded Build 14 behavior; previously recorded ABI/symbol/protocol facts. No MMF or MIT implementation source is an implementation template for this change. This is a specification-driven replacement, not a claim of a legally certified clean-room process: the author of this audit has previously seen those sources.

## Inputs and public ABI

Keep `MGBackendProbe(char *, unsigned long)`, `MGVerticalProbe(char *, unsigned long)`, `MGPostHorizontal(double progress, double velocity, uint32_t phase)`, `MGPostVertical(double progress, double velocity, uint32_t phase)` unchanged, all returning `bool`.

The selected entry point supplies the axis. The arguments are **absolute signed progress**, signed progress-per-second velocity, and one phase (`1` begin, `2` change, `4` end, `8` cancel). The Bridge receives no mouse delta, button, action name, sequence identifier, threshold, sensitivity or reversal preference. It must not invent any of these inputs or rescale/invert/clamp the caller's values. NaN/infinity in either numeric input and any other phase are rejected without posting.

The Swift state machines own dead zone, axis lock, begin/change/terminal selection, sign, stationary velocity expiry and exactly-once finish. Horizontal progress can reverse sign. Positive vertical progress is the recorded Mission Control behavior; negative progress is App Exposé. Vertical action locking remains outside the Bridge. The Bridge is stateless between requests except for one-time API loading: it must allow repeated sequences and must not synthesize extra begin/end events.

## Output contract and evidence sources

A valid posting call builds one CGEvent containing the required native HID payload and posts it once to the session event tap. `true` means construction and the posting call completed, not that Dock acknowledged delivery. Probes construct/read/release events without posting.

The previously recorded Apple ABI/protocol facts are the minimal protocol vocabulary, not a copied source program:

| Observable property | Required value / source |
|---|---|
| Native class / attachment | Runtime `HIDEvent`; SkyLight `SLEventSetIOHIDEvent`; readback via `SLEventCopyIOHIDEvent` |
| Root event kind | DockSwipe numeric type 23, recorded Apple IOHIDEventTypes definition |
| Root phase | options stores caller phase shifted 24 bits; existing phase tests and recorded protocol |
| Axis | field `(23 << 16) | 1`: horizontal=1, vertical=2 |
| Progress | field `(23 << 16) | 2`: caller's double, including its sign |
| Flavor | field `(23 << 16) | 5`: DockPrimary=3, recorded system protocol |
| Terminal velocity | Only end/cancel includes one type-9 Velocity child. Fields `(9 << 16) | {0,1,2}` form a vector: horizontal=(v,0,0), vertical=(0,v,0). Caller chooses zero for forced cancellation; the Bridge does not overwrite a supplied cancellation velocity |
| CG wrapper | event type 30; session-tap destination; existing source-user-data marker `0x4D47504F43` retained as an identification fact |
| Time | Each native object receives current mach time; CG timestamp uses current monotonic uptime nanoseconds. No input timestamp, old event, wall clock, or cross-process legacy field conversion |

Constant provenance is recorded in `system-gesture-provenance.md`; these runtime interface facts do not establish Apple permission to use private APIs. Do not add legacy gesture/momentum fields, pinch actions, device inversion, screen-size scaling, or fixed CG memory offsets.

## Lifecycle and failure semantics

Each call is one independent transaction: validate input and availability; describe the requested axis/phase/progress/vector; allocate the complete native objects and wrapper; apply required values; attach; return a completed owned event or fail. No partly allocated event may reach the posting boundary. Every CG/CF ownership transfer must balance on success, failure and exception; ARC owns Objective-C objects.

Begin/change have no velocity child. End/cancel have the one specified velocity vector. Pause means the caller sends no new frame; the Bridge has no clock/timer that posts autonomously. Direction reversal changes the next caller value; it does not reset Bridge state. Repeated and interleaved horizontal/vertical requests cannot inherit fields from the previous request.

Missing class, symbol, required selector, allocation or exception fails closed. Return false with no post on construction failure. A native posting call itself has no delivery acknowledgement. Startup probes validate both signs, phases and required field readback; tests additionally inspect velocity children and transactional allocation failure.

## Replacement design derived from these requirements

Use an immutable per-call **event description**: axis determines one motion value and one velocity-vector component; terminal phase determines whether there are one or two native objects. Express field assignments as typed records. A bounded materializer allocates the complete set first and applies these records uniformly, independent of horizontal/vertical control flow. Only after successful construction does the public posting boundary receive the event. This separation is chosen for validation, failure atomicity and testability; it is not a renamed or helper-extracted version of either old constructor.

The test executable interposes CGEventPost only at compile time to inspect real native payloads without sending events to Dock. CG wrapper and native-object allocation failures are injected only in the test build; these hooks are absent from shipping code. No production C entry points are added.

## Acceptance

Before replacement, run positive contract tests through Build 14's existing C API with posting intercepted. Freeze observable input/output properties only, not serialized bytes or construction order. After replacement, run the same tests plus native-allocation failure tests, the full existing 67-check suite, and all 6 package fault checks. Build an isolated Build 15 candidate, preserving marketing version 0.2.0-beta.1, Build 14 and the stable app.

Real two-button four-direction behavior and physical mouse disconnect/reconnect without restarting remain user acceptance. Synthetic tests cannot label those PASS.
