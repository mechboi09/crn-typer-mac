import Cocoa
import Carbon
import ApplicationServices

final class ModeToggle: NSControl {
    var fast = true { didSet { needsDisplay = true; setAccessibilityValue(fast) } }
    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }
    override func mouseDown(with event: NSEvent) { guard isEnabled else { return }; window?.makeFirstResponder(self); fast.toggle(); _ = sendAction(action, to: target) }
    override func keyDown(with event: NSEvent) { guard isEnabled else { return }; if event.keyCode == 49 { fast.toggle() } else if event.keyCode == 123 { fast = false } else if event.keyCode == 124 { fast = true } else { super.keyDown(with: event); return }; _ = sendAction(action, to: target) }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let normal: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11, weight: fast ? .regular : .semibold), .foregroundColor: fast ? NSColor.gray : NSColor.black]
        let quick: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11, weight: fast ? .semibold : .regular), .foregroundColor: fast ? NSColor.black : NSColor.gray]
        ("Normal" as NSString).draw(at: NSPoint(x: 0,y: 6),withAttributes: normal); ("Fast" as NSString).draw(at: NSPoint(x: 91,y: 6),withAttributes: quick)
        NSColor.black.setFill(); NSBezierPath(roundedRect: NSRect(x: 52,y: 9,width: 34,height: 10),xRadius: 5,yRadius: 5).fill()
        let knob = NSBezierPath(ovalIn: NSRect(x: fast ? 73 : 51,y: 7,width: 14,height: 14)); NSColor.white.setFill(); knob.fill(); NSColor.black.setStroke(); knob.lineWidth = 1; knob.stroke()
        if window?.firstResponder === self { NSColor.keyboardFocusIndicatorColor.setStroke(); let ring = NSBezierPath(roundedRect: bounds.insetBy(dx: 1,dy: 1),xRadius: 4,yRadius: 4); ring.stroke() }
    }
}
final class CrnField: NSTextField {
    var pasteValues: ((String) -> Void)?
    var selectAllValues: (() -> Void)?
    var clearSelection: (() -> Void)?
    var copyColumn: (() -> Bool)?
    var cutColumn: (() -> Bool)?
    var deleteColumn: (() -> Bool)?
    var insertColumn: ((String) -> Bool)?
    override func mouseDown(with event: NSEvent) { clearSelection?(); super.mouseDown(with: event) }
}
final class CrnEditor: NSTextView {
    weak var ownerField: CrnField?
    override func paste(_ sender: Any?) { ownerField?.pasteValues?(NSPasteboard.general.string(forType: .string) ?? "") }
    override func copy(_ sender: Any?) { if ownerField?.copyColumn?() != true { super.copy(sender) } }
    override func cut(_ sender: Any?) { if ownerField?.cutColumn?() != true { super.cut(sender) } }
    override func deleteBackward(_ sender: Any?) { if ownerField?.deleteColumn?() != true { super.deleteBackward(sender) } }
    override func deleteForward(_ sender: Any?) { if ownerField?.deleteColumn?() != true { super.deleteForward(sender) } }
    override func selectAll(_ sender: Any?) { ownerField?.selectAllValues?() }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "a" { if !event.isARepeat { selectAll(nil) }; return true }; return super.performKeyEquivalent(with: event)
    }
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) && event.charactersIgnoringModifiers?.lowercased() == "a" { if !event.isARepeat { selectAll(nil) }; return }
        if [48,53,123,124,125,126].contains(Int(event.keyCode)) { ownerField?.clearSelection?() }; super.keyDown(with: event)
    }
    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        let text = (insertString as? String) ?? (insertString as? NSAttributedString)?.string ?? ""
        guard text.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }) else { return }
        if ownerField?.insertColumn?(text) == true { return }
        let range = replacementRange.location == NSNotFound ? selectedRange() : replacementRange
        guard string.utf16.count - range.length + text.utf16.count <= 5 else { return }
        super.insertText(insertString,replacementRange: replacementRange)
    }
}

enum Action: Equatable {
    case text(String), key(CGKeyCode), wait(Int)
}

