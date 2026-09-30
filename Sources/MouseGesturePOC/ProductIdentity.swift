import Foundation

/// Current identity and the explicit compatibility boundary for pre-Build-16 users.
enum ProductIdentity {
    static let current = "io.github.double-u-zw.macmousegesture"
    static let legacy = "local.macmousegesture.poc"
    static let migrationKey = "bundleIdentifierMigrationV1Completed"
    static let configurationFields = ["enabled", "gestureButtons", "horizontalEnabled",
        "verticalEnabled", "horizontalInvert", "sensitivity", "deadZone", "freezePointer"]

    /// Call once while holding the shared instance lock, before loading any UI state.
    /// Read only the legacy persistent domain, never its global/registration fallbacks.
    static func migrateSettings(defaults: UserDefaults = .standard,
                                currentDomain: String = current,
                                legacyDomain: String = legacy) {
        let destination = defaults.persistentDomain(forName: currentDomain) ?? [:]
        guard destination[migrationKey] as? Bool != true else { return }
        let source = defaults.persistentDomain(forName: legacyDomain) ?? [:]
        if let old = source[ConfigStore.key] as? [String: Any] {
            // Preserve even malformed existing destination values; ConfigStore owns validation.
            if destination[ConfigStore.key] == nil || destination[ConfigStore.key] is [String: Any] {
                var merged = destination[ConfigStore.key] as? [String: Any] ?? [:]
                for key in configurationFields where merged[key] == nil {
                    if let value = old[key] { merged[key] = value }
                }
                if !merged.isEmpty { defaults.set(merged, forKey: ConfigStore.key) }
            }
        }
        if destination[OnboardingState.completedKey] == nil,
           let completed = source[OnboardingState.completedKey] {
            defaults.set(completed, forKey: OnboardingState.completedKey)
        }
        // Written last. A retry after interruption still never overwrites new values.
        defaults.set(true, forKey: migrationKey)
    }
}
