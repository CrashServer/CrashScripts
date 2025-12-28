
## Overview
Collection of FFmpeg-based bash scripts for creating glitch art, experimental video effects, and audio enhancement. Designed for VJ sets, live coding performances, and electronic music visuals.

---

## Scripts

### 1. `extract_instagram.sh`
**Purpose**: Simple video extraction tool for social media

**What it does**:
- Extracts 86 seconds from a specific timestamp (3:20)
- Outputs Instagram-compatible MP4
- Includes commented alternatives for Stories (9:16) and Reels

**Usage**:
```bash
./extract_instagram.sh
```

**Configuration**:
Edit these variables in the script:
- `INPUT_FILE`: Source video filename
- `START_TIME`: Start timestamp (HH:MM:SS)
- `DURATION`: Length in seconds

---

### 2. `filmroll_basic.sh`
**Purpose**: Create film roll effect with RGB color separation

**What it does**:
- Generates 50-second video with 100 beat-synced cuts (120 BPM)
- Splits screen into 3 horizontal strips (red/green/blue channels)
- Each strip shows different moments with time delays
- Rotating text overlays with glitch effects
- Scene change intensification every 6 segments

**Usage**:
```bash
./filmroll_basic.sh input_video.mov
```

**Output**: `film_roll_test.mp4`

**Technical details**:
- Beat duration: 0.5s (120 BPM)
- Resolution: 1080x1920 (vertical)
- Segments: 3 horizontal strips of 1080x640
- Text rotation: Every 8 seconds

---

### 3. `filmroll_cyberpunk.sh`
**Purpose**: Enhanced film roll with cyberpunk aesthetic

**What it does**:
- Same base as filmroll_basic.sh but more aggressive
- **Separate random audio** from different video timestamps
- Three intensity modes: Mega Glitch, Medium, Normal
- Cyberpunk matrix grid overlay
- Promotional text overlay support
- Heavy shake and displacement effects

**Usage**:
```bash
./filmroll_cyberpunk.sh input_video.mov
```

**Output**: `film_roll_test.mp4`

**Key differences from basic**:
- Audio sourced randomly (not synced to video cuts)
- More extreme color grading and contrast
- Faster blink speeds and text animations
- Matrix-style visual elements

---

### 4. `datamosh_chaos.sh`
**Purpose**: Extreme multi-mode glitch art generator

**What it does**:
- 140 BPM rapid cutting (0.43s per beat)
- **5 different visual modes** cycling every segment:
  1. **SLICE MODE**: Horizontal strips with extreme shake
  2. **DATAMOSH MODE**: Multiple overlaid videos at different scales
  3. **MIRROR CHAOS**: Vertical mirroring effects
  4. **KALEIDOSCOPE**: 9-panel grid layout
  5. **TOTAL CHAOS**: 5 random-sized video layers

**Usage**:
```bash
./datamosh_chaos.sh input_video.mov
```

**Output**: `CHAOS_DATAMOSH_INSANITY.mp4`

**Warning**: Creates extremely intense visual effects - may cause seizures

**Mode details**:
- SLICE: 3 strips with 20px shake amplitude
- DATAMOSH: 4 video inputs at 540x960, 270x480
- MIRROR: Top/bottom mirrored with vflip
- KALEIDOSCOPE: 360x640 tiles in 3x3 grid
- TOTAL CHAOS: 5 inputs from 150x300 to 400x800

---

### 5. `enhance_audio.sh`
**Purpose**: Professional audio enhancement with multiple presets

**What it does**:
- Interactive preset selection menu
- Copies video without re-encoding (fast)
- Applies advanced audio processing chain
- Outputs high-quality AAC 320kbps

**Usage**:
```bash
./enhance_audio.sh input.mkv [output.mkv]
```

**Available presets**:

1. **hard-techno**: Aggressive, punchy with heavy compression
   - 8:1 compression ratio
   - +10dB bass boost at 60Hz
   - +6dB treble at 8kHz

