package io.flutter.plugins;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.media.AudioManager;
import android.media.session.MediaSession;
import android.media.session.PlaybackState;
import android.os.Bundle;
import android.view.KeyEvent;

import androidx.media.session.MediaButtonReceiver;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.EventChannel;

public class MainActivity extends FlutterActivity {
    private static final String TAG = "MainActivity";
    private static final String MEDIA_CONTROL_CHANNEL = "com.example.tunes4r/media_controls";
    private static final String MEDIA_SESSION_TAG = "Tunes4RSession";
    private static final String MEDIA_BROADCAST_ACTION = "com.example.tunes4r.MEDIA_CONTROL";

    private MediaSession mediaSession;
    private MethodChannel methodChannel;
    private BroadcastReceiver mediaButtonReceiver;
    private BroadcastReceiver serviceBroadcastReceiver;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Initialize MediaSession for Android Auto and Bluetooth controls
        initializeMediaSession();

        // Register for media button events
        registerMediaButtonReceiver();

        // Register for broadcasts from MediaPlaybackService
        registerServiceBroadcastReceiver();
    }

    private void initializeMediaSession() {
        mediaSession = new MediaSession(this, MEDIA_SESSION_TAG);

        // Set flags to receive media buttons and transport controls
        mediaSession.setFlags(MediaSession.FLAG_HANDLES_MEDIA_BUTTONS |
                            MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS);

        // Set up playback state
        PlaybackState.Builder playbackStateBuilder = new PlaybackState.Builder()
                .setActions(PlaybackState.ACTION_PLAY |
                           PlaybackState.ACTION_PAUSE |
                           PlaybackState.ACTION_PLAY_PAUSE |
                           PlaybackState.ACTION_SKIP_TO_NEXT |
                           PlaybackState.ACTION_SKIP_TO_PREVIOUS |
                           PlaybackState.ACTION_STOP);

        mediaSession.setPlaybackState(playbackStateBuilder.build());
        mediaSession.setActive(true);

        // Set callback to handle media controls
        mediaSession.setCallback(new MediaSession.Callback() {
            @Override
            public void onPlay() {
                super.onPlay();
                sendMediaControlEvent("play");
            }

            @Override
            public void onPause() {
                super.onPause();
                sendMediaControlEvent("pause");
            }

            @Override
            public void onSkipToNext() {
                super.onSkipToNext();
                sendMediaControlEvent("next");
            }

            @Override
            public void onSkipToPrevious() {
                super.onSkipToPrevious();
                sendMediaControlEvent("previous");
            }

            @Override
            public void onStop() {
                super.onStop();
                sendMediaControlEvent("stop");
            }

            @Override
            public boolean onMediaButtonEvent(Intent mediaButtonEvent) {
                return super.onMediaButtonEvent(mediaButtonEvent);
            }
        });
    }

    private void registerMediaButtonReceiver() {
        mediaButtonReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                if (Intent.ACTION_MEDIA_BUTTON.equals(intent.getAction())) {
                    KeyEvent keyEvent = intent.getParcelableExtra(Intent.EXTRA_KEY_EVENT);
                    if (keyEvent != null && keyEvent.getAction() == KeyEvent.ACTION_DOWN) {
                        handleMediaButton(keyEvent.getKeyCode());
                    }
                }
            }
        };

        IntentFilter filter = new IntentFilter(Intent.ACTION_MEDIA_BUTTON);
        registerReceiver(mediaButtonReceiver, filter);
    }

    private void registerServiceBroadcastReceiver() {
        serviceBroadcastReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                if (MEDIA_BROADCAST_ACTION.equals(intent.getAction())) {
                    String action = intent.getStringExtra("action");
                    if (action != null) {
                        sendMediaControlEvent(action);
                    }
                }
            }
        };

        IntentFilter filter = new IntentFilter(MEDIA_BROADCAST_ACTION);
        registerReceiver(serviceBroadcastReceiver, filter);
    }

    private void handleMediaButton(int keyCode) {
        switch (keyCode) {
            case KeyEvent.KEYCODE_MEDIA_PLAY:
                sendMediaControlEvent("play");
                break;
            case KeyEvent.KEYCODE_MEDIA_PAUSE:
                sendMediaControlEvent("pause");
                break;
            case KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE:
                sendMediaControlEvent("playPause");
                break;
            case KeyEvent.KEYCODE_MEDIA_NEXT:
                sendMediaControlEvent("next");
                break;
            case KeyEvent.KEYCODE_MEDIA_PREVIOUS:
                sendMediaControlEvent("previous");
                break;
            case KeyEvent.KEYCODE_MEDIA_STOP:
                sendMediaControlEvent("stop");
                break;
        }
    }

    private void sendMediaControlEvent(String action) {
        if (methodChannel != null) {
            getMainExecutor().execute(() -> {
                methodChannel.invokeMethod("onMediaControl", action);
            });
        }
    }

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        // Set up method channel for communication with Flutter
        methodChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(),
                                         MEDIA_CONTROL_CHANNEL);

        methodChannel.setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "updatePlaybackState":
                    updatePlaybackState((String) call.argument("state"));
                    result.success(null);
                    break;
                case "updateMetadata":
                    updateMetadata(call.arguments);
                    result.success(null);
                    break;
                default:
                    result.notImplemented();
                    break;
            }
        });
    }

    private void updatePlaybackState(String state) {
        if (mediaSession != null) {
            int playbackStateAction = PlaybackState.STATE_STOPPED;
            switch (state) {
                case "playing":
                    playbackStateAction = PlaybackState.STATE_PLAYING;
                    break;
                case "paused":
                    playbackStateAction = PlaybackState.STATE_PAUSED;
                    break;
                case "stopped":
                    playbackStateAction = PlaybackState.STATE_STOPPED;
                    break;
            }

            PlaybackState.Builder builder = new PlaybackState.Builder()
                    .setState(playbackStateAction, PlaybackState.PLAYBACK_POSITION_UNKNOWN, 1.0f)
                    .setActions(PlaybackState.ACTION_PLAY |
                               PlaybackState.ACTION_PAUSE |
                               PlaybackState.ACTION_PLAY_PAUSE |
                               PlaybackState.ACTION_SKIP_TO_NEXT |
                               PlaybackState.ACTION_SKIP_TO_PREVIOUS |
                               PlaybackState.ACTION_STOP);

            mediaSession.setPlaybackState(builder.build());
        }
    }

    private void updateMetadata(Object metadata) {
        if (mediaSession != null && metadata instanceof java.util.Map) {
            @SuppressWarnings("unchecked")
            java.util.Map<String, Object> metaMap = (java.util.Map<String, Object>) metadata;

            android.media.MediaMetadata.Builder builder = new android.media.MediaMetadata.Builder();

            String title = (String) metaMap.get("title");
            String artist = (String) metaMap.get("artist");
            String album = (String) metaMap.get("album");

            if (title != null) builder.putString(android.media.MediaMetadata.METADATA_KEY_TITLE, title);
            if (artist != null) builder.putString(android.media.MediaMetadata.METADATA_KEY_ARTIST, artist);
            if (album != null) builder.putString(android.media.MediaMetadata.METADATA_KEY_ALBUM, album);

            mediaSession.setMetadata(builder.build());
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();

        if (mediaButtonReceiver != null) {
            unregisterReceiver(mediaButtonReceiver);
        }

        if (serviceBroadcastReceiver != null) {
            unregisterReceiver(serviceBroadcastReceiver);
        }

        if (mediaSession != null) {
            mediaSession.release();
        }
    }
}
