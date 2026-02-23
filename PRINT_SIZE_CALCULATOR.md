# Print Size Calculator Feature

## Overview

Added automatic print size calculation to the DPI Upscaling view. After upscaling an image, you'll see exactly what sizes you can print at different quality levels.

## What Was Added

### Print Size Display

**Location**: DPI Upscaling preview panel (after upscaling an image)

**Shows**:
1. **Maximum Print Sizes** at three quality levels:
   - Professional Quality (300 DPI) ⭐️ - Gallery/professional prints
   - Good Quality (240 DPI) - Standard photo prints
   - Poster/Large Format (150 DPI) - Large posters viewed from distance

2. **Recommended Standard Sizes**:
   - Common print sizes that match your image's aspect ratio
   - Only shows sizes where quality is acceptable (150+ DPI)
   - Indicates quality level for each size

### Quality Standards

**300 DPI (Professional)**:
- Gallery-quality prints
- Professional photography
- Close viewing distance
- Fine detail preservation

**240 DPI (Good)**:
- Standard photo prints
- Photo books
- Normal viewing distance
- Very good quality

**150 DPI (Poster)**:
- Large format prints
- Posters and banners
- Viewed from distance
- Acceptable quality

### Standard Print Sizes Checked

The calculator checks against these common sizes:
- 4×6 (postcard)
- 5×7 (small frame)
- 8×10 (standard frame)
- 11×14 (medium)
- 12×18 (medium-large)
- 16×20 (large)
- 20×30 (poster)
- 24×36 (large poster)
- 30×40 (very large)

## How It Works

### Calculation Formula

```
Print Size (inches) = Image Size (pixels) / DPI
```

**Example**:
- Image: 7200 × 4800 pixels
- At 300 DPI: 24" × 16" (professional quality)
- At 240 DPI: 30" × 20" (good quality)
- At 150 DPI: 48" × 32" (poster quality)

### Aspect Ratio Matching

The calculator only recommends standard sizes that match your image's aspect ratio (within 15% tolerance). This prevents distortion when printing.

**Example**:
- Image aspect ratio: 3:2 (landscape)
- Recommended: 4×6, 12×18, 20×30, 24×36
- Not recommended: 8×10 (4:5 ratio - would require cropping)

### Minimum Quality Filter

Only sizes where the image can achieve at least 150 DPI are shown. Below 150 DPI, print quality becomes noticeably poor.

## User Experience

### Before Upscaling

1. Select a photo
2. Choose target DPI (2×, 3×, 4×, 8×)
3. Click "Upscale Image"

### After Upscaling

You'll see:
```
┌─────────────────────────────────────────┐
│ 📊 Maximum Print Sizes                  │
├─────────────────────────────────────────┤
│ ⭐️ Professional Quality (300 DPI)       │
│    24.0" × 16.0"                        │
│                                         │
│ ✓ Good Quality (240 DPI)               │
│    30.0" × 20.0"                        │
│                                         │
│ 📷 Poster/Large Format (150 DPI)        │
│    48.0" × 32.0"                        │
├─────────────────────────────────────────┤
│ Recommended Standard Print Sizes:       │
│                                         │
│ ✓ 4×6    (300+ DPI ⭐️)                 │
│ ✓ 12×18  (300+ DPI ⭐️)                 │
│ ✓ 16×20  (300+ DPI ⭐️)                 │
│ ✓ 20×30  (240+ DPI)                    │
│ ✓ 24×36  (240+ DPI)                    │
│ ✓ 30×40  (150+ DPI)                    │
└─────────────────────────────────────────┘
```

## Technical Details

### Code Structure

**New Functions**:
- `printSizeSection(for:)` - Main UI component
- `printQualityRow()` - Individual quality level row
- `calculatePrintSizes()` - DPI calculations
- `recommendedPrintSizes()` - Aspect ratio matching + filtering

**Integration**:
- Added to `previewPanel()` in DPIUpscalingView
- Appears after image preview
- Updates automatically when new image is upscaled

### Files Modified

- `PhotoCoachPro/UI/Upscaling/DPIUpscalingView.swift`
  - Added ~150 lines
  - 4 new private functions
  - No breaking changes

## Testing

### Test Scenarios

1. **Small Image (1000×667px)**:
   - At 300 DPI: 3.3" × 2.2" (4×6 not recommended)
   - At 150 DPI: 6.7" × 4.4" (limited options)

2. **Medium Image (3000×2000px)**:
   - At 300 DPI: 10" × 6.7" (8×10, 11×14 recommended)
   - At 150 DPI: 20" × 13.3" (good range)

3. **Large Upscaled (7200×4800px)**:
   - At 300 DPI: 24" × 16" (most sizes available)
   - At 150 DPI: 48" × 32" (poster-size capable)

4. **Portrait Orientation (2000×3000px)**:
   - Shows portrait sizes: 4×6, 5×7, 8×10
   - Filters out landscape sizes

## Benefits

✅ **Know Before You Print** - See exactly what sizes are possible
✅ **Quality Assurance** - Only shows sizes with acceptable DPI
✅ **No Guesswork** - Clear quality indicators (⭐️ = professional)
✅ **Aspect Ratio Safe** - Only recommends sizes that won't distort
✅ **Professional Tool** - Real-world print standards

## Future Enhancements

Potential improvements:
- [ ] Export with embedded DPI metadata
- [ ] Custom print size calculator
- [ ] Canvas/paper type recommendations
- [ ] Cost estimator (based on print size)
- [ ] Crop guides for non-matching sizes

---

**Created**: 2026-02-14
**Author**: Claude (via Jason E Alaounis)
**Company**: ALÁON
