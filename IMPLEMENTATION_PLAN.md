# 🎵 Tunes4R Implementation Plan - Reactive MVC Music Player with Tauri

## 📖 Overview

Tunes4R is a Rust recreation of Tunes4J using Tauri framework, maintaining the reactive MVC architecture with bounded contexts communicating via an event-driven Observer Pattern. The frontend uses modern web technologies (HTML/CSS/JS) while all audio processing, database operations, and business logic run in performant Rust.

## 🏗️ Architectural Foundation

### Core Design Principles
- **Reactive MVC²**: Maintains Tunes4J's reactive architecture
- **Bounded Contexts**: Domain-driven design with clear separation
- **Observer Pattern**: Event-driven communication via Tauri's event system
- **Cross-Platform**: Web UI + native backend = consistent experience

### Technology Stack
- **Frontend**: HTML/CSS/TypeScript, Vue.js React alternative for reactive UI
- **Backend**: Rust with async runtime (tokio)
- **Framework**: Tauri for desktop app packaging
- **Audio**: Rodio (playback) + RustFFT (spectrum)
- **Database**: Rusqlite for song persistence
- **Build**: Cargo for Rust, npm for frontend

---

## 📋 Implementation Phases & Tasks

### Phase 1: Project Setup & Foundation (Priority: High)
*Estimated Time: 2-3 days*

#### ✅ Task 1.1: Initialize Tauri Project Structure
- [ ] Run `cargo create-tauri-app Tunes4R --template vue-ts` (or react-ts)
- [ ] Configure `tauri.conf.json` with window settings and permissions
- [ ] Set up frontend framework (Vue.js/Reacts) with TypeScript
- [ ] Install core frontend dependencies (Vue Router, Pinia for state)

#### ✅ Task 1.2: Core Dependencies & Cargo Configuration
- [ ] Add Rust dependencies:
  - `tokio = { version = "1", features = ["full"] }`
  - `rodio = "0.19"`
  - `rustfft = "6"`
  - `rusqlite = "0.32"`
  - `serde = { version = "1", features = ["derive"] }`
  - `tauri = { version = "2", features = [...system tray, fs, shell, notification] }`
- [ ] Configure audio and database feature flags

#### ✅ Task 1.3: Event System & Domain Models
- [ ] Implement event bus using Tauri's event system
- [ ] Define core event types (AudioEvent, LibraryEvent, AppEvent)
- [ ] Create domain models (Song, Playlist, AudioPlayback)
- [ ] Set up shared state management (Tauri managed state)

### Phase 2: Audio Bounded Context (Priority: High)
*Estimated Time: 5-7 days*

#### ✅ Task 2.1: Audio Domain Models & Infrastructure
- [ ] Implement `audio/model.rs`:
  - Song struct (from dto/Song.java)
  - AudioPlayback state machine
  - Spectrum domain objects
- [ ] Create basic audio playback adapter with Rodio
- [ ] Set up database schema for song metadata

#### ✅ Task 2.2: Audio Services & Adapters
- [ ] PlaybackService: Audio playback lifecycle management
- [ ] SpectrumService: Real-time FFT processing for visualization
- [ ] AudioPlayerAdapter: Rodio wrapper with equalizer/volume control
- [ ] SpectrumProcessor: FFT analysis with configurable sample sizes

#### ✅ Task 2.3: Audio Controller & Event Handling
- [ ] AudioController implementation:
  - Event listeners for AudioSongSelectedEvent
  - User interaction handling (play/pause/stop)
  - State management and state change publication
- [ ] Tauri commands for audio operations
- [ ] Progress update event emission

#### ✅ Task 2.4: Audio React Frontend Components
- [ ] AudioPlayer component: Play/pause/stop/volume controls
- [ ] VolumeControl with slider and numerical display
- [ ] ProgressBar with seek functionality
- [ ] Equalizer panel with adjustable bands

### Phase 3: Library Bounded Context (Priority: High)
*Estimated Time: 4-5 days*

#### ✅ Task 3.1: Library Domain Models
- [ ] LibrarySong aggregate with metadata
- [ ] Search and filtering criteria
- [ ] File system scanning domain logic

#### ✅ Task 3.2: Database Layer & Persistence
- [ ] SongRepository with Rusqlite crate
- [ ] Metadata extraction from audio files
- [ ] Database migration scripts
- [ ] CRUD operations for song management

#### ✅ Task 3.3: Library Controller & Search
- [ ] LibraryController for event-driven operations
- [ ] Song import/scanning service
- [ ] Search functionality with indexing
- [ ] Tauri commands for library APIs

#### ✅ Task 3.4: Library UI Components
- [ ] SongTable component: Sortable, filterable data table
- [ ] SearchBar with real-time filtering
- [ ] Import dialog for adding music files
- [ ] Library statistics display

### Phase 4: Spectrum Visualization (Priority: Medium)
*Estimated Time: 3-4 days*

#### ✅ Task 4.1: Spectrum Processing Pipeline
- [ ] FFT analysis integration with rodio audio stream
- [ ] Frequency binning and magnitude calculation
- [ ] Spectrum data formatting for visualization
- [ ] Performance optimization for real-time processing

#### ✅ Task 4.2: Spectrum Canvas Component
- [ ] Web Audio API or Canvas-based visualization
- [ ] Real-time frequency bar rendering
- [ ] Configurable visualization modes (bars, wave)
- [ ] Responsive design with variable bar counts

