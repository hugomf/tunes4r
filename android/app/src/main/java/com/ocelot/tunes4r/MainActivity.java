package com.ocelot.tunes4r;

import android.content.ComponentName;
import android.content.Intent;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.os.Build;
import android.os.Bundle;
import android.os.SystemClock;
import android.util.Log;
import android.view.KeyEvent;
import android.app.PendingIntent;

import androidx.annotation.NonNull;
import androidx.media.session.MediaButtonReceiver;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

import android.support.v4.media.MediaMetadataCompat;
import android.support.v4.media.session.MediaSessionCompat;
import android.support.v4.media.session.PlaybackStateCompat;

import android.media.audiofx.Equalizer;
import java.util.ArrayList;
import java.util.List;

public class MainActivity extends FlutterActivity {

    private static final String CHANNEL = "com.ocelot.tunes4r/media_controls";
    private static final String AUDIO_CHANNEL = "com.example.tunes4r/audio";
    private static final String TAG = "Tunes4RSession";
    private static final String MEDIA_SESSION_TAG = "tunes4r_media_session";

    private MediaSessionCompat mediaSession;
    private MethodChannel methodChannel;
    private MethodChannel audioMethodChannel;
    private AudioManager audioManager;
    private AudioFocusRequest audioFocusRequest;
    private boolean hasAudioFocus = false;
    private long currentPosition = 0;
    private AudioManager.OnAudioFocusChangeListener afChangeListener;
    private Equalizer equalizer;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Log.d(TAG, "🚀 onCreate - Android Version: " + Build.VERSION.SDK_INT);
        audioManager = (AudioManager) getSystemService(AUDIO_SERVICE);
        initializeAudioFocusListener();
        initializeMediaSession();