func sequence(_ values: [String], fast: Bool = false) -> [Action]? {
    guard !values.isEmpty, values.count <= 7,
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
    precondition(sequence(["1", "2", "3", "4", "5", "6", "7"]) != nil)
    precondition(sequence(["1", "2", "3", "4", "5", "6", "7", "8"]) == nil)
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
    var speed = ModeToggle()
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

    var editorControls: [NSControl] = []
    let crnEditor = CrnEditor(frame: .zero)
    var selectedColumn: Int?
    weak var lastSelectField: NSTextField?
    var lastSelectTime: TimeInterval = 0
    func windowWillReturnFieldEditor(_ sender: NSWindow, to client: Any?) -> Any? {
        guard let field = client as? CrnField else { return nil }; crnEditor.isFieldEditor = true; crnEditor.ownerField = field; return crnEditor
    }
    func clearColumnSelection() {
        if let option = selectedColumn { for field in fields[option] { field.attributedStringValue = NSAttributedString(string: field.stringValue,attributes: [.font: NSFont.systemFont(ofSize: 12),.foregroundColor: NSColor.labelColor]) } }; selectedColumn = nil
    }
    func clearColumn(_ option: Int) {
        window.makeFirstResponder(nil); clearColumnSelection(); fields[option].forEach { $0.stringValue = "" }; window.makeFirstResponder(fields[option][0]); fields[option][0].currentEditor()?.selectedRange = NSRange(location: 0,length: 0)
    }
    func selectColumn(_ option: Int, field: NSTextField) {
        let now = ProcessInfo.processInfo.systemUptime
        let twice = lastSelectField === field && now-lastSelectTime <= 0.7
        clearColumnSelection()
        if twice {
            selectedColumn = option; lastSelectField = nil
            for item in fields[option] { item.attributedStringValue = NSAttributedString(string: item.stringValue,attributes: [.font: NSFont.systemFont(ofSize: 12),.foregroundColor: NSColor.selectedTextColor,.backgroundColor: NSColor.selectedTextBackgroundColor]) }
        } else { lastSelectField = field; lastSelectTime = now }
        field.currentEditor()?.selectedRange = NSRange(location: 0,length: field.stringValue.utf16.count)
    }
    func copyColumn(_ option: Int, cut: Bool) -> Bool {
        guard selectedColumn == option else { return false }; let text = fields[option].map { $0.stringValue }.joined(separator: "\n"); NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text,forType: .string); if cut { clearColumn(option) }; return true
    }
    func directPaste(_ text: String, option: Int, index: Int) {
        guard !running else { return }; let start = selectedColumn == option ? 0 : index
        let values = text.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ","))).filter { !$0.isEmpty }
        guard values.count <= 7-start && (values.isEmpty || sequence(values) != nil) else { setStatus("Paste up to \(7-start) unique CRNs, each 1–5 digits.",error: true); return }
        window.makeFirstResponder(nil); clearColumnSelection(); for i in start..<7 { fields[option][i].stringValue = i-start < values.count ? values[i-start] : "" }; window.makeFirstResponder(fields[option][start])
    }
    @objc func showTips(_ sender: NSButton) {
        let alert = NSAlert(); alert.messageText = "Tips"; alert.informativeText = "- Use Normal mode (200 ms) to enter all your CRNs in one option, especially when the courses aren’t in high demand.\n- For high-demand courses, use Fast mode (1ms) and organize your CRNs across two or three options, placing your highest priority courses in Option 1."; alert.addButton(withTitle: "OK"); alert.runModal()
    }
    func buildUI() {
        let menu = NSMenu(), item = NSMenuItem(); menu.addItem(item); let appMenu = NSMenu(); appMenu.addItem(withTitle: "Quit CRN typer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); item.submenu = appMenu; NSApp.mainMenu = menu
        let editItem = NSMenuItem(); menu.addItem(editItem); let edit = NSMenu(title: "Edit"); editItem.submenu = edit
        edit.addItem(withTitle: "Copy",action: #selector(NSText.copy(_:)),keyEquivalent: "c"); edit.addItem(withTitle: "Cut",action: #selector(NSText.cut(_:)),keyEquivalent: "x"); edit.addItem(withTitle: "Paste",action: #selector(NSText.paste(_:)),keyEquivalent: "v"); edit.addItem(withTitle: "Select All",action: #selector(NSText.selectAll(_:)),keyEquivalent: "a")
        window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 306,height: 294),styleMask: [.titled,.closable,.miniaturizable],backing: .buffered,defer: false); window.title = "CRN typer"; window.center(); window.delegate = self
        let content = window.contentView!
        for option in 0..<4 {
            let group = NSBox(frame: NSRect(x: CGFloat(6+option*75),y: 87,width: 73,height: 201)); group.title = "Option \(option+1)"; group.titleFont = .systemFont(ofSize: 11); content.addSubview(group)
            var column: [NSTextField] = []
            for row in 0..<7 {
                let field = CrnField(frame: NSRect(x: 4,y: CGFloat(153-row*24),width: 61,height: 23)); field.font = .systemFont(ofSize: 12); field.setAccessibilityLabel("Option \(option+1), CRN \(row+1)")
                field.pasteValues = { [weak self] text in self?.directPaste(text,option: option,index: row) }
                field.selectAllValues = { [weak self,weak field] in if let field = field { self?.selectColumn(option,field: field) } }
                field.clearSelection = { [weak self] in self?.clearColumnSelection(); self?.lastSelectField = nil }
                field.copyColumn = { [weak self] in self?.copyColumn(option,cut: false) ?? false }; field.cutColumn = { [weak self] in self?.copyColumn(option,cut: true) ?? false }
                field.deleteColumn = { [weak self] in guard let self = self, self.selectedColumn == option else { return false }; self.clearColumn(option); return true }
                field.insertColumn = { [weak self] text in guard let self = self, self.selectedColumn == option else { return false }; self.clearColumn(option); self.fields[option][0].stringValue = String(text.prefix(5)); self.fields[option][0].currentEditor()?.selectedRange = NSRange(location: self.fields[option][0].stringValue.count,length: 0); return true }
                group.contentView!.addSubview(field); column.append(field)
            }; fields.append(column)
        }
        speed.frame = NSRect(x: 8,y: 51,width: 125,height: 28); speed.setAccessibilityRole(.checkBox); speed.setAccessibilityLabel("Fast mode"); speed.fast = true; content.addSubview(speed)
        let tips = NSButton(title: "Tips",target: self,action: #selector(showTips(_:))); tips.frame = NSRect(x: 249,y: 51,width: 49,height: 28); content.addSubview(tips); editorControls.append(tips)
        status.frame = NSRect(x: 9,y: 7,width: 288,height: 40); status.font = .systemFont(ofSize: 11); status.stringValue = "Ready. Focus the first CRN box, then F1–F4. Escape cancels."; content.addSubview(status)
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }

    func setStatus(_ text: String, error: Bool = false) { status.stringValue = text; status.textColor = error ? .systemRed : .labelColor }
    func stop(_ text: String) {
        guard running else { return }
        running = false; generation += 1; speed.isEnabled = true; editorControls.forEach { $0.isEnabled = true }
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
        fastMode = speed.fast
        guard let steps = sequence(values, fast: fastMode) else { setStatus("Option \(option+1): enter 1–7 unique CRNs, each 1–5 digits.", error: true); return }
        guard RegisterEventHotKey(53, 0, EventHotKeyID(signature: hotkeySignature, id: 99), GetApplicationEventTarget(), 0, &escapeKey) == noErr else {
            setStatus("Cannot reserve Escape for cancellation. Close other hotkey apps and retry.", error: true); return
        }
        clearColumnSelection(); target = front.processIdentifier; plan = steps; position = 0; count = values.count; typed = 0
        running = true; generation += 1; speed.isEnabled = false; editorControls.forEach { $0.isEnabled = false }
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
        running = false; speed.isEnabled = true; editorControls.forEach { $0.isEnabled = true }
        if let ref = escapeKey { UnregisterEventHotKey(ref); escapeKey = nil }
        for field in fields.flatMap({ $0 }) { field.isEnabled = true }
        setStatus("Done — \(count) CRN(s) sent; Keys sent to Add to Summary.\nReview the browser's result.")
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) {

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