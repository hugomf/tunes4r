import Flutter
import UIKit
import MediaPlayer

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var mediaChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Set up media controls
        setupMediaControls()

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func setupMediaControls() {
        // Set up remote command center for Bluetooth/media controls
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play command
        commandCenter.playCommand.addTarget { [weak self] event in
            self?.sendMediaControlEvent("play")
            return .success
        }

        commandCenter.playCommand.isEnabled = true

        // Pause command
        commandCenter.pauseCommand.addTarget { [weak self] event in
            self?.sendMediaControlEvent("pause")
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true

        // Toggle play/pause command
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] event in
            self?.sendMediaControlEvent("playPause")
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true

        // Next track command
        commandCenter.nextTrackCommand.addTarget { [weak self] event in
            self?.sendMediaControlEvent("next")
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true

        // Previous track command
        commandCenter.previousTrackCommand.addTarget { [weak self] event in
            self?.sendMediaControlEvent("previous")
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true

        // Initialize now playing info
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = "Tunes4R"
        nowPlayingInfo[MPMediaItemPropertyArtist] = "Ready to play"
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = 0
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Handle push notifications if needed
    }

    private func sendMediaControlEvent(_ action: String) {
        // This will be called when media controls are received
        // The Flutter side will handle the actual media actions via method channel
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let flutterViewController = windowScene.windows.first?.rootViewController as? FlutterViewController {

            if self.mediaChannel == nil {
                self.mediaChannel = FlutterMethodChannel(name: "com.example.tunes4r/media_controls", binaryMessenger: flutterViewController.binaryMessenger)
            }

            guard let methodChannel = self.mediaChannel else {
                return
            }

            DispatchQueue.main.async {
                methodChannel.invokeMethod("onMediaControl", arguments: action, result: nil)
            }
        }
    }

    // Public method that Flutter can call to update now playing info
    @objc public func updateNowPlayingInfo(title: String, artist: String, album: String, duration: Double, elapsedTime: Double, isPlaying: Bool) {
        var nowPlayingInfo = [String: Any]()

        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsedTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

        // Update playback state
        let playbackState = isPlaying ? MPNowPlayingPlaybackState.playing : MPNowPlayingPlaybackState.paused
        MPNowPlayingInfoCenter.default().playbackState = playbackState
    }
}
