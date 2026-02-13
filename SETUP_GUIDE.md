# Photo Coach Pro — Complete Setup Guide

This guide walks you through setting up the Xcode project from the provided source files.

## Prerequisites

- macOS 14.0 or later
- Xcode 15.0 or later
- Apple Developer account (for device testing)

## Step-by-Step Setup

### 1. Create New Xcode Project

1. **Launch Xcode**
2. **File → New → Project** (or press **⇧⌘N**)
3. Choose template:
   - Platform: **iOS** (multiplatform support will work)
   - Template: **App**
   - Click **Next**

4. Configure project:
   ```
   Product Name: PhotoCoachPro
   Team: [Your team]
   Organization Identifier: [e.g., com.yourname]
   Interface: SwiftUI
   Language: Swift
   Storage: SwiftData
   ```
   - ✅ **Include Tests** (optional)
   - Click **Next**

5. Choose save location:
   - Select the parent directory of this README
   - Click **Create**

### 2. Replace Default Files

Xcode creates some default files. We need to replace them:

1. **Delete these default files** (right-click → Delete → Move to Trash):
   - `ContentView.swift`
   - `Item.swift` (if created)

2. **Add all source folders** to the project:
   - Drag the `PhotoCoachPro` folder from Finder into Xcode's Project Navigator
   - When prompted:
     - ✅ **Copy items if needed**
     - ✅ **Create groups**
     - ✅ Select target: **PhotoCoachPro**
   - Click **Finish**

3. **Add Info.plist**:
   - Drag `Info.plist` from Finder into the project root
   - In project settings → General → Identity:
     - Ensure **Info.plist** is selected in the dropdown

### 3. Configure Project Settings

#### A. Deployment Targets

In project settings → General:
- **iOS Deployment Target**: 17.0
- **macOS Deployment Target**: 14.0 (if multiplatform)

#### B. App Capabilities

In project settings → Signing & Capabilities:

1. Click **+ Capability**
2. Add:
   - **Photo Library** (iOS)
   - **File Access** (macOS)

#### C. Build Settings

In Build Settings, verify:
- **Swift Language Version**: Swift 5
- **Optimization Level (Debug)**: No Optimization
- **Optimization Level (Release)**: Optimize for Speed

### 4. Verify File Structure

Your project navigator should look like this:

```
PhotoCoachPro
├── PhotoCoachPro/
│   ├── App/
│   │   ├── PhotoCoachProApp.swift
│   │   └── AppState.swift
│   ├── CoreEngine/
│   │   ├── ImagePipeline/
│   │   │   ├── ImageLoader.swift
│   │   │   ├── ImageRenderer.swift
│   │   │   ├── ThumbnailCache.swift
│   │   │   └── ColorSpaceManager.swift
│   │   ├── EditGraph/
│   │   │   ├── EditInstruction.swift
│   │   │   ├── EditStack.swift
│   │   │   ├── EditBranch.swift
│   │   │   ├── EditGraphEngine.swift
│   │   │   └── EditPresets.swift
│   │   └── MetadataAnalyzer/
│   │       ├── MetadataModels.swift
│   │       └── EXIFReader.swift
│   ├── Storage/
│   │   ├── Models/
│   │   │   ├── PhotoRecord.swift
│   │   │   └── EditRecord.swift
│   │   ├── LocalDatabase.swift
│   │   ├── EditHistoryManager.swift
│   │   └── PrivacyControls/
│   │       └── PrivacySettings.swift
│   ├── UI/
│   │   ├── Home/
│   │   │   └── HomeView.swift
│   │   ├── Editor/
│   │   │   ├── EditorView.swift
│   │   │   ├── SliderControls.swift
│   │   │   └── HistogramView.swift
│   │   └── Shared/
│   │       ├── PhotoGridItem.swift
│   │       ├── LoadingOverlay.swift
│   │       ├── ErrorBanner.swift
│   │       └── AccessibilityModifiers.swift
│   └── Export/
│       └── ExportManager.swift
├── Info.plist
└── README.md
```

