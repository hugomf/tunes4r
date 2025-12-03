import Cocoa
import FlutterMacOS
import AVFoundation

// Standard 10-band EQ center frequencies (in Hz)
private let centerFrequencies: [Float] = [
    32.0,   // Sub-bass
    64.0,   // Bass
    125.0,  // Low Mids
    250.0,  // Mids
    500.0,  // Upper Mids
    1000.0, // Presence
    2000.0, // Brilliance
    4000.0, // Air
    8000.0, // Brilliance
    16000.0 // Treble
]

@main
class AppDelegate: FlutterAppDelegate {
    private var audioEngine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var equalizer = AVAudioUnitEQ(numberOfBands: 10)
    private var currentBuffer: AVAudioPCMBuffer?
    private var isPlaying = false
    private var nodesConnected = false
    private var equalizerBypass = true  // Start bypassed by default

    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    override func applicationDidFinishLaunching(_ notification: Notification) {
        super.applicationDidFinishLaunching(notification)
        setupMacOSEqualizer()
    }

    private func setupMacOSEqualizer() {
        equalizer.globalGain = 0.0  // Start at 0 to avoid clipping

        for i in 0..<equalizer.bands.count {
            let band = equalizer.bands[i]
            band.filterType = .parametric
            band.frequency = centerFrequencies[i]
            band.bandwidth = 0.5  // CRITICAL: Narrower bandwidth for cleaner sound (was 1.0)
            band.gain = 0.0
            band.bypass = false
            
            print("🎛️ Band \(i): \(band.frequency)Hz, BW: \(band.bandwidth)")
        }

        print("🎛️ macOS AVAudioEngine EQ setup complete")
    }

    func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "playSong":
            handlePlaySong(call, result: result)
        case "pause":
            playerNode.pause()
            isPlaying = false
            result(nil)
        case "resume":
            playerNode.play()
            isPlaying = true
            result(nil)
        case "togglePlayPause":
            togglePlayPause(result: result)
        case "applyEqualizer":
            if let args = call.arguments as? [String: Any],
               let bands = args["bands"] as? [Double] {
                applyEqualizer(bands: bands, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected bands array", details: nil))
            }
        case "resetEqualizer":
            resetEqualizer(result: result)
        case "stop", "endPlayback":
            playerNode.stop()
            isPlaying = false
            result(nil)
        case "testExtremeEQ":
            testExtremeEQ(result: result)
        case "testBassBoost":
            testBassBoost(result: result)
        case "enableEqualizer":
            // CRITICAL FIX: Update tracking variable AND apply to equalizer
            equalizerBypass = false
            equalizer.bypass = false
            equalizer.globalGain = 0.0  // Use 0 instead of 1.0 to avoid clipping/distortion
            
            // CRITICAL: Un-bypass all individual bands
            for band in equalizer.bands {
                band.bypass = false
            }
            
            // Re-trigger gains to ensure they take effect
            for i in 0..<equalizer.bands.count {
                let gain = equalizer.bands[i].gain
                equalizer.bands[i].gain = gain
            }
            
            print("🎛️ macOS equalizer ENABLED - bypass: \(equalizer.bypass), tracking: \(equalizerBypass)")
            result(nil)
            
        case "disableEqualizer":
            // CRITICAL FIX: Update tracking variable AND apply to equalizer
            equalizerBypass = true
            equalizer.bypass = true
            
            // Also bypass individual bands
            for band in equalizer.bands {
                band.bypass = true
            }
            
            print("🎛️ macOS equalizer DISABLED - bypass: \(equalizer.bypass), tracking: \(equalizerBypass)")
            result(nil)
            
        case "debugEQState":
            debugEQState(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handlePlaySong(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let filePath = args["filePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected filePath", details: nil))
            return
        }

        playAudioFile(filePath: filePath, result: result)
    }