2. **soft-techno**: Balanced, moderate processing
   - 4:1 compression ratio
   - +6dB bass boost at 80Hz
   - +4dB treble at 10kHz

3. **industrial**: Dark, extreme low-end and harsh highs
   - 12:1 compression ratio
   - +12dB bass boost at 50Hz
   - +8dB treble at 6kHz

4. **ambient-techno**: Spacious, gentle processing
   - 3:1 compression ratio
   - +4dB bass boost at 100Hz
   - +5dB treble at 12kHz

5. **live-coding**: Optimized for variable dynamics
   - 6:1 compression ratio
   - +7dB bass boost at 70Hz
   - +5dB treble at 8kHz

6. **minimal**: Clean, subtle enhancement
   - 2.5:1 compression ratio
   - +3dB bass boost at 90Hz
   - +3dB treble at 12kHz

**Processing chain**:
1. High-pass filter (removes rumble)
2. Volume adjustment
3. Dynamic normalization
4. Parametric EQ (6-9 bands)
5. Compression
6. Bass enhancement
7. Treble enhancement
8. Limiting (prevents clipping)

---

## Common Requirements

### System Requirements
- FFmpeg (with libx264, libfdk_aac or aac support)
- Bash 4.0+
- awk (for calculations)
- bc (for progress percentage in enhance_audio.sh)

### Installation (Ubuntu/Debian)
```bash
sudo apt install ffmpeg bc
```

### Installation (Arch)
```bash
sudo pacman -S ffmpeg bc
```

---

## Common Parameters Explained

### Video Processing
- **CRF (Constant Rate Factor)**: 18-23 (lower = better quality, larger file)
- **Preset**: ultrafast (processing) → medium (final output)
- **pix_fmt yuv420p**: Maximum compatibility
- **movflags +faststart**: Web streaming optimization

### Audio Processing
- **dynaudnorm**: Automatic volume leveling
- **anequalizer**: Multi-band frequency control
- **acompressor**: Dynamic range compression
- **alimiter**: Peak limiting protection

---

## Performance Tips

1. **Use ultrafast preset during segment creation** (faster processing)
2. **Switch to medium/slow for final output** (better compression)
3. **Process in /tmp or SSD** for faster I/O
4. **Monitor RAM usage** - complex modes use more memory
5. **Expect long processing times** - 50s video can take 10-30 minutes

---

## Customization Guide

### Changing BPM
```bash
# 140 BPM = 0.43s per beat
BEAT_DURATION=$(awk 'BEGIN{printf "%.2f", 60/140}')
```

### Modifying Colors
```bash
# Red channel: rr=2 (increase red)
# Green channel: gg=2 (increase green)  
# Blue channel: bb=2 (increase blue)
colorchannelmixer=rr=2:gg=0:bb=0  # Pure red
```

### Text Positioning
```bash
# Shake with sine wave
x='(1080-text_w)/2+50*sin(t*20)'  # 50px amplitude, 20 speed
y='100+30*cos(t*15)'               # 30px amplitude, 15 speed
```

---

## Troubleshooting

### "Command not found: ffmpeg"
Install FFmpeg (see requirements section)

### "Cannot read input file"
- Check file exists
- Verify file isn't corrupted
- Try: `ffprobe input_video.mov`

### "No valid segments created"
- Check input video duration is sufficient
- Verify disk space available
- Check temp directory permissions

### Blue output instead of colors
- Issue with video source or FFmpeg build
- Try different source video
- Check FFmpeg supports colorchannelmixer

### Audio out of sync
Normal for datamosh effects - audio is intentionally randomized

---

## Output Specifications

### Video
- Container: MP4
- Codec: H.264 (libx264)
- Resolution: 1080x1920 (vertical) or original
- Frame rate: Source or 30fps

### Audio
- Codec: AAC
- Bitrate: 128kbps (video scripts) or 320kbps (enhance_audio.sh)
- Sample rate: 44.1kHz or 48kHz

---
