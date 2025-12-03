import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // CRITICAL FIX: Set up method channel IMMEDIATELY, not with delay
    setupMethodChannel(for: flutterViewController)

    super.awakeFromNib()
  }

  private func setupMethodChannel(for controller: FlutterViewController) {
    let audioChannel = FlutterMethodChannel(
      name: "com.example.tunes4r/audio",
      binaryMessenger: controller.engine.binaryMessenger
    )

    // Get the AppDelegate
    guard let appDelegate = NSApp.delegate as? AppDelegate else {
      print("🔴 ERROR: Could not get AppDelegate")
      return
    }

    // Set up the method call handler
    audioChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      print("🔵 Method channel received: \(call.method)")
      appDelegate.handleMethodCall(call, result: result)
    }
    
    print("✅ Method channel setup complete: com.example.tunes4r/audio")
  }
}