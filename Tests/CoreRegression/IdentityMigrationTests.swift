import Foundation

struct IdentityMigrationTests {
    private func fixture(_ body: (UserDefaults, String, String) -> Void) {
        let new = "test.identity.new.\(UUID().uuidString)"
        let old = "test.identity.old.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: new)!
        defer {
            defaults.removePersistentDomain(forName: new)
            defaults.removePersistentDomain(forName: old)
        }
        body(defaults, new, old)
    }
    func testFresh() {
        fixture { d, n, o in
            ProductIdentity.migrateSettings(defaults: d, currentDomain: n, legacyDomain: o)
            expectEqual(ConfigStore(defaults: d).load(), .defaults)
            expectTrue(OnboardingState.needsWelcome(d))
            expectTrue(d.bool(forKey: ProductIdentity.migrationKey))
            expectTrue(d.persistentDomain(forName: o) == nil)
        }
    }
    func testLegacy() {
        fixture { d, n, o in
            let legacy = UserDefaults(suiteName: o)!
            var config = AppConfig()
            config.enabled = false; config.gestureButtons = [4]
            config.horizontalEnabled = false; config.verticalEnabled = true
            config.horizontalInvert = false; config.sensitivity = 810
            config.deadZone = 15; config.freezePointer = false
            ConfigStore(defaults: legacy).save(config)
            ProductIdentity.migrateSettings(defaults: d, currentDomain: n, legacyDomain: o)
            expectEqual(ConfigStore(defaults: d).load(), config)
            expectEqual(ConfigStore(defaults: legacy).load(), config)
        }
    }
    func testNewWins() {
        fixture { d, n, o in
            d.setPersistentDomain([ConfigStore.key: ["horizontalInvert": true, "sensitivity": 940]], forName: n)
            d.setPersistentDomain([ConfigStore.key: ["horizontalInvert": false, "sensitivity": 810, "deadZone": 19]], forName: o)
            ProductIdentity.migrateSettings(defaults: d, currentDomain: n, legacyDomain: o)
            let config = ConfigStore(defaults: d).load()
            expectTrue(config.horizontalInvert); expectEqual(config.sensitivity, 940)
            expectEqual(config.deadZone, 19)
        }
    }
    func testIdempotency() {
        fixture { d, n, o in
            d.setPersistentDomain([ConfigStore.key: ["sensitivity": 810]], forName: o)
            ProductIdentity.migrateSettings(defaults: d, currentDomain: n, legacyDomain: o)
            let before = d.persistentDomain(forName: n)! as NSDictionary
            ProductIdentity.migrateSettings(defaults: d, currentDomain: n, legacyDomain: o)
            expectTrue(before.isEqual(to: d.persistentDomain(forName: n)!))
            var config = ConfigStore(defaults: d).load(); config.sensitivity = 1200
            ConfigStore(defaults: d).save(config)
            d.setPersistentDomain([ConfigStore.key: ["sensitivity": 2000]], forName: o)
            ProductIdentity.migrateSettings(defaults: d, currentDomain: n, legacyDomain: o)
            expectEqual(ConfigStore(defaults: d).load().sensitivity, 1200)
        }
    }
    func testOnboarding() {
        fixture { d, n, o in
            d.setPersistentDomain([OnboardingState.completedKey: true], forName: o)
            ProductIdentity.migrateSettings(defaults: d, currentDomain: n, legacyDomain: o)
            expectFalse(OnboardingState.needsWelcome(d))
            expectEqual(d.persistentDomain(forName: o)?[OnboardingState.completedKey] as? Bool, true)
        }
        fixture { d, n, o in
            d.set(false, forKey: OnboardingState.completedKey)
            d.setPersistentDomain([OnboardingState.completedKey: true], forName: o)
            ProductIdentity.migrateSettings(defaults: d, currentDomain: n, legacyDomain: o)
            expectTrue(OnboardingState.needsWelcome(d))
        }
    }
    func testIsolation() {
        fixture { d, n, o in
            d.setPersistentDomain(["unrelated": "do not copy", ConfigStore.key: ["unknown": 123, "sensitivity": 810]], forName: o)
            ProductIdentity.migrateSettings(defaults: d, currentDomain: n, legacyDomain: o)
            expectTrue(d.object(forKey: "unrelated") == nil)
            expectTrue(d.dictionary(forKey: ConfigStore.key)?["unknown"] == nil)
            expectEqual(d.persistentDomain(forName: o)?["unrelated"] as? String, "do not copy")
        }
    }
    func testMalformedNewWins() {
        fixture { d, n, o in
            d.set("existing malformed setting", forKey: ConfigStore.key)
            d.setPersistentDomain([ConfigStore.key: ["sensitivity": 810]], forName: o)
            ProductIdentity.migrateSettings(defaults: d, currentDomain: n, legacyDomain: o)
            expectEqual(d.string(forKey: ConfigStore.key), "existing malformed setting")
            expectEqual(ConfigStore(defaults: d).load(), .defaults)
        }
    }
}
