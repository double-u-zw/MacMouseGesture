import Foundation
import CoreGraphics

private let finderIdentity = WindowApplicationIdentity(pid: 1234, identifier: "com.apple.finder")
private let otherIdentity = WindowApplicationIdentity(pid: 5678, identifier: "com.google.Chrome")

let desktopActionChecks: [(String, () throws -> Void)] = [
    ("desktop actions route through existing executor without global Finder shortcuts", {
        var opened = 0, finderPosts: [pid_t] = [], keyboardPosts: [SystemKeyBinding] = [], verticalPosts = 0
        let finder = FinderAction(openHome: { opened += 1; return true }, performOnMain: { $0() },
            permissionGranted: { true }, frontmostApplication: { finderIdentity }, postNewFolder: { finderPosts.append($0); return true })
        let executor = MouseButtonActionExecutor(verticalAvailable: { true }, postVertical: { _ in verticalPosts += 1; return true },
            postKeyboard: { keyboardPosts.append(SystemKeyBinding(keyCode: $0, modifierFlags: $1.rawValue)); return true }, finder: finder)
        expectTrue(executor.execute(.system(.openFinder), button: 5))
        expectTrue(executor.execute(.system(.newFolder), button: 6))
        expectEqual(opened, 1); expectEqual(finderPosts, [finderIdentity.pid]); expectTrue(keyboardPosts.isEmpty)
        expectTrue(executor.execute(.system(.lockScreen), button: 7))
        expectEqual(keyboardPosts, [SystemKeyBinding(keyCode: 12, modifierFlags: CGEventFlags.maskCommand.rawValue | CGEventFlags.maskControl.rawValue)])
        expectEqual(verticalPosts, 0)
    }),
    ("New Folder cannot affect another foreground app or activate Finder", {
        var opened = 0, posts = 0
        for application: WindowApplicationIdentity? in [nil, otherIdentity, WindowApplicationIdentity(pid: 0, identifier: "com.apple.finder")] {
            let finder = FinderAction(openHome: { opened += 1; return true }, performOnMain: { $0() },
                permissionGranted: { true }, frontmostApplication: { application }, postNewFolder: { _ in posts += 1; return true })
            expectFalse(finder.newFolder() == .success)
        }
        expectEqual(opened, 0); expectEqual(posts, 0)
    }),
    ("New Folder cancels when foreground or Finder process changes", {
        for replacement: WindowApplicationIdentity? in [nil, otherIdentity, WindowApplicationIdentity(pid: 9999, identifier: "com.apple.finder")] {
            var reads = 0, posts = 0
            let finder = FinderAction(permissionGranted: { true }, frontmostApplication: {
                reads += 1; return reads == 1 ? finderIdentity : replacement
            }, postNewFolder: { _ in posts += 1; return true })
            expectEqual(finder.newFolder(), .cancelled); expectEqual(posts, 0)
        }
    }),
    ("New Folder refuses unavailable or lost Accessibility permission", {
        for availableReads in [0, 1] {
            var reads = 0, posts = 0
            let finder = FinderAction(permissionGranted: { reads += 1; return reads <= availableReads },
                frontmostApplication: { finderIdentity }, postNewFolder: { _ in posts += 1; return true })
            expectEqual(finder.newFolder(), .permissionDenied); expectEqual(posts, 0)
        }
    }),
    ("New Folder failed submission reports failure without retry or another backend", {
        var posts = 0, globalPosts = 0, opens = 0
        let finder = FinderAction(openHome: { opens += 1; return true }, permissionGranted: { true },
            frontmostApplication: { finderIdentity }, postNewFolder: { _ in posts += 1; return false })
        let executor = MouseButtonActionExecutor(verticalAvailable: { false }, postVertical: { _ in false },
            postKeyboard: { _, _ in globalPosts += 1; return true }, finder: finder)
        expectFalse(executor.execute(.system(.newFolder)))
        expectEqual(posts, 1); expectEqual(globalPosts, 0); expectEqual(opens, 0)
    }),
    ("Open Finder queues main-thread work and records actual acknowledgement", {
        for acknowledgement in [true, false] {
            var pending: (() -> Void)?, opens = 0, logs: [String] = []
            let finder = FinderAction(openHome: { opens += 1; return acknowledgement },
                performOnMain: { pending = $0 }, diagnostic: { logs.append($0) })
            expectTrue(finder.open()); expectEqual(opens, 0)
            expectFalse(logs.contains { $0.contains("stage=complete") })
            pending?(); expectEqual(opens, 1)
            expectTrue(logs.last?.contains("stage=complete result=\(acknowledgement ? "success" : "failed")") == true)
        }
    }),
    ("Lock Screen propagates event submission failure", {
        var posts = 0
        let executor = MouseButtonActionExecutor(verticalAvailable: { false }, postVertical: { _ in false },
            postKeyboard: { _, _ in posts += 1; return false })
        expectFalse(executor.execute(.system(.lockScreen))); expectEqual(posts, 1)
    }),
    ("desktop action persistence retains existing mappings flags and global parameters", {
        let domain = "local.macmousegesture.desktop-actions.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let store = ConfigStore(defaults: defaults)
        var config = AppConfig(); config.sensitivity = 713.25; config.deadZone = 5
        let existing = config.mappingStore.mappings
        let actions: [MouseAction] = [.system(.lockScreen), .system(.openFinder), .system(.newFolder)]
        let triggers: [MouseTrigger] = [.shortPress, .longPress(modifiers: [.command]), .wheel(.down, modifiers: [.control])]
        let added = zip(actions, triggers).map { MouseMapping(input: .button(6), trigger: $1, action: $0, isEnabled: $0 != .system(.openFinder)) }
        config.mappings = existing + added
        store.save(config)
        let loaded = store.load()
        expectEqual(loaded.sensitivity, 713.25); expectEqual(loaded.deadZone, 5)
        expectEqual(loaded.dragMappingsManaged, config.dragMappingsManaged)
        for row in existing + added { expectEqual(loaded.mappingStore.mapping(for: row.input, trigger: row.trigger), row) }
        let data = defaults.dictionary(forKey: ConfigStore.key)![ConfigStore.mappingsKey] as! Data
        let document = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        expectEqual(document["version"] as? Int, 4)
        for action in actions {
            expectEqual(try JSONDecoder().decode(MouseAction.self, from: JSONEncoder().encode(action)), action)
            expectEqual(MouseAction(legacy: action.legacyConfiguration!), action)
        }
    })
]