#### ✅ Task 4.3: Spectrum UI Integration
- [ ] Spectrum toggle in playback controls
- [ ] Theme-aware color schemes
- [ ] Peak hold and smoothing options

### Phase 5: Application Composition (Priority: High)
*Estimated Time: 2-3 days*

#### ✅ Task 5.1: Main Application Layout
- [ ] ApplicationWindow composition in Vue/React
- [ ] Vertical split panel (audio player top, library bottom)
- [ ] Responsive layout adjustments
- [ ] Window management (minimize, close, resize)

#### ✅ Task 5.2: Event Routing & State Management
- [ ] ApplicationController for cross-boundary coordination
- [ ] Frontend state management (Pinia/Vuex)
- [ ] Global event listeners and state synchronization
- [ ] Reactive updates across components

#### ✅ Task 5.3: Application Services
- [ ] Theme management system
- [ ] System notification integration
- [ ] Keyboard shortcuts and global hotkeys
- [ ] Auto-update configuration

### Phase 6: UI/UX Polish & Themes (Priority: Medium)
*Estimated Time: 3-4 days*

#### ✅ Task 6.1: Design System Implementation
- [ ] Consistent design tokens (colors, typography, spacing)
- [ ] Dark/light theme support
- [ ] Icon system and asset management
- [ ] Responsive breakpoints and layout

#### ✅ Task 6.2: Advanced UI Components
- [ ] Context menus and popup dialogs
- [ ] Drag-and-drop playlist management
- [ ] Loading states and error handling
- [ ] Accessibility features (ARIA labels, keyboard navigation)

#### ✅ Task 6.3: Performance Optimization
- [ ] Frontend bundle optimization
- [ ] Image loading and caching
- [ ] Virtual scrolling for large song lists
- [ ] Memory management for audio processing

### Phase 7: Integration & Testing (Priority: High)
*Estimated Time: 3-4 days*

#### ✅ Task 7.1: End-to-End Integration
- [ ] Complete playback flow (library selection → audio playback)
- [ ] Spectrum visualization pipeline testing
- [ ] Database persistence verification
- [ ] Cross-platform functionality validation

#### ✅ Task 7.2: Automated Testing
- [ ] Unit tests for domain models and services
- [ ] Integration tests for event communication
- [ ] UI component tests with Vitest or equivalent
- [ ] Audio processing accuracy tests

#### ✅ Task 7.3: Packaging & Distribution
- [ ] Configure Tauri build pipeline
- [ ] Create installers for Linux, Windows, macOS
- [ ] Test automated builds and CI/CD
- [ ] Set up update distribution

### Phase 8: Advanced Features (Priority: Low)
*Estimated Time: 5-7 days*

#### ✅ Task 8.1: Playlist Management
- [ ] Playlist bounded context implementation
- [ ] Drag-and-drop song reordering
- [ ] Playlist persistence and export
- [ ] Smart playlists with filters

#### ✅ Task 8.2: Audio Enhancements
- [ ] Gapless playback implementation
- [ ] Audio normalization and loudness analysis
- [ ] Multi-track audio support
- [ ] External audio device selection

#### ✅ Task 8.3: Cloud Integration (Future)
- [ ] Media library synchronization
- [ ] Online radio station support
- [ ] Streaming service integration

---

## 🎯 Development Guidelines

### Code Organization
- **Frontend**: Feature-based organization under `src/components/`
- **Backend**: Domain-driven structure under `src/*/`
- **Shared**: Common utilities in separate modules
- **Tests**: Mirror source structure in `src/test/` or equivalent

### Event-Driven Architecture
- All component communication through central event bus
- Reactive UI updates via Tauri's event system
- Immutable event payloads for consistency
- Async event handling with proper error propagation

### Performance Considerations
- Audio processing in dedicated threads/tasks
- Database operations with connection pooling
- UI virtual scrolling for large datasets
- Efficient FFT computations with SIMD where available

### Cross-Platform Compatibility
- Path handling with Tauri's fs APIs
- Platform-specific UI adaptations
- Audio codec support verification
- System notification APIs

### Testing Strategy
- Domain model unit tests
- Audio processing accuracy tests
- UI component integration tests
- End-to-end playback flow tests
- Cross-platform binary testing

---

## 📈 Risk Assessment & Mitigation

### High Risk Items
1. **Audio Spectrum Real-time Processing**
   - Risk: Performance impact on playback
   - Mitigation: Dedicated thread, optimized FFT, graceful degradation

2. **Cross-platform Audio Compatibility**
   - Risk: Audio codec and hardware differences
   - Mitigation: Abstract hardware differences, provide fallbacks, extensive testing

3. **Reactive State Synchronization**
   - Risk: UI-state desynchronization
   - Mitigation: Centralized state, event-driven updates, error boundaries

### Dependencies
- **Tauri Maturity**: As maturing framework, stay current with updates
- **Audio Libraries**: Monitor rodio and rustfft development
- **Web Standards**: Ensure compatibility with targeted browser engines

---

## 📅 Timeline & Milestones

**Phase 1-2**: Weeks 1-2 | Basic playback functionality
**Phase 3**: Weeks 2-3 | Library management complete
**Phase 4**: Weeks 3-4 | Spectrum visualization
**Phase 5-6**: Weeks 4-5 | Polished UI and theming
**Phase 7-8**: Weeks 5-6 | Testing, packaging, advanced features

**Total Estimated Duration: 6-8 weeks** with 1-2 developers
