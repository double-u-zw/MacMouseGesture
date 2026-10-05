import Foundation
import CoreGraphics
import GestureCore

private func mappingDefaults(_ body: (ConfigStore, UserDefaults) throws -> Void) rethrows {
    let name = "local.macmousegesture.mapping.\(UUID())"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    try body(ConfigStore(defaults: defaults), defaults)
}
private func roundTrip<T: Codable & Equatable>(_ value: T) throws {
    expectEqual(try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value)), value)
}
private func rejects(_ operation: () throws -> Void) {
    do { try operation(); expectTrue(false, "invalid data must fail") } catch {}
}
private func row(_ button: Int = 4, _ trigger: MouseTrigger = .shortPress, _ action: MouseAction = .system(.showDesktop), enabled: Bool = true) -> MouseMapping {
    MouseMapping(input: .button(button), trigger: trigger, action: action, isEnabled: enabled)
}
private func mouse(_ type: CGEventType, button: Int = 3, dx: Int64 = 0, dy: Int64 = 0) -> CGEvent {
    let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: .zero, mouseButton: .center)!
    event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(button))
    event.setIntegerValueField(.mouseEventDeltaX, value: dx); event.setIntegerValueField(.mouseEventDeltaY, value: dy)
    return event
}

let mouseMappingChecks: [(String, () throws -> Void)] = [
    ("mapping Input Codable and one-based conversion", {
        for n in [3,4,5,6,16,32] { try roundTrip(MouseInput.button(n)); expectEqual(MouseInput.button(n).cgNumber, n-1) }
    }),
    ("mapping invalid input cannot capture primary buttons", {
        for n in [-1,0,1,2,33] {
            expectFalse(MouseInput.button(n).isSupported)
            rejects { _ = try JSONDecoder().decode(MouseInput.self, from: Data("{\"kind\":\"button\",\"number\":\(n)}".utf8)) }
        }
        rejects { _ = try JSONDecoder().decode(MouseInput.self, from: Data(#"{"kind":"button","number":true}"#.utf8)) }
    }),
    ("mapping Trigger Codable all existing triggers", {
        try roundTrip(MouseTrigger.shortPress)
        for d in MouseDragDirection.allCases { try roundTrip(MouseTrigger.drag(d)) }
    }),
    ("mapping unknown trigger is never reinterpreted as click", {
        rejects { _ = try JSONDecoder().decode(MouseTrigger.self, from: Data(#"{"kind":"doubleClick"}"#.utf8)) }
        rejects { _ = try JSONDecoder().decode(MouseTrigger.self, from: Data(#"{"kind":"drag","direction":"diagonal"}"#.utf8)) }
    }),
    ("mapping Action Codable all categories", {
        for a: MouseAction in [.none,.system(.showDesktop),.system(.missionControl),.system(.appExpose),.system(.launchpad),.system(.lockScreen),.system(.previousSpace),.system(.nextSpace),.window(.minimize),.window(.toggleFullscreen),.navigation(.back),.navigation(.forward),.media(.playPause)] { try roundTrip(a) }
    }),
    ("mapping keyboard main key and multiple modifiers roundtrip", {
        for flags in [UInt64(0), CGEventFlags.maskCommand.rawValue, KeyboardShortcut.modifierMask] {
            let key = KeyboardShortcut(keyCode: 20, modifierFlags: flags)!
            try roundTrip(key); try roundTrip(MouseAction.keyboardShortcut(key))
        }
    }),
    ("mapping malformed shortcut safely becomes none", {
        for code in [55,56,58,59,128] {
            let json = "{\"kind\":\"keyboardShortcut\",\"shortcut\":{\"keyCode\":\(code),\"modifierFlags\":1048576}}"
            expectEqual(try JSONDecoder().decode(MouseAction.self, from: Data(json.utf8)), .none)
        }
    }),
    ("mapping unknown action kind and value degrade to none", {
        for json in [#"{"kind":"shell","value":"ignored"}"#, #"{"kind":"system","value":"futureAction"}"#] {
            expectEqual(try JSONDecoder().decode(MouseAction.self, from: Data(json.utf8)), .none)
        }
    }),
    ("mapping MouseMapping identity and disabled status Codable", { try roundTrip(row(6, .shortPress, .navigation(.back), enabled: false)) }),
    ("mapping store add and resolve", {
        var store = MouseMappingStore(); let r = row(); expectEqual(store.add(r), r.id)
        expectEqual(store.action(for: .button(4), trigger: .shortPress), .system(.showDesktop))
        expectEqual(store.action(for: .button(6), trigger: .shortPress), nil)
    }),
    ("mapping store update preserves identity", {
        var r = row(); var store = MouseMappingStore(mappings: [r]); r.action = .none
        expectTrue(store.update(r)); expectEqual(store.mappings, [r]); expectEqual(store.action(for: r.input, trigger: r.trigger), .some(.none))
    }),
    ("mapping store delete and unknown deletion", {
        let r = row(); var store = MouseMappingStore(mappings: [r]); store.delete(UUID()); expectEqual(store.mappings.count,1)
        store.delete(r.id); expectEqual(store.action(for: r.input, trigger: r.trigger),nil)
    }),
    ("mapping enable disable and restore", {
        let r = row(); var store = MouseMappingStore(mappings: [r]); store.setEnabled(false,id:r.id)
        expectEqual(store.action(for:r.input,trigger:r.trigger),nil); expectEqual(store.mappings[0].action,r.action)
        store.setEnabled(true,id:r.id); expectEqual(store.action(for:r.input,trigger:r.trigger),r.action)
    }),
    ("mapping duplicate add opens existing even when disabled", {
        let r = row(enabled:false); var store = MouseMappingStore(mappings:[r])
        expectEqual(store.add(row(4,.shortPress,.none)),r.id); expectEqual(store.mappings,[r])
    }),
    ("mapping update refuses conflicting trigger", {
        let a = row(); var b = row(5); var store = MouseMappingStore(mappings:[a,b]); b.input = a.input
        expectFalse(store.update(b)); expectEqual(store.mappings[1].input,.button(5))
    }),
    ("mapping decoded duplicates resolve exactly one action", {
        let a = row(); let b = row(4,.shortPress,.none)
        let store = MouseMappingStore(mappings:[a,b]); expectEqual(store.mappings,[a])
        expectEqual(try MouseMappingStore(data:store.encoded()).mappings,[a])
    }),
    ("mapping invalid input and reused UUID rejected", {
        let a = row(); var b = row(5); b.id = a.id; var store = MouseMappingStore(mappings:[a])
        expectEqual(store.add(b),nil); expectEqual(store.add(row(2)),nil)
        expectFalse(store.update(row(1)))
    }),
    ("mapping short press and drag resolve independently", {
        let a = row(); let b = row(4,.drag(.left),.system(.previousSpace)); var store = MouseMappingStore(mappings:[a,b])
        store.setEnabled(false,id:a.id)
        expectEqual(store.action(for:.button(4),trigger:.shortPress),nil)
        expectEqual(store.action(for:.button(4),trigger:.drag(.left)),b.action)
    }),
    ("mapping buttons 4 and 5 isolated", {
        let a = row(); let b = row(5,.shortPress,.none); var store = MouseMappingStore(mappings:[a,b]); store.delete(a.id)
        expectEqual(store.action(for:b.input,trigger:b.trigger),.some(.none))
    }),
    ("mapping migration preserves both legacy button actions", {
        mappingDefaults { store,d in
            d.set(["button4ClickAction":["action":"showDesktop"],"button5ClickAction":["action":"back"]],forKey:ConfigStore.key)
            let c=store.load(); expectEqual(c.mappingStore.action(for:.button(4),trigger:.shortPress),.system(.showDesktop))
            expectEqual(c.mappingStore.action(for:.button(5),trigger:.shortPress),.navigation(.back))
            expectTrue(d.dictionary(forKey:ConfigStore.key)?[ConfigStore.mappingsKey] is Data)
        }
    }),
    ("mapping migration custom shortcut preserves key and modifiers", {
        mappingDefaults { store,d in
            d.set(["button4ClickAction":["action":"customShortcut","keyCode":20,"modifierFlags":KeyboardShortcut.modifierMask]],forKey:ConfigStore.key)
            expectEqual(store.load().mappingStore.action(for:.button(4),trigger:.shortPress),.keyboardShortcut(KeyboardShortcut(keyCode:20,modifierFlags:KeyboardShortcut.modifierMask)!))
        }
    }),
    ("mapping new install keeps stable defaults none and gestures", {
        mappingDefaults { store,_ in
            let c=store.load(); expectEqual(c,.defaults); expectEqual(c.mappingStore.mappings.count,10)
            expectEqual(c.mappingStore.action(for:.button(4),trigger:.shortPress),.some(.none))
            expectEqual(c.gestureConfig.deadZone,8); expectEqual(c.gestureButtons,[3,4])
        }
    }),
    ("mapping migration unknown legacy action fails safe", {
        mappingDefaults { store,d in
            d.set(["button4ClickAction":["action":"future"],"button5ClickAction":["action":"customShortcut","keyCode":55,"modifierFlags":0]],forKey:ConfigStore.key)
            for n in [4,5] { expectEqual(store.load().mappingStore.action(for:.button(n),trigger:.shortPress),.some(.none)) }
        }
    }),
    ("mapping migration idempotent stable IDs and bytes", {
        mappingDefaults { store,d in
            d.set(["button4ClickAction":["action":"back"],"gestureButtons":[4],"sensitivity":667,"deadZone":5],forKey:ConfigStore.key)
            let c=store.load(); let data=d.dictionary(forKey:ConfigStore.key)?[ConfigStore.mappingsKey] as? Data
            for _ in 0..<10 { expectEqual(ConfigStore(defaults:d).load(),c) }
            expectEqual(d.dictionary(forKey:ConfigStore.key)?[ConfigStore.mappingsKey] as? Data,data)
            expectEqual(c.deadZone,5); expectEqual(c.sensitivity,667); expectEqual(c.gestureButtons,[4])
        }
    }),
    ("mapping new format wins over stale legacy fields", {
        try mappingDefaults { store,d in
            let empty=try MouseMappingStore().encoded()
            d.set([ConfigStore.mappingsKey:empty,"button4ClickAction":["action":"showDesktop"]],forKey:ConfigStore.key)
            expectEqual(store.load().mappingStore.action(for:.button(4),trigger:.shortPress),nil)
        }
    }),
    ("mapping corrupt or future document does not resurrect old actions", {
        mappingDefaults { store,d in
            for raw: Any in [Data("broken".utf8),Data(#"{"version":99,"mappings":[]}"#.utf8),"not data"] {
                d.set([ConfigStore.mappingsKey:raw,"button4ClickAction":["action":"showDesktop"]],forKey:ConfigStore.key)
                expectEqual(store.load().mappingStore.action(for:.button(4),trigger:.shortPress),nil)
            }
        }
    }),
    ("mapping disabled status persistence keeps action and UUID", {
        mappingDefaults { store,_ in
            var c=AppConfig();let r=row(6,.shortPress,.system(.showDesktop),enabled:false);c.mappings=[r];store.save(c)
            expectEqual(store.load().mappingStore.mapping(for:r.input,trigger:r.trigger),r)
            expectEqual(store.load().mappingStore.action(for:r.input,trigger:r.trigger),nil)
        }
    }),
    ("mapping deletion persists and never remigrates", {
        mappingDefaults { store,_ in
            var c=store.load();c.button4ClickAction=ButtonClickConfiguration(action:.showDesktop);store.save(c)
            c.mappings.removeAll { $0.trigger == .shortPress };store.save(c)
            for _ in 0..<3 { expectFalse(store.load().mappingStore.mappings.contains { $0.trigger == .shortPress }) }
        }
    }),
    ("mapping preserves unrelated preference fields on migration", {
        mappingDefaults { store,d in
            d.set(["unrelatedFutureValue":"keep","horizontalInvert":false,"freezePointer":false],forKey:ConfigStore.key)
            let c=store.load();expectFalse(c.horizontalInvert);expectFalse(c.freezePointer)
            expectEqual(d.dictionary(forKey:ConfigStore.key)?["unrelatedFutureValue"] as? String,"keep")
        }
    }),
    ("mapping drag projection follows legacy inversion and axes", {
        var c=AppConfig(); let id=c.mappingStore.mapping(for:.button(4),trigger:.drag(.left))!.id
        expectEqual(c.mappingStore.action(for:.button(4),trigger:.drag(.left)),.system(.previousSpace))
        c.horizontalInvert=false
        expectEqual(c.mappingStore.action(for:.button(4),trigger:.drag(.left)),.system(.nextSpace))
        expectEqual(c.mappingStore.mapping(for:.button(4),trigger:.drag(.left))?.id,id)
        c.horizontalEnabled=false
        expectEqual(c.mappingStore.action(for:.button(4),trigger:.drag(.left)),nil)
        expectEqual(c.mappingStore.action(for:.button(4),trigger:.drag(.up)),.system(.missionControl))
    }),
    ("mapping disabled drag button retains independent short press", {
        var c=AppConfig();c.button4ClickAction=ButtonClickConfiguration(action:.showDesktop);c.gestureButtons=[4]
        expectEqual(c.mappingStore.action(for:.button(4),trigger:.shortPress),.system(.showDesktop))
        expectEqual(c.mappingStore.action(for:.button(4),trigger:.drag(.left)),nil)
        expectTrue(c.mappingStore.shortPressCGButtons.contains(3))
    }),
    ("mapping active short press works with both gesture axes off", {
        var c=AppConfig();c.horizontalEnabled=false;c.verticalEnabled=false;expectFalse(c.shouldRun)
        c.button4ClickAction=ButtonClickConfiguration(action:.showDesktop);expectTrue(c.shouldRun)
        c.enabled=false;expectFalse(c.shouldRun)
    }),
    ("mapping disabled short press does not disable gesture", {
        var c=AppConfig();c.button4ClickAction=ButtonClickConfiguration(action:.showDesktop)
        var s=c.mappingStore;let r=s.mapping(for:.button(4),trigger:.shortPress)!;s.setEnabled(false,id:r.id);c.mappings=s.mappings
        expectEqual(c.mappingStore.action(for:.button(4),trigger:.shortPress),nil)
        expectEqual(c.mappingStore.action(for:.button(4),trigger:.drag(.left)),.system(.previousSpace))
        expectTrue(c.shouldRun)
    }),
    ("mapping executor adapter retains accepted desktop native path", {
        var posted:[SystemKeyBinding]=[]
        let e=MouseButtonActionExecutor(verticalAvailable:{false},postVertical:{_ in false},postKeyboard:{posted.append(SystemKeyBinding(keyCode:$0,modifierFlags:$1.rawValue));return true},systemHotKeys:{[:]})
        expectTrue(e.execute(MouseAction.system(.showDesktop),button:4))
        expectEqual(posted,[SystemKeyBinding(keyCode:103,modifierFlags:8388608)])
        expectFalse(e.execute(MouseAction.system(.previousSpace)))
        expectEqual(posted.count,1)
    }),
    ("mapping mailbox short-only edges have no gesture modifier or freeze", {
        let box=InputMailbox(buttons:[2,3,4,7],gesture:true,freeze:true,gestureButtons:[3,4])
        expectTrue(box.capture(type:.otherMouseDown,event:mouse(.otherMouseDown,button:7)))
        expectFalse(box.capture(type:.otherMouseDragged,event:mouse(.otherMouseDragged,button:7,dx:2)))
        expectTrue(box.capture(type:.otherMouseUp,event:mouse(.otherMouseUp,button:7)))
        let records=box.drain();expectEqual(records.count,3)
        expectFalse(records.contains { if case .modifier = $0 { return true }; return false })
    }),
    ("mapping mixed buttons preserve legacy modifier release ordering", {
        let box=InputMailbox(buttons:[3,4,7],gesture:true,freeze:true,gestureButtons:[3,4])
        for (b,down) in [(7,true),(3,true),(4,true),(3,false),(4,false),(7,false)] {
            let t:CGEventType=down ? .otherMouseDown:.otherMouseUp
            expectTrue(box.capture(type:t,event:mouse(t,button:b)))
        }
        let edges=box.drain().compactMap { r -> Bool? in if case .modifier(let down,_) = r { return down };return nil }
        expectEqual(edges,[true,false])
    }),
    ("mapping standalone clicks jitter and both generic buttons", {
        var tracker=StandaloneShortPressTracker();var c=GestureConfig();c.deadZone=8
        for b in [2,7] { tracker.down(b,at:1,config:c) }
        tracker.move(dx:2,dy:1,at:1.02,count:1);expectTrue(tracker.up(2));expectTrue(tracker.up(7));expectFalse(tracker.isActive)
    }),
    ("mapping standalone threshold crossing stays sticky on reversal", {
        var tracker=StandaloneShortPressTracker();var c=GestureConfig();c.deadZone=8
        tracker.down(7,at:1,config:c);tracker.move(dx:9,dy:0,at:1.01,count:1);tracker.move(dx:-9,dy:0,at:1.02,count:1)
        expectFalse(tracker.up(7));expectFalse(tracker.isActive)
    }),
    ("mapping standalone uses configured deadZone all directions", {
        for (x,y) in [(5.0,0.0),(-5,0),(0,5),(0,-5)] {
            var t=StandaloneShortPressTracker();var c=GestureConfig();c.deadZone=5;t.down(7,at:1,config:c)
            t.move(dx:x,dy:y,at:1.01,count:1);expectFalse(t.up(7))
        }
    }),
    ("mapping standalone cancellation has no unmatched click", {
        var t=StandaloneShortPressTracker();t.down(7,at:1,config:GestureConfig());t.reset()
        expectFalse(t.up(7));expectFalse(t.isActive)
        t.down(7,at:2,config:GestureConfig());expectTrue(t.up(7))
    }),
    ("mapping standalone button joining active legacy gesture is suppressed", {
        var machine=GestureMachine();machine.down(at:1);machine.move(dx:30,dy:0,at:1.01,count:1)
        var t=StandaloneShortPressTracker();t.down(7,at:1.02,config:machine.config,sharedMachine:machine)
        expectFalse(t.up(7))
        t.down(7,at:2,config:machine.config);t.observeShared(machine);expectFalse(t.up(7))
    }),
    ("mapping legacy mailbox explicit drag set preserves event trace", {
        let legacy=InputMailbox(buttons:[3,4],gesture:true,freeze:true)
        let mapped=InputMailbox(buttons:[3,4],gesture:true,freeze:true,gestureButtons:[3,4])
        var time=1.0
        for (type,b,x,y) in [(CGEventType.otherMouseDown,3,Int64(0),Int64(0)),(.mouseMoved,3,-20,0),(.otherMouseDown,4,0,0),(.mouseMoved,3,10,0),(.otherMouseUp,3,0,0),(.mouseMoved,4,0,-20),(.otherMouseUp,4,0,0)] {
            time+=0.01
            expectEqual(legacy.capture(type:type,event:mouse(type,button:b,dx:x,dy:y),receivedAt:time),mapped.capture(type:type,event:mouse(type,button:b,dx:x,dy:y),receivedAt:time))
        }
        func trace(_ records:[InputRecord]) -> [String] {
            records.map { r in
                switch r {
                case .button(let n,let down,let t): "button \(n) \(down) \(t)"
                case .modifier(let down,let t): "modifier \(down) \(t)"
                case .motion(let x,let y,let t,let count): "motion \(x) \(y) \(t) \(count)"
                default: "other"
                }
            }
        }
        expectEqual(trace(legacy.drain()),trace(mapped.drain()))
    }),
    ("mapping short-only Escape cancels without blocking cursor", {
        let box=InputMailbox(buttons:[7],gesture:true,freeze:true,gestureButtons:[])
        expectTrue(box.capture(type:.otherMouseDown,event:mouse(.otherMouseDown,button:7)))
        let escape=CGEvent(keyboardEventSource:nil,virtualKey:53,keyDown:true)!
        expectFalse(box.capture(type:.keyDown,event:escape))
        expectTrue(box.drain().contains { if case .cancel("Escape") = $0 { return true };return false })
        expectFalse(box.capture(type:.otherMouseUp,event:mouse(.otherMouseUp,button:7)))
        expectFalse(box.capture(type:.mouseMoved,event:mouse(.mouseMoved,dx:30)))
    }),
    ("mapping short-only tap recovery quarantines held button", {
        let box=InputMailbox(buttons:[7],gesture:true,freeze:true,gestureButtons:[])
        _=box.capture(type:.otherMouseDown,event:mouse(.otherMouseDown,button:7));_=box.drain()
        box.interruptForTapRecovery("test");_=box.drain();expectTrue(box.resumeAfterTapRecovery())
        expectFalse(box.capture(type:.otherMouseDown,event:mouse(.otherMouseDown,button:7)))
        expectFalse(box.capture(type:.otherMouseUp,event:mouse(.otherMouseUp,button:7)))
        expectTrue(box.drain().isEmpty)
        expectTrue(box.capture(type:.otherMouseDown,event:mouse(.otherMouseDown,button:7)))
    }),
    ("mapping standalone rapid duplicate edges reset independently", {
        var t=StandaloneShortPressTracker()
        for i in 0..<100 {
            t.down(2,at:Double(i),config:GestureConfig());t.down(2,at:Double(i),config:GestureConfig())
            t.down(7,at:Double(i),config:GestureConfig());expectTrue(t.up(2));expectFalse(t.up(2));expectTrue(t.up(7));expectFalse(t.isActive)
        }
    }),
    ("mapping UI save edit delete disable uses persisted store", {
        mappingDefaults { store,_ in
            let model=AppViewModel(config:store.load());model.applyConfig={ c,_ in store.save(c);model.show(c) }
            let r=row(6);if case .saved=model.saveMapping(r) {} else { expectTrue(false) }
            expectEqual(store.load().mappingStore.mapping(for:r.input,trigger:r.trigger),r)
            model.setMappingEnabled(false,id:r.id);expectEqual(store.load().mappingStore.action(for:r.input,trigger:r.trigger),nil)
            var edited=r;edited.action = .none
            if case .saved=model.saveMapping(edited) {} else { expectTrue(false) }
            model.deleteMapping(r.id);expectEqual(store.load().mappingStore.mapping(for:r.input,trigger:r.trigger),nil)
        }
    }),
    ("mapping UI duplicates open existing without overwriting", {
        let model=AppViewModel();var applied=0;model.applyConfig={_,_ in applied+=1}
        let existing=model.config.mappingStore.mapping(for:.button(4),trigger:.shortPress)!
        if case .existing(let r)=model.saveMapping(row()) { expectEqual(r,existing) } else { expectTrue(false) }
        expectEqual(applied,0)
    }),
    ("mapping UI drag adapter refuses unrepresentable actions", {
        let model=AppViewModel();var applied=0;model.applyConfig={_,_ in applied+=1}
        var r=model.config.mappingStore.mapping(for:.button(4),trigger:.drag(.left))!
        r.action = .system(.showDesktop)
        if case .unavailable=model.saveMapping(r) {} else { expectTrue(false) }
        expectEqual(applied,0)
    }),
    ("mapping editing draft cancel does not mutate saved shortcut", {
        let key=KeyboardShortcut(keyCode:17,modifierFlags:1048576)!
        var original=AppConfig();original.button4ClickAction=ButtonClickConfiguration(action:.customShortcut,shortcut:key)
        let model=AppViewModel(config:original);var draft=model.config.mappingStore.mapping(for:.button(4),trigger:.shortPress)!
        draft.action = .none
        expectEqual(model.config,original);expectEqual(model.config.mappingStore.action(for:draft.input,trigger:draft.trigger),.keyboardShortcut(key))
    }),
    ("mapping normal menu policy keeps unknown acceptance explicit", {
        expectTrue(MouseAction.none.isStandardChoice);expectTrue(MouseAction.system(.showDesktop).isStandardChoice)
        for a:MouseAction in [.navigation(.back),.navigation(.forward),.system(.launchpad),.media(.playPause),.system(.lockScreen)] {
            expectFalse(a.isStandardChoice);expectTrue(a.acceptanceNote != nil)
        }
        expectTrue(MouseAction.navigation(.back).acceptanceNote!.contains("Finder"))
    }),
    ("mapping persistence across separate processes including deletion", {
        let name="local.macmousegesture.mapping.process.\(UUID())";let d=UserDefaults(suiteName:name)!
        defer { d.removePersistentDomain(forName:name) }
        for mode in ["--write-mapping-fixture","--read-mapping-fixture"] {
            let p=Process();p.executableURL=URL(fileURLWithPath:CommandLine.arguments[0]);p.arguments=[mode,name]
            try p.run();p.waitUntilExit();expectEqual(p.terminationStatus,0)
        }
    })
]
