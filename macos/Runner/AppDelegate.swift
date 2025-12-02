import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
    private var mediaChannel: FlutterMethodChannel?
    private var globalMonitor: Any?
    private var hasAccessibilityPermission = false

    override func applicationDidFinishLaunching(_ notification: Notification) {
        setupMediaControls()
        setupMethodChannel()
    }

    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    private func setupMediaControls() {
        // First try local monitoring (works when app is focused)
        NSEvent.addLocalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            return self?.handleMediaKey(event: event) ?? event
        }

        // Then try global monitoring (works system-wide, needs accessibility)
        _ = checkAccessibilityPermission()
        setupGlobalMediaMonitoring()

        // Test accessibility every 2 seconds if not granted yet
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.hasAccessibilityPermission else { return }
            _ = self.checkAccessibilityPermission()
            if self.hasAccessibilityPermission {
                // Upgrade to global monitoring now that we have permission
                self.setupGlobalMediaMonitoring()
                print("🎵 Tunes4R: Upgraded to global media key monitoring")
            }
        }
    }

    private func checkAccessibilityPermission() -> Bool {
        // Check if we have accessibility permission
        let checkOptionPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [checkOptionPrompt: false] as CFDictionary
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions(options)
        return hasAccessibilityPermission
    }

    private func requestAccessibilityPermission() {
        // Show detailed alert with exact steps for sandboxed app accessibility
        let alert = NSAlert()
        alert.messageText = "Enable Bluetooth Headphones"
        alert.informativeText = "To use Bluetooth headphone buttons globally with Tunes4R:\n\n1. Click 'Open System Settings' below\n2. Go to Privacy & Security → Accessibility\n3. Click '+' to add an app\n4. Find and select Tunes4R (it may be in ~/Library/Developer/Xcode/DerivedData/...)\n5. Or find it in Applications folder\n6. Enable Tunes4R\n7. Restart Tunes4R\n\nIf Tunes4R doesn't appear, quit Tunes4R, relaunch it, then retry adding it."

        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)

            // Try to trigger accessibility dialog after opening settings
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // This will prompt macOS to ask for accessibility permission
                let checkOptionPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
                let options = [checkOptionPrompt: true] as CFDictionary // Set to true to prompt
                _ = AXIsProcessTrustedWithOptions(options)
                print("🎵 Tunes4R: Triggered accessibility dialog")
            }
        }
    }

    private func setupGlobalMediaMonitoring() {
        // Only set up global monitoring if we have accessibility permission
        guard checkAccessibilityPermission() else {
            print("🎵 Tunes4R: Accessibility permission not granted - media keys will only work when app is focused")
            return
        }

        // Set up global media key monitoring (works when app is not focused)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            self?.handleGlobalMediaKey(event: event)
        }

        print("🎵 Tunes4R: Global media key monitoring active")
    }

    private func handleMediaKey(event: NSEvent) -> NSEvent? {
        return handleMediaKeyLogic(event: event, consumeEvent: true)
    }

    private func handleGlobalMediaKey(event: NSEvent) {
        _ = handleMediaKeyLogic(event: event, consumeEvent: false)
    }

    private func handleMediaKeyLogic(event: NSEvent, consumeEvent: Bool) -> NSEvent? {
        // Check if this is a media key event
        guard event.type == .systemDefined && event.subtype.rawValue == 8 else {
            return consumeEvent ? event : nil
        }

        let keyCode = (event.data1 & 0xFFFF0000) >> 16
        let keyFlags = (event.data1 & 0x0000FFFF)
        let keyState = ((keyFlags & 0xFF00) >> 8) == 0xA

        guard keyState else {
            return consumeEvent ? event : nil
        }

        var action = ""

        switch Int32(keyCode) {
        case NX_KEYTYPE_PLAY:
            action = "playPause"
        case NX_KEYTYPE_NEXT:
            action = "next"
        case NX_KEYTYPE_PREVIOUS:
            action = "previous"
        case NX_KEYTYPE_FAST:
            action = "next"  // Fast forward → next track
        case NX_KEYTYPE_REWIND:
            action = "previous"  // Rewind → previous track
        default:
            return consumeEvent ? event : nil
        }

        if !action.isEmpty {
            sendMediaControlEvent(action)
            print("🎵 Tunes4R: Handled media key - \(action)")
            return consumeEvent ? nil : nil // Consume event for local monitor, don't consume for global
        }

        return consumeEvent ? event : nil
    }

    private func sendMediaControlEvent(_ action: String) {
        // Send event to Flutter via method channel (already set up in setupMethodChannel)
        guard let methodChannel = self.mediaChannel else {
            print("🎵 Tunes4R: Method channel not available for sending events")
            return
        }

        DispatchQueue.main.async {
            methodChannel.invokeMethod("onMediaControl", arguments: action, result: nil)
        }
    }

    private func setupMethodChannel() {
        // Set up method channel for bidirectional communication (Flutter ↔ native)
        guard let flutterViewController = self.mainFlutterWindow?.contentViewController as? FlutterViewController else {
            // Window not ready yet, retry soon
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.setupMethodChannel()
            }
            return
        }

        self.mediaChannel = FlutterMethodChannel(name: "com.example.tunes4r/media_controls", binaryMessenger: flutterViewController.engine.binaryMessenger)

        // Set up method call handler for incoming calls from Flutter
        self.mediaChannel?.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }

            switch call.method {
            case "requestMediaPermissions":
                self.requestAccessibilityPermission()
                result("Permission dialog shown")
            case "checkMediaPermissions":
                let hasPermission = self.checkAccessibilityPermission()
                result(hasPermission)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        print("🎵 Tunes4R: Method channel initialized for media controls")
    }

    // Public method to check and request permissions
    @objc func checkAndRequestMediaPermissions() {
        if !hasAccessibilityPermission {
            requestAccessibilityPermission()
        } else {
            print("🎵 Tunes4R: Accessibility permission already granted")
        }
    }
}
