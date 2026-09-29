#pragma once
#include <stdbool.h>
#include <stdint.h>

// All undocumented APIs and constants stay behind this boundary.
// Probe builds and reads back events, but NEVER posts an event.
bool MGBackendProbe(char *message, unsigned long capacity);
// phase: began=1, changed=2, ended=4, cancelled=8. Horizontal only.
bool MGPostHorizontal(double progress, double velocity, uint32_t phase);
// Phase 1/2 vertical DockSwipe POC. Probe never posts. Signed progress selects
// the two vertical Dock actions; horizontal payload stays separate.
bool MGVerticalProbe(char *message, unsigned long capacity);
bool MGPostVertical(double progress, double velocity, uint32_t phase);