    private func playAudioFile(filePath: String, result: @escaping FlutterResult) {
        let url = URL(fileURLWithPath: filePath)
        playerNode.stop()
        playerNode.reset()

        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: url)
        } catch let error as NSError {
            print("🔴 Audio file load failed: \(error.localizedDescription)")
            result(FlutterError(code: "FILE_LOAD_ERROR", message: "Could not load audio file", details: error.localizedDescription))
            return
        }

        let format = audioFile.processingFormat

        do {
            if !nodesConnected {
                print("🎛️ Attaching AVAudioEngine nodes...")
                audioEngine.attach(playerNode)
                audioEngine.attach(equalizer)

                print("🎛️ Initializing AVAudioEngine node connections...")
                try audioEngine.connect(playerNode, to: equalizer, format: format)
                try audioEngine.connect(equalizer, to: audioEngine.mainMixerNode, format: format)
                nodesConnected = true
                print("🎛️ Node connections established")
            }
        } catch let error as NSError {
            print("🔴 AVAudioEngine node connection failed:")
            print("   Error: \(error.localizedDescription)")
            result(FlutterError(code: "EQ_CONNECTION_FAILED", message: "Equalizer setup failed", details: error.localizedDescription))
            return
        }

        playerNode.scheduleFile(audioFile, at: nil) {
            DispatchQueue.main.async {
                print("🎵 macOS playback completed: \(url.lastPathComponent)")
            }
        }

        do {
            if !audioEngine.isRunning {
                try audioEngine.start()
                print("🎵 AVAudioEngine started successfully")
                
                // Force re-application of current EQ settings after engine starts
                // Don't change bypass state - respect whatever was set via enable/disable
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.equalizer.globalGain = 1.0
                    
                    // Force re-application of gains
                    for i in 0..<self.equalizer.bands.count {
                        let gain = self.equalizer.bands[i].gain
                        self.equalizer.bands[i].gain = gain
                    }
                    
                    print("🎛️ EQ gains re-applied after engine start - bypass: \(self.equalizer.bypass)")
                }
            }
            
        } catch let error as NSError {
            print("🔴 AVAudioEngine start failed: \(error.localizedDescription)")
        }

        playerNode.play()
        isPlaying = true
        print("🎵 Playing: \(url.lastPathComponent)")
        result(nil)
    }

    private func togglePlayPause(result: @escaping FlutterResult) {
        if isPlaying {
            playerNode.pause()
            isPlaying = false
        } else {
            playerNode.play()
            isPlaying = true
        }
        result(nil)
    }

    private func applyEqualizer(bands: [Double], result: @escaping FlutterResult) {
        for i in 0..<min(equalizer.bands.count, bands.count) {
            let band = equalizer.bands[i]
            band.gain = Float(bands[i])
            band.bypass = false  // Ensure band is active when setting gain
        }
        
        print("🎛️ Applied equalizer bands: \(bands)")
        result(nil)
    }

    private func resetEqualizer(result: @escaping FlutterResult) {
        for band in equalizer.bands {
            band.gain = 0.0
        }
        print("🎛️ Reset equalizer to flat")
        result(nil)
    }

    private func testExtremeEQ(result: @escaping FlutterResult) {
        equalizer.bands[0].gain = 20.0
        equalizer.bands[1].gain = 15.0
        equalizer.bands[8].gain = -20.0
        equalizer.bands[9].gain = -15.0

        print("🎛️ EXTREME EQ APPLIED - Bass: +20dB, Treble: -20dB")
        result(nil)
    }

    private func testBassBoost(result: @escaping FlutterResult) {
        equalizer.bands[0].gain = 20.0
        equalizer.bands[1].gain = 10.0
        equalizer.bands[2].gain = 5.0
        equalizer.bands[8].gain = -10.0
        equalizer.bands[9].gain = -10.0

        print("🎛️ BASS BOOST TEST - 32Hz: +20dB")
        result(nil)
    }

    deinit {
        audioEngine.stop()
    }
    
    private func debugEQState(result: @escaping FlutterResult) {
        print("🔍 ===== EQ DEBUG STATE =====")
        print("   Equalizer bypass: \(equalizer.bypass)")
        print("   Equalizer globalGain: \(equalizer.globalGain)")
        print("   Tracking bypass: \(equalizerBypass)")
        print("   Engine running: \(audioEngine.isRunning)")
        print("   Player playing: \(playerNode.isPlaying)")
        print("   Nodes connected: \(nodesConnected)")
        print("   Band gains:")
        for (i, band) in equalizer.bands.enumerated() {
            print("      Band \(i) (\(Int(band.frequency))Hz): \(band.gain)dB, bypass: \(band.bypass)")
        }
        print("========================")
        result(nil)
    }
}