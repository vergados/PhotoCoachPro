# Print Size Dropdown Feature

## Overview

Replaced the manual upscaling factor slider with a smart print size dropdown that automatically calculates the required upscaling based on your target print size and quality level.

## What Changed

### Old Approach
- Select upscaling factor (2×, 3×, 4×, 8×)
- Guess what print sizes would be possible
- See results after upscaling

### New Approach
- Select exact print size you want (4×6, 8×10, 24×36, etc.)
- Select quality level (150-600 DPI)
- App calculates required upscaling automatically
- See requirements before upscaling

---

## Print Size Categories

The dropdown organizes sizes into 6 categories:

### 1. Wallet & Small
- 2.5×3.5" (wallet)
- 3×5"
- 4×6"
- 5×7"

### 2. Standard
- 8×10"
- 8.5×11" (letter)
- 9×12"
- 10×13"
- 11×14"
- 12×16"
- 12×18"

### 3. Large
- 16×20"
- 16×24"
- 18×24"
- 20×24"
- 20×30"

### 4. Large Format
- 24×30"
- 24×36"
- 30×40"
- 30×45"
- 40×50"
- 40×60"

### 5. Panoramic
- 8×24" (3:1 ratio)
- 10×30" (3:1 ratio)
- 12×36" (3:1 ratio)

### 6. Panoramic Large Format
- 20×60" (3:1 ratio)
- 30×90" (3:1 ratio)

---

## Quality Levels (DPI)

**150 DPI - Poster Quality**
- Large prints viewed from distance
- Acceptable quality for posters/banners
- Budget-friendly option

**240 DPI - Good Quality**
- Standard photo prints
- Photo books
- Normal viewing distance

**300 DPI - Professional** ⭐️
- Gallery-quality prints
- Professional photography
- Close viewing distance
- **Recommended for most prints**

**600 DPI - Fine Art**
- Archival/museum quality
- Extreme detail preservation
- Fine art reproductions

---

## How It Works

### Smart Calculation

The app automatically calculates:

```
Required Pixels = Print Size (inches) × Target DPI

Example:
- Print Size: 24×36"
- Target DPI: 300
- Required Pixels: 7200 × 10800

If your image is:
- 3600 × 5400 → Needs 2× upscaling
- 7200 × 10800 → Already perfect, no upscaling
- 1800 × 2700 → Needs 4× upscaling
```

### Aspect Ratio Matching

The app warns you if your image's aspect ratio doesn't match the selected print size:

**Example**:
- Image: 3000×2000 (3:2 ratio)
- Print: 8×10 (4:5 ratio)
- Warning: ⚠️ "Aspect ratio mismatch - image will be cropped"

This helps you choose compatible sizes or know when cropping will occur.

### No Upscaling Needed

If your image is already large enough for the selected print size and quality:
- Shows ✓ "Image is already large enough"
- Scale factor shows 1.00×
- Upscaling still processes (for method consistency) but doesn't enlarge

---

## User Interface

### Controls Panel (New Layout)

```
┌─────────────────────────────────────────┐
│ Original Image                          │
│ 3000 × 2000 pixels                      │
│ Good quality                            │
├─────────────────────────────────────────┤
│ Print Size Category                     │
│ [Standard ▼]                            │
├─────────────────────────────────────────┤
│ Target Print Size                       │
│ [8×10" ▼]                               │
│ ⚠️ Aspect ratio mismatch - cropped      │
├─────────────────────────────────────────┤
│ Target Quality (DPI)                    │
│                         300 DPI         │
│ [150|240|300|600]                       │
│ Professional/gallery quality            │
├─────────────────────────────────────────┤
│ Required Upscaling         2.67×        │
│ Output Size   8000 × 5333 pixels        │
├─────────────────────────────────────────┤
│ Upscaling Method                        │
│ [Lanczos|Bicubic|Bilinear]             │
│ Lanczos resampling (best quality)      │
├─────────────────────────────────────────┤
│      [🖨️ Upscale to Print Size]         │
└─────────────────────────────────────────┘
```

---

## Workflow

### Step-by-Step

1. **Select Photo** (left panel)
   - Click any photo from your library
   - Original dimensions shown

2. **Choose Category** (dropdown)
   - Wallet & Small
   - Standard
   - Large
   - Large Format
   - Panoramic
   - Panoramic Large Format