        // Handle media button intent if launched by it
        handleIntent(getIntent());
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        Log.d(TAG, "📨 onNewIntent received");
        handleIntent(intent);
    }

    private void handleIntent(Intent intent) {
        if (intent == null)
            return;

        Log.d(TAG, "🔍 handleIntent - Action: " + intent.getAction());

        if (Intent.ACTION_MEDIA_BUTTON.equals(intent.getAction())) {
            KeyEvent event = intent.getParcelableExtra(Intent.EXTRA_KEY_EVENT);
            if (event != null && event.getAction() == KeyEvent.ACTION_DOWN) {
                Log.d(TAG, "🎯 Media button intent - KeyCode: " + event.getKeyCode());

                switch (event.getKeyCode()) {
                    case KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE:
                    case KeyEvent.KEYCODE_HEADSETHOOK:
                        sendToFlutter("playPause");
                        break;
                    case KeyEvent.KEYCODE_MEDIA_PLAY:
                        sendToFlutter("play");
                        break;
                    case KeyEvent.KEYCODE_MEDIA_PAUSE:
                        sendToFlutter("pause");
                        break;
                    case KeyEvent.KEYCODE_MEDIA_NEXT:
                        sendToFlutter("next");
                        break;
                    case KeyEvent.KEYCODE_MEDIA_PREVIOUS:
                        sendToFlutter("previous");
                        break;
                    case KeyEvent.KEYCODE_MEDIA_STOP:
                        sendToFlutter("stop");
                        break;
                }
            }
        }
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        Log.d(TAG, "🎹 onKeyDown - KeyCode: " + keyCode);
        switch (keyCode) {
            case KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE:
            case KeyEvent.KEYCODE_HEADSETHOOK:
                Log.d(TAG, "⏯️ Play/Pause key intercepted");
                sendToFlutter("playPause");
                return true;
            case KeyEvent.KEYCODE_MEDIA_PLAY:
                Log.d(TAG, "▶️ Play key intercepted");
                sendToFlutter("play");
                return true;
            case KeyEvent.KEYCODE_MEDIA_PAUSE:
                Log.d(TAG, "⏸️ Pause key intercepted");
                sendToFlutter("pause");
                return true;
            case KeyEvent.KEYCODE_MEDIA_NEXT:
                Log.d(TAG, "⏭️ Next key intercepted");
                sendToFlutter("next");
                return true;
            case KeyEvent.KEYCODE_MEDIA_PREVIOUS:
                Log.d(TAG, "⏮️ Previous key intercepted");
                sendToFlutter("previous");
                return true;
            case KeyEvent.KEYCODE_MEDIA_STOP:
                Log.d(TAG, "⏹️ Stop key intercepted");
                sendToFlutter("stop");
                return true;
        }
        return super.onKeyDown(keyCode, event);
    }

    private void initializeAudioFocusListener() {
        afChangeListener = new AudioManager.OnAudioFocusChangeListener() {
            public void onAudioFocusChange(int focusChange) {
                Log.d(TAG, "🔊 Audio focus changed: " + focusChange);
                switch (focusChange) {
                    case AudioManager.AUDIOFOCUS_LOSS_TRANSIENT:
                        sendToFlutter("pause");
                        break;
                    case AudioManager.AUDIOFOCUS_GAIN:
                        sendToFlutter("play");
                        break;
                    case AudioManager.AUDIOFOCUS_LOSS:
                        sendToFlutter("stop");
                        break;
                    case AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK:
                        break;
                }
            }
        };
    }

    private void initializeMediaSession() {
        Log.d(TAG, "🎵 Initializing MediaSessionCompat");

        ComponentName mediaButtonReceiver = new ComponentName(this, MediaButtonReceiver.class);
        mediaSession = new MediaSessionCompat(this, MEDIA_SESSION_TAG, mediaButtonReceiver, null);

        // CRITICAL: Set flags to handle media buttons and transport controls
        mediaSession.setFlags(
                MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS |
                        MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS);

        // Create PendingIntent for media button receiver
        Intent mediaButtonIntent = new Intent(Intent.ACTION_MEDIA_BUTTON);
        mediaButtonIntent.setClass(this, MediaButtonReceiver.class);
        PendingIntent pendingIntent = PendingIntent.getBroadcast(
                this,
                0,
                mediaButtonIntent,
                PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
        mediaSession.setMediaButtonReceiver(pendingIntent);

        // Set initial playback state BEFORE activating
        updatePlaybackStateInternal(PlaybackStateCompat.STATE_STOPPED);

        // Register MediaBrowserService
        TunesMediaBrowserService.setMediaSession(mediaSession);

        // NOW activate the session
        mediaSession.setActive(true);
        Log.d(TAG, "✅ MediaSession activated");

        // Set the callback to handle media controls
        mediaSession.setCallback(new MediaSessionCompat.Callback() {
            @Override
            public boolean onMediaButtonEvent(Intent mediaButtonIntent) {
                Log.d(TAG, "🎯 === onMediaButtonEvent CALLED ===");

                if (mediaButtonIntent == null) {
                    Log.e(TAG, "❌ mediaButtonIntent is null");
                    return super.onMediaButtonEvent(mediaButtonIntent);
                }

                KeyEvent event = mediaButtonIntent.getParcelableExtra(Intent.EXTRA_KEY_EVENT);

                if (event == null) {
                    Log.e(TAG, "❌ KeyEvent is null");
                    return super.onMediaButtonEvent(mediaButtonIntent);
                }

                Log.d(TAG, "🔑 KeyEvent - Action: " + event.getAction() +
                        ", KeyCode: " + event.getKeyCode() +
                        ", RepeatCount: " + event.getRepeatCount());

                if (event.getAction() != KeyEvent.ACTION_DOWN) {
                    Log.d(TAG, "⏭️ Ignoring non-ACTION_DOWN event");
                    return super.onMediaButtonEvent(mediaButtonIntent);
                }

                if (event.getRepeatCount() > 0) {
                    Log.d(TAG, "🔁 Ignoring repeat event");
                    return super.onMediaButtonEvent(mediaButtonIntent);
                }

                switch (event.getKeyCode()) {
                    case KeyEvent.KEYCODE_HEADSETHOOK:
                    case KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE:
                        Log.d(TAG, "⏯️ Play/Pause button pressed");
                        sendToFlutter("playPause");
                        return true;
                    case KeyEvent.KEYCODE_MEDIA_PLAY:
                        Log.d(TAG, "▶️ Play button pressed");
                        requestAudioFocus();
                        sendToFlutter("play");
                        return true;
                    case KeyEvent.KEYCODE_MEDIA_PAUSE:
                        Log.d(TAG, "⏸️ Pause button pressed");
                        sendToFlutter("pause");
                        return true;
                    case KeyEvent.KEYCODE_MEDIA_NEXT:
                        Log.d(TAG, "⏭️ Next button pressed");
                        sendToFlutter("next");
                        return true;
                    case KeyEvent.KEYCODE_MEDIA_PREVIOUS:
                        Log.d(TAG, "⏮️ Previous button pressed");
                        sendToFlutter("previous");
                        return true;
                    case KeyEvent.KEYCODE_MEDIA_STOP:
                        Log.d(TAG, "⏹️ Stop button pressed");
                        abandonAudioFocus();
                        sendToFlutter("stop");
                        return true;
                    default:
                        Log.d(TAG, "❓ Unhandled keycode: " + event.getKeyCode());
                }
                return super.onMediaButtonEvent(mediaButtonIntent);
            }

            @Override
            public void onPlay() {
                Log.d(TAG, "▶️ onPlay callback");
                requestAudioFocus();
                sendToFlutter("play");
            }

            @Override
            public void onPause() {
                Log.d(TAG, "⏸️ onPause callback");
                sendToFlutter("pause");
            }

            @Override
            public void onSkipToNext() {
                Log.d(TAG, "⏭️ onSkipToNext callback");
                sendToFlutter("next");
            }

            @Override
            public void onSkipToPrevious() {
                Log.d(TAG, "⏮️ onSkipToPrevious callback");
                sendToFlutter("previous");
            }

            @Override
            public void onStop() {
                Log.d(TAG, "⏹️ onStop callback");
                abandonAudioFocus();
                sendToFlutter("stop");
            }
        });

        Log.d(TAG, "✅ MediaSession initialization complete");
    }

    private void updatePlaybackStateInternal(int state) {
        PlaybackStateCompat.Builder builder = new PlaybackStateCompat.Builder()
                .setActions(
                        PlaybackStateCompat.ACTION_PLAY |
                                PlaybackStateCompat.ACTION_PAUSE |
                                PlaybackStateCompat.ACTION_PLAY_PAUSE |
                                PlaybackStateCompat.ACTION_SKIP_TO_NEXT |
                                PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS |
                                PlaybackStateCompat.ACTION_STOP)
                .setState(state, currentPosition, 1.0f, SystemClock.elapsedRealtime());

        mediaSession.setPlaybackState(builder.build());
        Log.d(TAG, "📊 Playback state updated to: " + state);
    }

    private void sendToFlutter(String action) {
        if (methodChannel != null) {
            runOnUiThread(() -> {
                try {
                    Log.d(TAG, "📤 Sending to Flutter → " + action);
                    methodChannel.invokeMethod("onMediaControl", action, new MethodChannel.Result() {
                        @Override
                        public void success(Object result) {
                            Log.d(TAG, "✅ Flutter successfully received: " + action);
                        }

                        @Override
                        public void error(String errorCode, String errorMessage, Object errorDetails) {
                            Log.e(TAG, "❌ Failed to send to Flutter: " + errorMessage);
                        }

                        @Override
                        public void notImplemented() {
                            Log.e(TAG, "⚠️ Method not implemented in Flutter");
                        }
                    });
                } catch (Exception e) {
                    Log.e(TAG, "💥 Error sending to Flutter", e);
                }
            });
        } else {
            Log.e(TAG, "⚠️ MethodChannel not initialized, cannot send action: " + action);
        }
    }

    private void updatePlaybackState(String state) {
        Log.d(TAG, "📥 Updating playback state from Flutter: " + state);
        int playbackState = PlaybackStateCompat.STATE_STOPPED;
        switch (state) {
            case "playing":
                playbackState = PlaybackStateCompat.STATE_PLAYING;
                requestAudioFocus();
                break;
            case "paused":
                playbackState = PlaybackStateCompat.STATE_PAUSED;
                break;
            case "stopped":
                playbackState = PlaybackStateCompat.STATE_STOPPED;
                abandonAudioFocus();
                break;
        }
        updatePlaybackStateInternal(playbackState);
    }

    private void updateMetadata(Object args) {
        if (!(args instanceof java.util.Map)) {
            Log.e(TAG, "❌ Invalid metadata format");
            return;
        }

        @SuppressWarnings("unchecked")
        java.util.Map<String, Object> map = (java.util.Map<String, Object>) args;

        MediaMetadataCompat.Builder builder = new MediaMetadataCompat.Builder();

        String title = map.containsKey("title") ? (String) map.get("title") : "";
        String artist = map.containsKey("artist") ? (String) map.get("artist") : "";
        String album = map.containsKey("album") ? (String) map.get("album") : "";

        builder.putString(MediaMetadataCompat.METADATA_KEY_TITLE, title);
        builder.putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist);
        builder.putString(MediaMetadataCompat.METADATA_KEY_ALBUM, album);

        if (map.containsKey("duration") && map.get("duration") instanceof Long) {
            builder.putLong(MediaMetadataCompat.METADATA_KEY_DURATION, (Long) map.get("duration"));
        }

        if (map.containsKey("artUri") && map.get("artUri") instanceof String) {
            builder.putString(MediaMetadataCompat.METADATA_KEY_ALBUM_ART_URI, (String) map.get("artUri"));
        }

        mediaSession.setMetadata(builder.build());
        Log.d(TAG, "🎼 Metadata updated - Title: " + title + ", Artist: " + artist);
    }

    private void updatePosition(long position) {
        currentPosition = position;
        if (mediaSession != null && mediaSession.getController() != null
                && mediaSession.getController().getPlaybackState() != null) {
            int currentState = mediaSession.getController().getPlaybackState().getState();
            updatePlaybackStateInternal(currentState);
        }
        Log.d(TAG, "⏱️ Position updated to: " + position);
    }

    private void requestAudioFocus() {
        if (hasAudioFocus) {
            Log.d(TAG, "✅ Already has audio focus");
            return;
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            AudioAttributes attrs = new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build();
            audioFocusRequest = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                    .setAudioAttributes(attrs)
                    .setOnAudioFocusChangeListener(afChangeListener)
                    .build();
            int result = audioManager.requestAudioFocus(audioFocusRequest);
            hasAudioFocus = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED;
            Log.d(TAG, "🔊 Audio focus request result: " + (hasAudioFocus ? "GRANTED" : "DENIED"));
        } else {
            @SuppressWarnings("deprecation")
            int result = audioManager.requestAudioFocus(afChangeListener, AudioManager.STREAM_MUSIC,
                    AudioManager.AUDIOFOCUS_GAIN);
            hasAudioFocus = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED;
            Log.d(TAG, "🔊 Audio focus request result: " + (hasAudioFocus ? "GRANTED" : "DENIED"));
        }
    }

    private void abandonAudioFocus() {
        if (!hasAudioFocus) {
            Log.d(TAG, "⚠️ No audio focus to abandon");
            return;
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && audioFocusRequest != null) {
            audioManager.abandonAudioFocusRequest(audioFocusRequest);
        } else {
            audioManager.abandonAudioFocus(afChangeListener);
        }
        hasAudioFocus = false;
        Log.d(TAG, "🔇 Audio focus abandoned");
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        Log.d(TAG, "🔧 Configuring Flutter engine");

        methodChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL);
        methodChannel.setMethodCallHandler((call, result) -> {
            try {
                Log.d(TAG, "📨 Received method call from Flutter: " + call.method);
                switch (call.method) {
                    case "updatePlaybackState":
                        updatePlaybackState(call.argument("state"));
                        result.success(null);
                        break;
                    case "updateMetadata":
                        updateMetadata(call.arguments);
                        result.success(null);
                        break;
                    case "updatePosition":
                        Long position = call.argument("position");
                        if (position != null) {
                            updatePosition(position);
                        }
                        result.success(null);
                        break;
                    default:
                        Log.w(TAG, "⚠️ Unhandled method: " + call.method);
                        result.notImplemented();
                        break;
                }
            } catch (Exception e) {
                Log.e(TAG, "💥 Error handling method call: " + call.method, e);
                result.error("ERROR", "Failed to handle method call", e.getMessage());
            }
        });

        audioMethodChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), AUDIO_CHANNEL);
        audioMethodChannel.setMethodCallHandler((call, result) -> {
            try {
                Log.d(TAG, "🎛️ Received audio method call from Flutter: " + call.method);
                switch (call.method) {
                    case "initializeEqualizer":
                        initializeEqualizer();
                        result.success(null);
                        break;
                    case "applyEqualizer":
                        applyEqualizer(call.argument("bands"));
                        result.success(null);
                        break;
                    case "resetEqualizer":
                        resetEqualizer();
                        result.success(null);
                        break;
                    case "enableEqualizer":
                        enableEqualizer();
                        result.success(null);
                        break;
                    case "disableEqualizer":
                        disableEqualizer();
                        result.success(null);
                        break;
                    case "setAudioSessionId":
                        Integer sessionId = call.argument("sessionId");
                        if (sessionId != null) {
                            setAudioSessionId(sessionId);
                        }
                        result.success(null);
                        break;
                    default:
                        Log.w(TAG, "⚠️ Unhandled audio method: " + call.method);
                        result.notImplemented();
                        break;
                }
            } catch (Exception e) {
                Log.e(TAG, "💥 Error handling audio method call: " + call.method, e);
                result.error("ERROR", "Failed to handle audio method call", e.getMessage());
            }
        });

        Log.d(TAG, "✅ MethodChannels configured successfully");
    }

    @Override
    protected void onDestroy() {
        Log.d(TAG, "🛑 onDestroy called");
        if (equalizer != null) {
            equalizer.release();
            equalizer = null;
        }
        if (mediaSession != null) {
            mediaSession.setActive(false);
            mediaSession.release();
            mediaSession = null;
            Log.d(TAG, "🗑️ MediaSession released");
        }
        abandonAudioFocus();
        super.onDestroy();
    }

    private void initializeEqualizer() {
        try {
            if (equalizer != null) {
                equalizer.release();
            }
            equalizer = new Equalizer(0, 0); // Use global session
            equalizer.setEnabled(false); // Start disabled
            Log.d(TAG, "🎛️ Equalizer initialized successfully");
        } catch (Exception e) {
            Log.e(TAG, "Failed to initialize equalizer", e);
        }
    }

    private void applyEqualizer(List<Double> bands) {
        try {
            if (equalizer == null || bands == null) {
                Log.w(TAG, "Equalizer not initialized or bands null");
                return;
            }
            short numberOfBands = equalizer.getNumberOfBands();
            short[] bandLevelRange = equalizer.getBandLevelRange();

            for (short i = 0; i < numberOfBands && i < bands.size(); i++) {
                // Convert from dB to millibels
                short targetGain = (short) (bands.get(i) * 100);
                targetGain = (short) Math.max(bandLevelRange[0], Math.min(bandLevelRange[1], targetGain));

                // SMOOTH RAMPING: Gradually move to target to avoid clicks
                short currentGain = equalizer.getBandLevel(i);
                short difference = (short) (targetGain - currentGain);

                // If change is large (>300 millibels = 3dB), ramp it
                if (Math.abs(difference) > 300) {
                    // Apply 70% of the change (smooth transition)
                    short smoothGain = (short) (currentGain + difference * 0.7);
                    equalizer.setBandLevel(i, smoothGain);
                } else {
                    // Small changes can be applied directly
                    equalizer.setBandLevel(i, targetGain);
                }

                int centerFreq = equalizer.getCenterFreq(i) / 1000;
                Log.d(TAG, "   Band " + i + " (" + centerFreq + "Hz): " + bands.get(i) + "dB");
            }
            Log.d(TAG, "🎛️ Equalizer bands applied with smoothing");
        } catch (Exception e) {
            Log.e(TAG, "Failed to apply equalizer bands", e);
        }
    }

    private void resetEqualizer() {
        try {
            if (equalizer == null) {
                return;
            }
            short numberOfBands = equalizer.getNumberOfBands();
            for (short i = 0; i < numberOfBands; i++) {
                equalizer.setBandLevel(i, (short) 0);
            }
            Log.d(TAG, "🎛️ Equalizer reset to flat");
        } catch (Exception e) {
            Log.e(TAG, "Failed to reset equalizer", e);
        }
    }

    private void enableEqualizer() {
        try {
            if (equalizer != null) {
                equalizer.setEnabled(true);
                Log.d(TAG, "🎛️ Equalizer ENABLED");
            } else {
                Log.w(TAG, "⚠️ Equalizer is null, cannot enable");
            }
        } catch (Exception e) {
            Log.e(TAG, "Failed to enable equalizer", e);
        }
    }

    private void disableEqualizer() {
        try {
            if (equalizer != null) {
                equalizer.setEnabled(false);
                Log.d(TAG, "🎛️ Equalizer DISABLED");
            } else {
                Log.w(TAG, "⚠️ Equalizer is null, cannot disable");
            }
        } catch (Exception e) {
            Log.e(TAG, "Failed to disable equalizer", e);
        }
    }

    private void setAudioSessionId(int sessionId) {
        try {
            boolean wasEnabled = false;
            List<Double> savedBands = new ArrayList<>();

            // Save current state if equalizer exists
            if (equalizer != null) {
                wasEnabled = equalizer.getEnabled();
                short numberOfBands = equalizer.getNumberOfBands();
                for (short i = 0; i < numberOfBands; i++) {
                    savedBands.add((double) equalizer.getBandLevel(i) / 100.0);
                }
                equalizer.release();
            }

            // Create new equalizer with the audio session
            equalizer = new Equalizer(0, sessionId);
            equalizer.setEnabled(wasEnabled);

            // Restore band levels if we had any
            if (!savedBands.isEmpty()) {
                applyEqualizer(savedBands);
            }

            Log.d(TAG, "🎛️ Equalizer initialized with session ID: " + sessionId + ", enabled: " + wasEnabled);
        } catch (Exception e) {
            Log.e(TAG, "Failed to set audio session ID", e);
        }
    }
}