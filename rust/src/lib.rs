use flutter_rust_bridge::{frb, StreamSink};

/// Core audio engine for Tunes4R
pub struct AudioEngine {
    // TODO: Implement with rodio, rustfft, etc.
    pub sample_rate: u32,
}

/// Domain model for a song
#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
pub struct Song {
    pub id: String,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub duration: u64,
    pub file_path: String,
}

/// Audio playback state
#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
pub enum PlaybackState {
    Stopped,
    Playing,
    Paused,
    Loading,
}

/// Event types for reactive UI updates
#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
pub enum AudioEvent {
    PlaybackStateChanged { state: PlaybackState, song: Option<Song> },
    SpectrumDataUpdated { frequencies: Vec<f32> },
    ProgressUpdated { current_time: f64, total_time: f64 },
}

/// FFI API exposed to Flutter
#[frb(sync)]
pub fn create_audio_engine() -> AudioEngine {
    AudioEngine { sample_rate: 44100 }
}

#[frb(sync)]
pub fn get_next_free_id() -> u32 {
    use std::sync::atomic::{AtomicU32, Ordering};
    static COUNTER: AtomicU32 = AtomicU32::new(0);
    COUNTER.fetch_add(1, Ordering::Relaxed)
}

#[frb(init)]
pub fn init_app() {
    // App initialization code
    tracing_subscriber::fmt::init();
}

#[frb(stream)]
pub fn tick_stream(sink: StreamSink<i32>) {
    // TODO: Replace with actual audio events
    tokio::spawn(async move {
        for i in 0..100 {
            sink.add(i).unwrap();
            tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
        }
    });
}
