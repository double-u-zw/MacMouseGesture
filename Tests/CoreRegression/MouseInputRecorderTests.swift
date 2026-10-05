import Foundation
import CoreGraphics

private func press(_ raw: Int, flags: CGEventFlags = [], down: Bool = true) -> CGEvent {
    let type: CGEventType = down ? .otherMouseDown : .otherMouseUp
    let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: .zero, mouseButton: .center)!
    event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(raw)); event.flags = flags
    return event
}
private func recording(_ raw: Int, _ flags: CGEventFlags = []) -> RecordedMouseInput {
    RecordedMouseInput(button: MouseButtonIdentifier(rawValue: raw)!, modifiers: MouseModifiers(flags: flags))
}
private func mapping(_ mods: MouseModifiers, _ action: MouseAction, enabled: Bool = true) -> MouseMapping {
    MouseMapping(input: .button(4), trigger: .shortPress(modifiers: mods), action: action, isEnabled: enabled)
}
private func roundTripRecorder<T: Codable & Equatable>(_ value: T) throws {
    expectEqual(try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value)), value)
}

let mouseInputRecorderChecks: [(String, () throws -> Void)] = [
    ("recorder unified numbering preserves existing side buttons", {
        for raw in 0...31 {
            let id = MouseButtonIdentifier(rawValue: raw)!
            expectEqual(MouseButtonIdentifier(number: id.number), id)
            expectEqual(id.input.cgNumber, raw)
        }
        expectEqual(MouseButtonIdentifier(rawValue: 3)?.input, .button(4))
        expectEqual(MouseButtonIdentifier(rawValue: 4)?.input, .button(5))
    }),
    ("recorder friendly names include primary middle side and generic", {
        expectEqual((0...6).map { MouseButtonIdentifier(rawValue: $0)!.title },
                    ["左键","右键","中键","侧键 4","侧键 5","鼠标按钮 6","鼠标按钮 7"])
        expectEqual(MouseButtonIdentifier(rawValue: 31)?.title,"鼠标按钮 32")
    }),
    ("recorder invalid numbers including Int extremes do not trap", {
        for raw in [Int.min,-1,32,Int.max] { expectEqual(MouseButtonIdentifier(rawValue:raw),nil) }
        for n in [Int.min,0,33,Int.max] { expectEqual(MouseButtonIdentifier(number:n),nil) }
    }),
    ("recorder primary buttons stay protected and waiting", {
        let r=MouseInputRecorder(); r.begin()
        for raw in [0,1] {
            expectEqual(r.handle(type:raw==0 ? .leftMouseDown : .rightMouseDown,raw:raw),.primaryUnsupported)
            expectTrue(r.isRecording)
            expectEqual(r.handle(type:raw==0 ? .leftMouseUp : .rightMouseUp,raw:raw),.pass)
        }
        expectEqual(r.handle(type:.otherMouseDown,raw:2),.captured(recording(2)))
    }),
    ("recorder middle button capture", { let r=MouseInputRecorder();r.begin();expectEqual(r.handle(type:.otherMouseDown,raw:2),.captured(recording(2))) }),
    ("recorder button 4 capture", { let r=MouseInputRecorder();r.begin();expectEqual(r.handle(type:.otherMouseDown,raw:3),.captured(recording(3))) }),
    ("recorder button 5 capture", { let r=MouseInputRecorder();r.begin();expectEqual(r.handle(type:.otherMouseDown,raw:4),.captured(recording(4))) }),
    ("recorder button 6 capture", { let r=MouseInputRecorder();r.begin();expectEqual(r.handle(type:.otherMouseDown,raw:5),.captured(recording(5))) }),
    ("recorder UI button 31 capture", { let r=MouseInputRecorder();r.begin();expectEqual(r.handle(type:.otherMouseDown,raw:30),.captured(recording(30))) }),
    ("recorder CG raw 31 capture", { let r=MouseInputRecorder();r.begin();expectEqual(r.handle(type:.otherMouseDown,raw:31),.captured(recording(31))) }),
    ("recorder inactive input passes", { let r=MouseInputRecorder();expectEqual(r.handle(type:.otherMouseDown,raw:4),.pass);expectFalse(r.hasPendingRelease) }),
    ("recorder captures once and stops before next down", {
        let r=MouseInputRecorder();r.begin()
        expectEqual(r.handle(type:.otherMouseDown,raw:3),.captured(recording(3)))
        expectFalse(r.isRecording)
        expectEqual(r.handle(type:.otherMouseDown,raw:4),.pass)
        expectEqual(r.handle(type:.otherMouseUp,raw:3),.consume)
        expectFalse(r.hasPendingRelease)
    }),
    ("recorder repeated down and up never recapture", {
        let r=MouseInputRecorder();r.begin();_=r.handle(type:.otherMouseDown,raw:4)
        expectEqual(r.handle(type:.otherMouseDown,raw:4),.consume)
        expectEqual(r.handle(type:.otherMouseUp,raw:4),.consume)
        expectEqual(r.handle(type:.otherMouseUp,raw:4),.pass)
    }),
    ("recorder cancel while waiting restores next button", {
        let r=MouseInputRecorder();r.begin();r.cancel()
        expectFalse(r.isRecording);expectEqual(r.handle(type:.otherMouseDown,raw:3),.pass)
    }),
    ("recorder cancel after down quarantines the release", {
        let r=MouseInputRecorder();r.begin();_=r.handle(type:.otherMouseDown,raw:4);r.cancel()
        expectTrue(r.hasPendingRelease);expectEqual(r.handle(type:.otherMouseUp,raw:4),.consume)
        expectEqual(r.handle(type:.otherMouseDown,raw:4),.pass)
    }),
    ("recorder Escape cancels without leaking release or stale state", {
        let r=MouseInputRecorder();r.begin();_=r.handle(type:.otherMouseDown,raw:3);r.cancel(.escape)
        expectFalse(r.isRecording);expectEqual(r.handle(type:.otherMouseUp,raw:3),.consume)
        r.begin();expectEqual(r.handle(type:.otherMouseDown,raw:4),.captured(recording(4)))
    }),
    ("recorder sheet close cancels waiting and preserves normal input", {
        let r=MouseInputRecorder();r.begin();r.cancel(.sheetClosed)
        expectFalse(r.isRecording);expectEqual(r.handle(type:.otherMouseDown,raw:3),.pass)
    }),
    ("recorder every exit path protects a swallowed down/up pair", {
        for reason in MouseRecordingEndReason.allCases {
            let r=MouseInputRecorder();r.begin();_=r.handle(type:.otherMouseDown,raw:4);r.cancel(reason)
            expectFalse(r.isRecording);expectEqual(r.handle(type:.otherMouseUp,raw:4),.consume)
            expectFalse(r.hasPendingRelease)
        }
    }),
    ("recorder rerecord cannot capture a held repeat", {
        let r=MouseInputRecorder();r.begin();_=r.handle(type:.otherMouseDown,raw:3);r.begin()
        expectEqual(r.handle(type:.otherMouseDown,raw:3),.consume);expectTrue(r.isRecording)
        expectEqual(r.handle(type:.otherMouseUp,raw:3),.consume)
        expectEqual(r.handle(type:.otherMouseDown,raw:3),.captured(recording(3)))
    }),
    ("recorder shutdown clears pending state", {
        let r=MouseInputRecorder();r.begin();_=r.handle(type:.otherMouseDown,raw:3);r.shutdown()
        expectFalse(r.isRecording);expectFalse(r.hasPendingRelease)
    }),
    ("recorder ignores invalid raw events without stopping", {
        let r=MouseInputRecorder();r.begin()
        for raw in [-1,32] { expectEqual(r.handle(type:.otherMouseDown,raw:raw),.pass);expectTrue(r.isRecording) }
    }),
    ("recorder modifier only and motion do not complete", {
        let r=MouseInputRecorder();r.begin()
        for type in [CGEventType.flagsChanged,.mouseMoved,.keyDown] {
            expectEqual(r.handle(type:type,raw:3,flags:.maskCommand),.pass);expectTrue(r.isRecording)
        }
    }),
    ("recorder Command mouse input", { let r=MouseInputRecorder();r.begin();expectEqual(r.handle(type:.otherMouseDown,raw:3,flags:.maskCommand),.captured(recording(3,.maskCommand))) }),
    ("recorder Option mouse input", { let r=MouseInputRecorder();r.begin();expectEqual(r.handle(type:.otherMouseDown,raw:2,flags:.maskAlternate),.captured(recording(2,.maskAlternate))) }),
    ("recorder Control mouse input", { let r=MouseInputRecorder();r.begin();expectEqual(r.handle(type:.otherMouseDown,raw:4,flags:.maskControl),.captured(recording(4,.maskControl))) }),
    ("recorder Shift mouse input", { let r=MouseInputRecorder();r.begin();expectEqual(r.handle(type:.otherMouseDown,raw:5,flags:.maskShift),.captured(recording(5,.maskShift))) }),
    ("recorder multiple modifiers and display", {
        let r=MouseInputRecorder();r.begin()
        let value=recording(2,[.maskAlternate,.maskShift,.maskAlphaShift,.maskSecondaryFn])
        expectEqual(r.handle(type:.otherMouseDown,raw:2,flags:[.maskAlternate,.maskShift,.maskAlphaShift,.maskSecondaryFn]),.captured(value))
        expectEqual(value.modifiers,[.option,.shift]);expectEqual(value.title,"⌥⇧ + 中键")
    }),
    ("recorder mailbox swallows recorded pair before any mapping or drag", {
        let r=MouseInputRecorder();let box=InputMailbox(buttons:[3,4],gesture:true,freeze:true,recorder:r)
        r.begin();expectTrue(box.capture(type:.otherMouseDown,event:press(4),receivedAt:1))
        r.cancel();expectTrue(box.capture(type:.otherMouseUp,event:press(4,down:false),receivedAt:1.1))
        expectTrue(box.drain().isEmpty)
        expectTrue(box.capture(type:.otherMouseDown,event:press(4),receivedAt:2))
        expectTrue(box.capture(type:.otherMouseUp,event:press(4,down:false),receivedAt:2.1))
        let normal=box.drain();expectEqual(normal.count,4)
        if case .modifier(true,_) = normal[1] {} else { expectTrue(false,"normal gesture down did not recover") }
        if case .modifier(false,_) = normal[3] {} else { expectTrue(false,"normal gesture up did not recover") }
    }),
    ("recorder mailbox left and right pass to UI", {
        let r=MouseInputRecorder();let box=InputMailbox(buttons:[3,4],gesture:true,freeze:true,recorder:r);r.begin()
        for raw in [0,1] { expectFalse(box.capture(type:.leftMouseDown,event:press(raw),receivedAt:1)) }
        expectTrue(r.isRecording)
    }),
    ("recorder synthetic navigation events never count as recorded input", {
        let r=MouseInputRecorder();r.begin();let e=press(3)
        MouseActionEventOrigin.mark(e)
        expectEqual(r.capture(type:.otherMouseDown,event:e),.pass);expectTrue(r.isRecording)
    }),
    ("modifier plain and Command short press resolve separately", {
        let s=MouseMappingStore(mappings:[mapping([],.system(.showDesktop)),mapping(.command,.none)])
        expectEqual(s.shortPressAction(for:.button(4),modifiers:[]),.system(.showDesktop))
        expectEqual(s.shortPressAction(for:.button(4),modifiers:.command),.some(.none))
    }),
    ("modifier exact match takes precedence with one result", {
        let s=MouseMappingStore(mappings:[mapping([],.system(.showDesktop)),mapping(.command,.window(.minimize)),mapping([.command,.shift],.window(.toggleFullscreen))])
        expectEqual(s.shortPressAction(for:.button(4),modifiers:[.command,.shift]),.window(.toggleFullscreen))
        expectEqual(s.mappings.count,3)
    }),
    ("modifier match never uses a subset and plain fallback is explicit", {
        let only=MouseMappingStore(mappings:[mapping(.command,.window(.minimize))])
        expectEqual(only.shortPressAction(for:.button(4),modifiers:[.command,.shift]),nil)
        let fallback=MouseMappingStore(mappings:only.mappings+[mapping([],.system(.showDesktop))])
        expectEqual(fallback.shortPressAction(for:.button(4),modifiers:[.command,.shift]),.system(.showDesktop))
    }),
    ("modifier disabled exact mapping blocks plain fallback", {
        let s=MouseMappingStore(mappings:[mapping([],.system(.showDesktop)),mapping(.command,.window(.minimize),enabled:false)])
        expectEqual(s.shortPressAction(for:.button(4),modifiers:.command),nil)
    }),
    ("modifier duplicate combination cannot create a second action", {
        var s=MouseMappingStore(mappings:[mapping(.command,.system(.showDesktop))]);let id=s.mappings[0].id
        expectEqual(s.add(mapping(.command,.none)),id);expectEqual(s.mappings.count,1)
        expectTrue(s.add(mapping([],.none)) != nil);expectEqual(s.mappings.count,2)
    }),
    ("modifier trigger input action mapping Codable round trip", {
        for modifiers in [MouseModifiers.command,.option,.shift,.control,[.command,.shift],.supported] {
            try roundTripRecorder(modifiers);try roundTripRecorder(MouseTrigger.shortPress(modifiers:modifiers))
            let row=mapping(modifiers,.keyboardShortcut(KeyboardShortcut(keyCode:17,modifierFlags:MouseModifiers.command.rawValue)!))
            try roundTripRecorder(row);try roundTripRecorder(row.input);try roundTripRecorder(row.action)
        }
    }),
    ("modifier v1 migration stays plain while modified document uses v2", {
        let old=Data(#"{"version":1,"mappings":[{"id":"00000000-0000-0000-0000-000000000001","input":{"kind":"button","number":4},"trigger":{"kind":"shortPress"},"action":{"kind":"system","value":"showDesktop"},"isEnabled":true}]}"#.utf8)
        let store=try MouseMappingStore(data:old);expectEqual(store.mappings[0].trigger,.shortPress)
        let modified=MouseMappingStore(mappings:store.mappings+[mapping(.command,.none)])
        let data=try modified.encoded();expectEqual(try MouseMappingStore(data:data),modified)
        expectEqual(try JSONSerialization.jsonObject(with:data) as? [String:Any] != nil,true)
        expectEqual((try JSONSerialization.jsonObject(with:data) as! [String:Any])["version"] as? Int,2)
    }),
    ("modifier persistence preserves combinations across load and disabled delete", {
        let domain="local.macmousegesture.recorder.\(UUID())";let defaults=UserDefaults(suiteName:domain)!
        defer { defaults.removePersistentDomain(forName:domain) }
        var c=AppConfig();let row=mapping([.control,.option],.system(.showDesktop));c.mappings.append(row)
        let store=ConfigStore(defaults:defaults);store.save(c)
        var loaded=store.load();expectEqual(loaded.mappingStore.mapping(for:.button(4),trigger:row.trigger),row)
        var s=loaded.mappingStore;s.setEnabled(false,id:row.id);loaded.mappings=s.mappings;store.save(loaded)
        expectEqual(store.load().mappingStore.mapping(for:.button(4),trigger:row.trigger)?.isEnabled,false)
        s.delete(row.id);loaded.mappings=s.mappings;store.save(loaded)
        expectEqual(store.load().mappingStore.mapping(for:.button(4),trigger:row.trigger),nil)
        expectTrue(store.load().mappingStore.mapping(for:.button(4),trigger:.shortPress) != nil)
    }),
    ("modifier unknown flags are rejected rather than downgraded", {
        do {
            _=try JSONDecoder().decode(MouseTrigger.self,from:Data(#"{"kind":"shortPress","modifiers":1}"#.utf8))
            expectTrue(false,"unknown modifier became plain")
        } catch {}
    }),
    ("modifier changes at release and duplicate down preserve original press", {
        var contexts=MousePressContexts();contexts.down(3,modifiers:.command);contexts.down(3,modifiers:.shift)
        contexts.down(4,modifiers:.option)
        expectEqual(contexts.up(3),.command);expectEqual(contexts.up(4),.option)
        expectEqual(contexts.up(3),[])
    }),
    ("modifier context reset prevents stale modifiers", {
        var contexts=MousePressContexts();contexts.down(3,modifiers:.command);contexts.reset();contexts.down(3)
        expectEqual(contexts.up(3),[])
    }),
    ("modifier mailbox snapshots down flags before ordinary button boundary", {
        let box=InputMailbox(buttons:[3,4],gesture:true,freeze:true)
        _=box.capture(type:.otherMouseDown,event:press(3,flags:[.maskCommand,.maskShift]),receivedAt:1)
        _=box.capture(type:.otherMouseUp,event:press(3),receivedAt:1.1)
        let records=box.drain();expectEqual(records.count,5)
        if case .buttonContext(3,let flags)=records[0] { expectEqual(flags,[.command,.shift]) }
        else { expectTrue(false,"down modifier context absent") }
    }),
    ("modifier ViewModel saves and conflicts only identical input trigger flags", {
        let model=AppViewModel();model.applyConfig={ c,_ in model.show(c) }
        let row=mapping(.command,.system(.showDesktop))
        if case .saved=model.saveMapping(row) {} else { expectTrue(false,"modified mapping cannot save") }
        if case .existing(let original)=model.saveMapping(mapping(.command,.none)) { expectEqual(original.id,row.id) }
        else { expectTrue(false,"modified duplicate accepted") }
        expectEqual(model.config.button4ClickAction.action,.none)
    })
]
