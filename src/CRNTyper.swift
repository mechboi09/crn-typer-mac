import Cocoa
import Carbon
import ApplicationServices

enum Action: Equatable {
    case text(String), key(CGKeyCode), wait(Int)
}

func sequence(_ values: [String], fast: Bool = false) -> [Action]? {
    guard !values.isEmpty, values.count <= 6,
          Set(values).count == values.count,
          values.allSatisfy({ !$0.isEmpty && $0.count <= 5 && $0.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }) }) else { return nil }
    var result: [Action] = []
    for (index, value) in values.enumerated() {
        result.append(.text(value))
        if index < values.count - 1 {
            result += fast ? [.key(48), .key(36), .wait(1)] : [.key(48), .wait(200)]
        }
    }
    // Both Tabs are posted in the same main-loop turn, before Banner's 200 ms check.
    result += [.key(48), .key(48), .wait(fast ? 1 : 80), .key(36)]
    return result
}

if CommandLine.arguments.contains("--self-test") {
    let expected: [Action] = [.text("90001"), .key(48), .wait(200), .text("90002"), .key(48), .wait(200), .text("90003"), .key(48), .key(48), .wait(80), .key(36)]
    precondition(sequence(["90001", "90002", "90003"]) == expected)
    precondition(sequence(["00123"]) == [.text("00123"), .key(48), .key(48), .wait(80), .key(36)])
    precondition(sequence([]) == nil)
    precondition(sequence(["90001", "90001"]) == nil)
    precondition(sequence(["hello"]) == nil)
    precondition(sequence(["123456"]) == nil)
    precondition(sequence(["1", "2", "3", "4", "5", "6"]) != nil)
    precondition(sequence(["90001", "90002"], fast: true) == [.text("90001"), .key(48), .key(36), .wait(1), .text("90002"), .key(48), .key(48), .wait(1), .key(36)])
    print("PASS: normal and fast modes; CRN sequence, 200 ms pauses, final Tab Tab Enter, leading zeros, and input validation. No keystrokes sent.")
    exit(0)
}

