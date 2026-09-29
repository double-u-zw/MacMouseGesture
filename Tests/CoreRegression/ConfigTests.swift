import Foundation

final class ConfigTests {
    private func withDefaults(_ body: (UserDefaults, String) throws -> Void) rethrows {
        let name = "local.macmousegesture.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults, name)
    }
    func testFirstLaunchKeepsBuild4Defaults() {
        withDefaults { defaults, _ in
            let c = ConfigStore(defaults: defaults).load()
            expectTrue(c.enabled && c.horizontalEnabled && c.verticalEnabled && c.horizontalInvert && c.freezePointer)
            expectEqual(c.gestureButtons, [3, 4]); expectEqual(c.sensitivity, 600); expectEqual(c.deadZone, 8)
            expectEqual(c.gestureConfig.flickVelocity, 1.2)
            expectEqual(c.gestureConfig.completionProgress, 0.35)
        }
    }
    func testAllExposedSettingsRoundTripAndDisablePersists() {
        withDefaults { defaults, _ in
            var c = AppConfig(); c.enabled = false; c.horizontalEnabled = false; c.verticalEnabled = false
            c.gestureButtons = [2, 4, 8]; c.horizontalInvert = false
            c.sensitivity = 720; c.deadZone = 13; c.freezePointer = false
            ConfigStore(defaults: defaults).save(c)
            let restored = ConfigStore(defaults: defaults).load()
            expectEqual(restored, c); expectFalse(restored.shouldRun)
        }
    }
    func testCorruptionAndTypesDoNotReachEngine() {
        withDefaults { defaults, _ in
            let store = ConfigStore(defaults: defaults)
            defaults.set("not a dictionary", forKey: ConfigStore.key)
            expectEqual(store.load(), .defaults)
            defaults.set(["enabled": false, "sensitivity": Double.nan, "deadZone": -999,
                          "gestureButtons": [0, 4], "horizontalInvert": "false"] as [String: Any], forKey: ConfigStore.key)
            let c = store.load()
            expectFalse(c.enabled); expectEqual(c.sensitivity, 600); expectEqual(c.deadZone, 1)
            expectEqual(c.gestureButtons, [3, 4]); expectTrue(c.horizontalInvert)
            for value in [Double.infinity, -Double.infinity, Double.nan] {
                var invalid = AppConfig(); invalid.sensitivity = value; invalid.deadZone = value
                store.save(invalid); expectEqual(store.load(), .defaults)
            }
            for buttons: [Any] in [[3.5], [true], [], [32], ["3"]] {
                defaults.set(["gestureButtons": buttons, "sensitivity": true, "deadZone": "9"], forKey: ConfigStore.key)
                expectEqual(store.load(), .defaults)
            }
        }
    }
    func testBoundsAndButtonParsing() {
        var c = AppConfig(); c.sensitivity = 0; c.deadZone = 999
        expectEqual(c.validated().sensitivity, 100); expectEqual(c.validated().deadZone, 80)
        expectEqual(AppConfig.parseButtons(" 4,3,4 "), [3, 4])
        for text in ["", "3,", "0,4", "3,a", "32", "-1", "3.5"] { expectEqual(AppConfig.parseButtons(text), nil) }
    }
    func testVerticalPreferenceMigrationAndIndependentEnablement() {
        withDefaults { defaults, _ in
            let store = ConfigStore(defaults: defaults)
            defaults.set(["enabled": true, "horizontalEnabled": false], forKey: ConfigStore.key)
            expectFalse(store.load().verticalEnabled)
            expectFalse(store.load().shouldRun)
            defaults.set(["enabled": true, "horizontalEnabled": true], forKey: ConfigStore.key)
            expectTrue(store.load().verticalEnabled)
            var verticalOnly = store.load()
            verticalOnly.horizontalEnabled = false
            store.save(verticalOnly)
            expectTrue(store.load().verticalEnabled)
            expectTrue(store.load().shouldRun)
            expectTrue(store.load().gestureConfig.verticalEnabled)
        }
    }
    func testSeparateProcessRestoresSavedSettings() throws {
        try withDefaults { _, name in
            for mode in ["--write-config-fixture", "--read-config-fixture"] {
                let child = Process()
                child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
                child.arguments = [mode, name]
                try child.run(); child.waitUntilExit()
                expectEqual(child.terminationStatus, 0, file: #filePath, line: #line)
            }
        }
    }
}
