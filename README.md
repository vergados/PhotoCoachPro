# Photo Coach Pro — Phase 1: Foundation

Privacy-first, professional-grade photo editing and AI coaching app for iOS, iPadOS, and macOS.

**Phase 1 Status:** ✅ Complete — Core editing pipeline implemented

## What's Built (Phase 1)

### ✅ Core Engine
- **ImagePipeline**: Load, render, and cache images with color space management
- **EditGraph Engine**: Non-destructive editing with undo/redo
- **Metadata**: Full EXIF/IPTC reading
- **Color Management**: sRGB, Display P3, Adobe RGB, ProPhoto RGB support
- **Export**: JPEG/PNG export with privacy controls

### ✅ Data Layer
- **SwiftData Models**: PhotoRecord, EditRecord with full persistence
- **Edit History**: Branch-ready edit graph with undo/redo
- **Privacy Controls**: Metadata stripping, location removal

### ✅ UI (Phase 1)
- **Home View**: Photo library with grid display
- **Editor**: Real-time editing canvas with 20+ adjustments
- **Tool Panels**: Basic (tone), Color, Detail, Effects
- **Accessibility**: Full VoiceOver support, Dynamic Type, Reduce Motion

### ✅ Adjustments Implemented
**Basic Tone**: Exposure, Contrast, Highlights, Shadows, Whites, Blacks
**Color**: Temperature, Tint, Saturation, Vibrance
**Detail**: Texture, Clarity, Sharpening, Noise Reduction
**Effects**: Dehaze, Vignette, Grain

## Project Structure

```
PhotoCoachPro/
├── App/
│   ├── PhotoCoachProApp.swift      # Main app entry point
│   └── AppState.swift              # Central state management
├── CoreEngine/
│   ├── ImagePipeline/              # Loading, rendering, color management
│   ├── EditGraph/                  # Non-destructive editing engine
│   └── MetadataAnalyzer/           # EXIF/IPTC reading
├── Storage/
│   ├── Models/                     # SwiftData models
│   ├── LocalDatabase.swift         # Database operations
│   └── PrivacyControls/            # Privacy settings
├── UI/
│   ├── Home/                       # Library view
│   ├── Editor/                     # Editing interface
│   └── Shared/                     # Reusable components
└── Export/
    └── ExportManager.swift         # Export coordination
```

## Setup Instructions

### 1. Create Xcode Project

1. Open Xcode 15+
2. File → New → Project
3. Select **App** template
4. Configuration:
   - Product Name: `PhotoCoachPro`
   - Team: Your team
   - Organization Identifier: Your identifier
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **SwiftData**
   - Platforms: **iOS 17+, macOS 14+**

### 2. Add Source Files

1. Delete the default `ContentView.swift` created by Xcode
2. Add all files from this `PhotoCoachPro/` directory to your Xcode project
3. Ensure folder references match the structure above

### 3. Configure Info.plist

Add these privacy keys to `Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo Coach Pro needs access to import photos for editing.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>Photo Coach Pro can save edited photos to your library.</string>

<key>NSCameraUsageDescription</key>
<string>Photo Coach Pro can capture photos with live coaching.</string>
```

### 4. Configure Capabilities

In Xcode target settings:
- **Signing & Capabilities** → Enable **App Sandbox** (macOS)
- Enable **Photo Library** access
- Enable **File Access** for import/export

### 5. Build and Run

**iOS**: Select iPhone or iPad simulator
**macOS**: Select My Mac

Press **⌘R** to build and run.

## How to Use (Phase 1)

### Import Photos
1. Tap **Import** button (+ icon)
2. Select photo from library
3. Photo appears in grid

### Edit Photos
1. Tap photo thumbnail
2. Editor opens with image canvas
3. Use tool tabs: Basic, Color, Detail, Effects
4. Adjust sliders in real-time
5. Tap **Undo/Redo** to navigate history
6. Tap **Done** to return to library

### Export Photos
Currently manual (Phase 1):
- Call `appState.exportCurrent(to: url, preset: .web)` programmatically
- Full export UI coming in Phase 4

## Code Quality Features

✅ **Zero Force Unwraps**: All optionals handled safely
✅ **Zero Force Try**: All throws handled with do-catch
✅ **Actor Isolation**: All image processing on background actors
✅ **Protocol-Driven**: All engines conform to protocols
✅ **60fps Rendering**: CIImage lazy evaluation with Metal
✅ **Accessibility**: VoiceOver labels, Dynamic Type, Reduce Motion

## Performance

- **Editor Render**: Real-time (< 16ms target, actual depends on device)
- **Thumbnail Cache**: LRU cache with 200 item limit
- **Image Loading**: Async/await with proper memory management
- **SwiftData**: Background context for writes

## Privacy Guarantees

✅ **100% On-Device**: No network requests for image data
✅ **Local Storage**: All photos stored in app's Documents directory
✅ **Metadata Control**: Can strip EXIF/GPS on export
✅ **No Analytics**: No image content transmitted anywhere

## Next Phases

### Phase 2: RAW + Masking
- RAW processing via CIRAWFilter
- Auto masking (Vision framework)
- Manual brush masking
- Tone curves, HSL mixer
- Advanced geometry tools

### Phase 3: AI Coaching
- Photo critique engine
- Skill tracking
- Weekly practice plans

### Phase 4: Batch + Export
- Multi-photo editing
- Batch consistency checking
- Professional export presets

### Phase 5: Advanced Processing
- Panorama stitching
- HDR merge
- AI upscaling
- Print preparation

### Phase 6: Live Coach
- Real-time camera feedback
- Practice mode
- Guided sessions

## Technical Notes

### Color Spaces
- **Import**: Preserves original color space
- **Editing**: Works in Display P3 (configurable to ProPhoto RGB)
- **Export**: Converts to sRGB for web, preserves for print

### Edit Stack Format
All edits stored as `EditInstruction` (Codable):
- Type-safe enum for operations
- Value ranges enforced at compile time
- Undo/redo via index pointer
- Branch-ready architecture

### Image Pipeline
```
URL → ImageLoader → CIImage → EditGraphEngine → ImageRenderer → Display
                                     ↓
                              ThumbnailCache
```

### SwiftData Schema
- `PhotoRecord`: File reference + metadata snapshot
- `EditRecord`: Edit graph + instruction stack
- Relationship: PhotoRecord ← EditRecord (1:1)

## Requirements

- **iOS 17.0+** or **macOS 14.0+**
- **Xcode 15.0+**
- **Swift 5.9+**
- **SwiftUI + SwiftData**

## Architecture Decisions

### Why Actors?
All image processing happens on background actors to never block the main thread. This ensures 60fps UI even during heavy edits.

### Why CIImage?
Core Image provides lazy evaluation — filters compose without rendering until final display. This enables real-time preview of complex edit stacks.

### Why SwiftData?
Modern, type-safe persistence with automatic migration support. Codable edit instructions persist cleanly as JSON blobs.

### Why No Dependencies?
Privacy-first means trusting only Apple frameworks. No third-party SDKs means no unexpected data transmission.

## License

Copyright © 2024 Photo Coach Pro. All rights reserved.

---

**Phase 1 Milestone**: ✅ Can import a photo, make non-destructive edits, undo/redo, and see results in real time.