3. **Select Print Size** (dropdown)
   - Only shows sizes in selected category
   - Organized by common standards

4. **Set Quality** (segmented picker)
   - 150 DPI (Poster)
   - 240 DPI (Good)
   - 300 DPI (Professional) ⭐️
   - 600 DPI (Fine Art)

5. **Review Requirements**
   - See calculated upscaling factor
   - See output dimensions
   - Check for aspect ratio warnings

6. **Choose Method**
   - Lanczos (recommended)
   - Bicubic
   - Bilinear

7. **Click "Upscale to Print Size"**
   - Processing begins
   - Preview appears when done

8. **Review & Save**
   - Check quality in preview
   - See actual print sizes possible
   - Save to library

---

## Console Output

When upscaling, you'll see:

```
🖨️ Upscaling for print:
  Target: 24×36" at 300 DPI
  Scale: 2.40×
  Output: 7200 × 4800 pixels
```

Or if no upscaling needed:

```
🖨️ Upscaling for print:
  Target: 4×6" at 300 DPI
  Scale: 1.00×
  Output: 3000 × 2000 pixels
  ✓ No upscaling needed - image already large enough
```

---

## Technical Details

### Code Structure

**New Types**:
- `PrintSizeCategory` enum (6 categories)
- `UpscalingPrintSize` struct (29 standard sizes)
  - Renamed from `PrintSize` to avoid conflict with existing export module

**New State Variables**:
- `selectedPrintSize: UpscalingPrintSize`
- `targetDPI: Double` (150/240/300/600)
- `selectedCategory: PrintSizeCategory`

**Removed**:
- `scaleFactor: Double` slider (now calculated automatically)

**New Functions**:
- `calculateUpscalingRequirements()` - Main calculation logic
- `estimateCurrentPrintDPI()` - Quality estimate for original
- `dpiDescription()` - Helper for quality descriptions

**Modified Functions**:
- `upscaleImage()` - Now calculates scale from print size + DPI
- `controlsPanel` - Complete redesign with new UI

### Calculation Formula

```swift
requiredWidth = printSize.widthInches × targetDPI
requiredHeight = printSize.heightInches × targetDPI

scaleX = requiredWidth / currentWidth
scaleY = requiredHeight / currentHeight

scaleFactor = max(scaleX, scaleY, 1.0) // Never scale down

outputWidth = Int(currentWidth × scaleFactor)
outputHeight = Int(currentHeight × scaleFactor)
```

### Files Modified

**Single File**:
- `PhotoCoachPro/UI/Upscaling/DPIUpscalingView.swift`
  - Added ~150 lines (print size definitions)
  - Modified ~100 lines (controls panel)
  - Updated ~30 lines (upscale function)

---

## Benefits

✅ **Print-First Workflow** - Choose your target, not a random multiplier
✅ **Smart Calculation** - No math needed, app does it for you
✅ **Quality Assurance** - DPI selector ensures proper print quality
✅ **Aspect Ratio Safety** - Warns about mismatches before upscaling
✅ **Professional Standards** - All industry-standard print sizes
✅ **Panoramic Support** - Dedicated categories for wide formats
✅ **Visual Feedback** - See requirements before processing
✅ **No Guesswork** - Know exactly what you're getting

---

## Testing

### Test Scenarios

**1. Small Image (1000×667)**:
- Select: 8×10" at 300 DPI
- Shows: 3.60× upscaling needed
- Output: 3600×2400 pixels

**2. Medium Image (3000×2000)**:
- Select: 8×10" at 300 DPI
- Shows: Aspect ratio warning (3:2 vs 4:5)
- Scale: 1.20× needed

**3. Large Image (6000×4000)**:
- Select: 16×20" at 300 DPI
- Shows: 1.00× (already large enough)
- Checkmark: No upscaling needed

**4. Panoramic (6000×2000, 3:1 ratio)**:
- Select: 30×90" at 150 DPI
- Perfect match for panoramic
- Scale: 2.25× needed

---

## Future Enhancements

Potential improvements:
- [ ] Custom print size input
- [ ] Crop preview for mismatched aspect ratios
- [ ] Recommended sizes based on image aspect ratio
- [ ] Export with embedded DPI metadata
- [ ] Print cost estimator
- [ ] Paper type recommendations

---

**Created**: 2026-02-14
**Author**: Claude (via Jason E Alaounis)
**Company**: ALÁON
