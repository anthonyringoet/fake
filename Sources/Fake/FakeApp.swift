import AppKit
import FakeCore
import SwiftUI

@main
struct FakeApp {
    @MainActor static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(CommandLine.arguments.contains("--preview") ? .regular : .accessory)
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let model = GeneratorModel()
    private var previewWindow: NSWindow?
    private var keyboardMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--dark") {
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
        if CommandLine.arguments.contains("--customized") {
            model.showsOptions = true
            model.randomBirthday = false
            model.sexChoice = .female
            model.customBirthday = BirthDate(year: 2000, month: 2, day: 29)!.date
            model.generateRegistry()
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "fake"
            button.font = .menuBarFont(ofSize: 0)
            button.toolTip = "Fake — Belgian test values"
            button.setAccessibilityLabel("fake")
            button.target = self
            button.action = #selector(togglePopover)
        }
        let host = NSHostingController(rootView: PopoverView(model: model))
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
        popover.contentSize = host.view.fittingSize
        popover.behavior = .transient
        popover.animates = !CommandLine.arguments.contains("--smoke-test")
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let handled = MainActor.assumeIsolated {
                guard let self else { return false }
                return self.handleKeyDown(event) == nil
            }
            return handled ? nil : event
        }
        if CommandLine.arguments.contains("--smoke-test") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                Task { await self.runSmokeTest() }
            }
        } else if let index = CommandLine.arguments.firstIndex(of: "--render-preview"),
                  CommandLine.arguments.indices.contains(index + 1) {
            // Render this app's own view into a QA artifact; no desktop capture is involved.
            let view = host.view
            view.frame = NSRect(origin: .zero, size: view.fittingSize)
            view.layoutSubtreeIfNeeded()
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            do {
                try bitmap.representation(using: .png, properties: [:])!.write(
                    to: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
                print("Rendered preview: \(view.bounds.size)")
                NSApp.terminate(nil)
            } catch { print("Render failed: \(error)"); exit(1) }
        } else if CommandLine.arguments.contains("--preview") {
            // A stable window for visual QA tools that dismiss transient popovers on activation.
            let previewHost = NSHostingController(rootView: PopoverView(model: model))
            previewHost.sizingOptions = [.preferredContentSize]
            let window = NSWindow(contentViewController: previewHost)
            window.title = "Fake — Preview"
            window.styleMask = [.titled, .closable]
            window.setContentSize(previewHost.view.fittingSize)
            window.center()
            window.makeKeyAndOrderFront(nil)
            previewWindow = window
            NSApp.activate(ignoringOtherApps: true)
        } else if CommandLine.arguments.contains("--show") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.togglePopover() }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !popover.isShown { togglePopover() }
        return false
    }

    @objc func togglePopover() {
        if popover.isShown { popover.performClose(nil) }
        else if let button = statusItem.button {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard popover.isShown || previewWindow?.isVisible == true else { return event }
        if event.keyCode == 53 {
            popover.performClose(nil)
            return nil
        }
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard modifiers == [.command] || modifiers == [.command, .shift] else { return event }
        let shift = modifiers.contains(.shift)
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "1": shift ? model.generateAndCopy(.registry) : model.generateRegistry()
        case "2": shift ? model.generateAndCopy(.iban) : model.generateIBAN()
        case "c": model.copy(shift ? .iban : .registry)
        case "r" where !shift: model.generateBoth()
        case "q" where !shift: NSApp.terminate(nil)
        default: return event
        }
        return nil
    }

    private func runSmokeTest() async {
        do {
            togglePopover()
            print("Popover size: \(popover.contentSize), anchor: \(String(describing: statusItem.button?.window?.frame)), shown: \(popover.isShown)")
            guard popover.isShown, statusItem.button != nil else {
                throw SmokeTestFailure.failed("Menu bar item and popover")
            }
            try AppSmokeTests.run()
            let collapsedSize = popover.contentSize
            model.showsOptions = true
            model.randomBirthday = false
            try await Task.sleep(for: .milliseconds(150))
            guard popover.contentSize.height > collapsedSize.height,
                  popover.contentSize.width == collapsedSize.width else {
                throw SmokeTestFailure.failed("Popover expands for custom controls")
            }
            model.showsOptions = false
            try await Task.sleep(for: .milliseconds(150))
            guard popover.contentSize == collapsedSize else {
                throw SmokeTestFailure.failed("Popover shrinks after custom controls close")
            }
            func key(_ character: String, code: UInt16 = 0,
                     modifiers: NSEvent.ModifierFlags = .command) -> NSEvent {
                NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
                                 timestamp: 0, windowNumber: 0, context: nil, characters: character,
                                 charactersIgnoringModifiers: character, isARepeat: false, keyCode: code)!
            }
            let beforeRegistry = model.registry
            let beforeIBAN = model.iban
            guard handleKeyDown(key("1")) == nil, model.registry != beforeRegistry, model.iban == beforeIBAN,
                  handleKeyDown(key("2")) == nil, model.iban != beforeIBAN else {
                throw SmokeTestFailure.failed("Keyboard generation shortcuts")
            }
            let beforeBoth = (model.registry, model.iban)
            guard handleKeyDown(key("r")) == nil, model.registry != beforeBoth.0, model.iban != beforeBoth.1,
                  handleKeyDown(key("x")) != nil else {
                throw SmokeTestFailure.failed("New both and unhandled keys")
            }
            _ = handleKeyDown(key("", code: 53, modifiers: []))
            guard !popover.isShown else { throw SmokeTestFailure.failed("Popover closes") }
            print("PASS: menu bar item, popover open/close/resize, date/sex options, generate, clipboard formats, keyboard handling")
            NSApp.terminate(nil)
        } catch {
            fputs("FAIL: \(error)\n", stderr)
            exit(1)
        }
    }
}