let hotkeySignature: OSType = 0x43524E54 // CRNT

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSTextFieldDelegate {
    var window: NSWindow!
    var fields: [[NSTextField]] = []
    var status = NSTextField(wrappingLabelWithString: "Ready. Focus the first empty CRN box, then press F1–F4.\nEscape cancels. Choose Normal or Fast.")
    var hotkeys: [EventHotKeyRef] = []
    var escapeKey: EventHotKeyRef?
    var eventHandler: EventHandlerRef?
    let functionKeys: [UInt32] = [122, 120, 99, 118]
    var speed = NSPopUpButton()
    var fastMode = false
    var running = false
    var generation = 0
    var target: pid_t = 0
    var plan: [Action] = []
    var position = 0
    var count = 0
    var typed = 0
    var focusObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildUI()
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let result = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event = event, let userData = userData else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let error = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, numericCast(MemoryLayout<EventHotKeyID>.size), nil, &id)
            guard error == noErr, id.signature == hotkeySignature else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            if id.id == 99 { owner.stop("Cancelled. Clear partially entered CRNs before restarting.") }
            else if (1...4).contains(id.id) { owner.start(Int(id.id) - 1) }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        guard result == noErr else { setStatus("Could not register the keyboard handler.", error: true); return }
        var failed: [String] = []
        for i in 0..<4 {
            var ref: EventHotKeyRef?
            let code = RegisterEventHotKey(functionKeys[i], 0, EventHotKeyID(signature: hotkeySignature, id: UInt32(i + 1)), GetApplicationEventTarget(), 0, &ref)
            if code == noErr, let ref = ref { hotkeys.append(ref) } else { failed.append("F\(i+1)") }
        }
        if !failed.isEmpty { setStatus("Unavailable: \(failed.joined(separator: ", ")). Check macOS keyboard shortcuts, then restart.", error: true) }
        focusObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self, self.running else { return }
            if NSWorkspace.shared.frontmostApplication?.processIdentifier != self.target {
                self.stop("Stopped: active application changed. Clear the form before restarting.")
            }
        }
    }

    var tabs = NSTabView()
    var names: [NSTextField] = []
    var rowViews: [[NSView]] = []
    var visibleRows = [3,3,3,3]
    var editorControls: [NSControl] = []
    var loading = true
    var saveWork: DispatchWorkItem?
    struct Saved: Codable { var values: [[String]]; var names: [String]; var visible: [Int]; var speed: Int }
    var settingsURL: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("CRNTyper-AUB/settings.json") }
    func save() {
        guard !loading else { return }
        saveWork?.cancel()
        do {
            let saved = Saved(values: fields.map { $0.map { $0.stringValue } }, names: names.map { $0.stringValue }, visible: visibleRows, speed: speed.indexOfSelectedItem)
            try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(saved).write(to: settingsURL, options: .atomic)
        } catch { setStatus("Could not save settings: \(error.localizedDescription)", error: true) }
    }
    func controlTextDidChange(_ notification: Notification) {
        for i in 0..<names.count { tabs.tabViewItem(at: i).label = (names[i].stringValue.isEmpty ? "Option \(i+1)" : names[i].stringValue) + " (F\(i+1))" }
        guard !loading else { return }
        saveWork?.cancel(); let work = DispatchWorkItem { [weak self] in self?.save() }; saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(400), execute: work)
    }
    func updateRows(_ option: Int) { for i in 0..<6 { rowViews[option][i].isHidden = i >= visibleRows[option] } }
    @objc func addCRN(_ sender: NSButton) {
        guard !running else { return }; let option = sender.tag
        guard visibleRows[option] < 6 else { setStatus("Maximum six CRNs per option."); return }
        visibleRows[option] += 1; updateRows(option); save(); window.makeFirstResponder(fields[option][visibleRows[option]-1])
    }
    @objc func removeCRN(_ sender: NSButton) {
        guard !running else { return }; let option = sender.tag / 10, index = sender.tag % 10
        guard visibleRows[option] > 1 else { return }
        for i in index..<5 { fields[option][i].stringValue = fields[option][i+1].stringValue }
        fields[option][5].stringValue = ""; visibleRows[option] -= 1; updateRows(option); save()
    }
    @objc func pasteList(_ sender: NSButton) {
        guard !running else { return }; let option = sender.tag
        let alert = NSAlert(); alert.messageText = "Paste CRN list"; alert.informativeText = "Up to six unique CRNs, separated by spaces, commas or new lines. This replaces the current option."; alert.addButton(withTitle: "Use this list"); alert.addButton(withTitle: "Cancel")
        let scroll = NSScrollView(frame: NSRect(x: 0,y: 0,width: 340,height: 140)); scroll.hasVerticalScroller = true
        let input = NSTextView(frame: scroll.bounds); input.isRichText = false; scroll.documentView = input; alert.accessoryView = scroll
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let values = input.string.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ","))).filter { !$0.isEmpty }
        guard values.isEmpty || sequence(values) != nil else { setStatus("Use up to six unique CRNs, 1–5 digits each.", error: true); return }
        for i in 0..<6 { fields[option][i].stringValue = i < values.count ? values[i] : "" }
        visibleRows[option] = max(3, values.count); updateRows(option); save(); setStatus("Ready. List saved locally.")
    }
    func buildUI() {
        let menu = NSMenu(), item = NSMenuItem(); menu.addItem(item); let appMenu = NSMenu(); appMenu.addItem(withTitle: "Quit CRN Typer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); item.submenu = appMenu; NSApp.mainMenu = menu
        window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 470,height: 500), styleMask: [.titled,.closable,.miniaturizable], backing: .buffered, defer: false)
        window.title = "CRN Typer - AUB"; window.center(); window.delegate = self
        let content = window.contentView!
        tabs.frame = NSRect(x: 12,y: 125,width: 446,height: 360); content.addSubview(tabs)
        for option in 0..<4 {
            let item = NSTabViewItem(identifier: option); item.label = "Option \(option+1) (F\(option+1))"; let page = NSView(frame: NSRect(x: 0,y: 0,width: 420,height: 325)); item.view = page; tabs.addTabViewItem(item)
            let name = NSTextField(frame: NSRect(x: 16,y: 284,width: 260,height: 26)); name.stringValue = "Option \(option+1)"; name.delegate = self; name.setAccessibilityLabel("Name of option \(option+1)"); page.addSubview(name); names.append(name); editorControls.append(name)
            let paste = NSButton(title: "Paste list", target: self, action: #selector(pasteList(_:))); paste.tag = option; paste.frame = NSRect(x: 290,y: 282,width: 110,height: 30); page.addSubview(paste); editorControls.append(paste)
            var column: [NSTextField] = [], rows: [NSView] = []
            for row in 0..<6 {
                let panel = NSView(frame: NSRect(x: 16,y: CGFloat(244-row*34),width: 390,height: 30)); page.addSubview(panel); rows.append(panel)
                let label = NSTextField(labelWithString: "CRN \(row+1)"); label.frame = NSRect(x: 0,y: 5,width: 58,height: 20); panel.addSubview(label)
                let field = NSTextField(frame: NSRect(x: 65,y: 3,width: 225,height: 25)); field.delegate = self; field.setAccessibilityLabel("Option \(option+1), CRN \(row+1)"); panel.addSubview(field); column.append(field)
                let remove = NSButton(title: "Remove", target: self, action: #selector(removeCRN(_:))); remove.tag = option*10+row; remove.frame = NSRect(x: 300,y: 1,width: 85,height: 28); panel.addSubview(remove); editorControls.append(remove)
            }
            fields.append(column); rowViews.append(rows); updateRows(option)
            let add = NSButton(title: "+ Add CRN", target: self, action: #selector(addCRN(_:))); add.tag = option; add.frame = NSRect(x: 16,y: 18,width: 125,height: 30); page.addSubview(add); editorControls.append(add)
        }
        speed.frame = NSRect(x: 16,y: 84,width: 438,height: 28); speed.addItems(withTitles: ["Normal (200 ms)","Fast (1 ms requested)"]); speed.target = self; speed.action = #selector(speedChanged(_:)); content.addSubview(speed)
        status.frame = NSRect(x: 16,y: 12,width: 438,height: 62); status.font = .systemFont(ofSize: 12); content.addSubview(status)
        if FileManager.default.fileExists(atPath: settingsURL.path) {
            do { let saved = try JSONDecoder().decode(Saved.self, from: Data(contentsOf: settingsURL)); guard saved.values.count == 4 && saved.names.count == 4 && saved.visible.count == 4 else { throw NSError(domain: "Settings",code: 1) }
                for c in 0..<4 { names[c].stringValue = saved.names[c]; for r in 0..<6 { fields[c][r].stringValue = r < saved.values[c].count ? saved.values[c][r] : "" }; let occupied = (fields[c].lastIndex { !$0.stringValue.isEmpty }).map { $0+1 } ?? 0; visibleRows[c] = max(max(1,min(6,saved.visible[c])),occupied); updateRows(c); tabs.tabViewItem(at: c).label = names[c].stringValue + " (F\(c+1))" }; speed.selectItem(at: max(0,min(1,saved.speed)))
            } catch { setStatus("Settings could not be loaded: \(error.localizedDescription)", error: true) }
        }
        loading = false; window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }

    @objc func speedChanged(_ sender: NSPopUpButton) {
        save()
        setStatus(sender.indexOfSelectedItem == 1 ? "fast is guaranteed dean’s warning 😈 (just kidding)" : "Normal mode — automatic, 200 ms.")
    }
    func setStatus(_ text: String, error: Bool = false) { status.stringValue = text; status.textColor = error ? .systemRed : .labelColor }
    func stop(_ text: String) {
        guard running else { return }
        running = false; generation += 1; speed.isEnabled = true; editorControls.forEach { .isEnabled = true }
        if let ref = escapeKey { UnregisterEventHotKey(ref); escapeKey = nil }
        for field in fields.flatMap({ $0 }) { field.isEnabled = true }
        setStatus(text, error: true)
    }
    func validTarget() -> Bool {
        guard running else { return false }
        if NSWorkspace.shared.frontmostApplication?.processIdentifier != target {
            stop("Stopped: active application changed. Clear the form before restarting."); return false
        }
        if CGEventSource.keyState(.combinedSessionState, key: 53) { stop("Cancelled. Clear partially entered CRNs before restarting."); return false }
        let modifiers = CGEventSource.flagsState(.combinedSessionState)
        if !modifiers.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]).isEmpty {
            stop("Stopped: release Command, Control, Option and Shift before starting."); return false
        }
        return true
    }
    func start(_ option: Int) {
        guard !running else { return }
        guard let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            setStatus("Click the first CRN box in your browser, then press F\(option+1).", error: true); return
        }
        guard AXIsProcessTrusted() else {
            setStatus("Allow CRN Typer in System Settings → Privacy & Security → Accessibility, then reopen it.", error: true)
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options); return
        }
        let values = fields[option].map { $0.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        fastMode = speed.indexOfSelectedItem == 1
        guard let steps = sequence(values, fast: fastMode) else { setStatus("Option \(option+1): enter 1–6 unique CRNs, each 1–5 digits.", error: true); return }
        guard RegisterEventHotKey(53, 0, EventHotKeyID(signature: hotkeySignature, id: 99), GetApplicationEventTarget(), 0, &escapeKey) == noErr else {
            setStatus("Cannot reserve Escape for cancellation. Close other hotkey apps and retry.", error: true); return
        }
        target = front.processIdentifier; plan = steps; position = 0; count = values.count; typed = 0
        running = true; generation += 1; speed.isEnabled = false; editorControls.forEach { .isEnabled = false }
        for field in fields.flatMap({ $0 }) { field.isEnabled = false }
        setStatus("Option \(option+1) running — Escape cancels.")
        awaitRelease(CGKeyCode(functionKeys[option]), attempts: 0, run: generation)
    }
    func awaitRelease(_ key: CGKeyCode, attempts: Int, run: Int) {
        guard run == generation, validTarget() else { return }
        if CGEventSource.keyState(.combinedSessionState, key: key) {
            guard attempts < 120 else { stop("Stopped: release the function key after pressing it."); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(25)) { self.awaitRelease(key, attempts: attempts + 1, run: run) }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(fastMode ? 1 : 60)) { self.advance(run) }
        }
    }
    func postKey(_ key: CGKeyCode, text: String? = nil) -> Bool {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: false) else { return false }
        down.flags = []; up.flags = []
        if let text = text {
            let utf16 = Array(text.utf16)
            utf16.withUnsafeBufferPointer { chars in
                down.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: chars.baseAddress)
                up.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: chars.baseAddress)
            }
        }
        down.post(tap: .cghidEventTap); up.post(tap: .cghidEventTap); return true
    }
    func advance(_ run: Int) {
        guard run == generation, validTarget() else { return }
        while position < plan.count {
            guard validTarget() else { return }
            let action = plan[position]; position += 1
            switch action {
            case .text(let text):
                typed += 1; setStatus("Typing CRN \(typed) of \(count). Escape cancels.")
                // Individual Unicode digits preserve leading zeros without using the clipboard.
                for digit in text { if !postKey(0, text: String(digit)) { stop("Could not create a keyboard event."); return } }
            case .key(let key):
                if !postKey(key) { stop("Could not create a keyboard event."); return }
            case .wait(let milliseconds):
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(milliseconds)) { self.advance(run) }; return
            }
        }
        running = false; speed.isEnabled = true; editorControls.forEach { .isEnabled = true }
        if let ref = escapeKey { UnregisterEventHotKey(ref); escapeKey = nil }
        for field in fields.flatMap({ $0 }) { field.isEnabled = true }
        setStatus("Done — \(count) CRN(s) sent; Keys sent to Add to Summary.\nReview the browser's result.")
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) {
        save()
        running = false; generation += 1
        for ref in hotkeys { UnregisterEventHotKey(ref) }
        if let ref = escapeKey { UnregisterEventHotKey(ref) }
        if let handler = eventHandler { RemoveEventHandler(handler) }
        if let observer = focusObserver { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()