### 5. Build the Project

1. **Select target**:
   - iOS: Choose iPhone or iPad simulator from scheme selector
   - macOS: Choose "My Mac"

2. **Build** (**⌘B**)
   - Should complete with 0 errors

3. **Run** (**⌘R**)
   - App launches with empty library view
   - "Import" button visible

### 6. Test Basic Functionality

#### Import a Photo
1. Click **Import** button
2. Select a photo from simulator/Photos library
3. Photo appears in grid

#### Edit a Photo
1. Tap photo thumbnail
2. Editor view opens
3. Try adjusting:
   - **Basic** tab: Exposure, Contrast
   - **Color** tab: Temperature, Saturation
   - **Detail** tab: Clarity, Sharpening
4. Changes apply in real-time
5. Test **Undo** / **Redo** buttons

#### Test Persistence
1. Edit a photo
2. Tap **Done** to return to library
3. Tap photo again
4. ✅ Edits should be preserved

## Troubleshooting

### Build Errors

**"Cannot find type 'PhotoRecord' in scope"**
- Solution: Ensure all files are added to the target
- Check: File Inspector → Target Membership → ✅ PhotoCoachPro

**"Module 'SwiftData' not found"**
- Solution: Ensure deployment target is iOS 17+ / macOS 14+
- Check: Project settings → General → Deployment Info

**"Missing Info.plist"**
- Solution: Add Info.plist to project
- Check: Project settings → General → Identity → Info.plist file path

### Runtime Errors

**App crashes on launch**
- Check console for SwiftData errors
- Ensure `@main` is only on `PhotoCoachProApp`
- Verify no duplicate files

**Photo picker doesn't show**
- Check Info.plist has `NSPhotoLibraryUsageDescription`
- Verify Photos permission granted in Settings

**Images don't load**
- Check file path permissions
- Verify Documents directory is writable
- Check console for `ImageLoadError`

### Performance Issues

**Slow rendering on simulator**
- Normal on simulator (GPU acceleration limited)
- Test on real device for accurate performance

**Memory warnings**
- Ensure thumbnail cache has reasonable limit (200 items default)
- Check autoreleasepool usage in batch operations

## macOS-Specific Setup

If building for macOS:

1. **Sandbox Entitlements**:
   - Project → Signing & Capabilities → App Sandbox
   - ✅ User Selected File (Read/Write)
   - ✅ Photo Library
   - ✅ Downloads Folder (Read/Write)

2. **File Access**:
   - macOS uses file bookmarks for persistent access
   - Photos will be copied to app container

## iOS-Specific Notes

1. **Simulator vs Device**:
   - Simulator: Limited photo library, use sample images
   - Device: Full Photos access

2. **Photo Picker**:
   - iOS 17+ uses `PhotosPicker` from PhotosUI
   - No need for PHPickerViewController

## Next Steps

### Phase 1 Complete ✅
You now have:
- Working photo import
- Real-time non-destructive editing
- 20+ adjustment sliders
- Undo/redo
- SwiftData persistence

### Add RAW Support (Phase 2)
See `README.md` for Phase 2 roadmap.

### Customize
- Change app icon: Assets.xcassets → AppIcon
- Modify color scheme: Accent color in Assets
- Add custom presets: `EditPresetManager.loadDefaultPresets()`

## Support

For issues:
1. Check build logs (**⌘9** → Report Navigator)
2. Check runtime console (**⌘⇧Y** → Console)
3. Review error messages in `ErrorBanner`

## Success Checklist

✅ Project builds without errors
✅ App launches on simulator/device
✅ Can import photos
✅ Editor opens with image
✅ Sliders adjust image in real-time
✅ Undo/redo works
✅ Edits persist across sessions

---

**Setup complete! 🎉**

You now have a fully functional Phase 1 photo editor. See README.md for architecture details and next steps.
