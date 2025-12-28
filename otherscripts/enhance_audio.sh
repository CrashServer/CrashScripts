#!/bin/bash

# Techno Audio Enhancer for MKV files with Multiple Presets
# Usage: ./enhance_techno.sh input.mkv [output.mkv]

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${CYAN}[HEADER]${NC} $1"
}

print_detail() {
    echo -e "${MAGENTA}[DETAIL]${NC} $1"
}

# Audio enhancement presets
declare -A PRESETS
declare -A PRESET_DESCRIPTIONS

# Define presets
PRESETS["hard-techno"]="
highpass=f=25,
volume=2.8,
dynaudnorm=p=0.92:m=40:s=12:r=0.9,
anequalizer=c0 f=45 w=30 g=8|c1 f=80 w=40 g=6|c2 f=120 w=60 g=3|c3 f=400 w=200 g=-2|c4 f=800 w=300 g=-3|c5 f=1500 w=600 g=-1|c6 f=3000 w=1000 g=2|c7 f=6000 w=2000 g=5|c8 f=10000 w=3000 g=4|c9 f=14000 w=2000 g=2,
acompressor=threshold=0.08:ratio=8:attack=2:release=50:makeup=1.5,
bass=g=10:f=60:w=1.5,
treble=g=6:f=8000:w=1.2,
alimiter=level_in=1.8:level_out=0.88:limit=0.82
"

PRESETS["soft-techno"]="
highpass=f=35,
volume=2.4,
dynaudnorm=p=0.9:m=50:s=15:r=0.85,
anequalizer=c0 f=60 w=40 g=5|c1 f=120 w=80 g=3|c2 f=500 w=300 g=-1|c3 f=2000 w=800 g=1|c4 f=6000 w=2000 g=3|c5 f=12000 w=3000 g=2,
acompressor=threshold=0.125:ratio=4:attack=10:release=100:makeup=1,
bass=g=6:f=80:w=1,
treble=g=4:f=10000:w=1,
alimiter=level_in=1.5:level_out=0.9:limit=0.85
"

PRESETS["industrial"]="
highpass=f=20,
volume=3.2,
dynaudnorm=p=0.95:m=30:s=8:r=0.95,
anequalizer=c0 f=40 w=25 g=10|c1 f=90 w=50 g=8|c2 f=200 w=100 g=-4|c3 f=800 w=400 g=-5|c4 f=2000 w=1000 g=0|c5 f=4000 w=2000 g=6|c6 f=8000 w=3000 g=8|c7 f=15000 w=2000 g=3,
acompressor=threshold=0.063:ratio=12:attack=1:release=30:makeup=2,
bass=g=12:f=50:w=2,
treble=g=8:f=6000:w=1.5,
alimiter=level_in=2.2:level_out=0.85:limit=0.8
"

PRESETS["ambient-techno"]="
highpass=f=40,
volume=2.2,
dynaudnorm=p=0.85:m=80:s=25:r=0.8,
anequalizer=c0 f=80 w=60 g=3|c1 f=200 w=150 g=1|c2 f=800 w=400 g=-2|c3 f=2000 w=1000 g=2|c4 f=8000 w=4000 g=4|c5 f=12000 w=3000 g=3,
acompressor=threshold=0.2:ratio=3:attack=20:release=200:makeup=0.8,
bass=g=4:f=100:w=0.8,
treble=g=5:f=12000:w=1.5,
alimiter=level_in=1.2:level_out=0.92:limit=0.88
"

PRESETS["live-coding"]="
highpass=f=30,
volume=2.6,
dynaudnorm=p=0.88:m=60:s=18:r=0.85,
anequalizer=c0 f=50 w=35 g=6|c1 f=100 w=70 g=4|c2 f=600 w=300 g=-2|c3 f=1500 w=800 g=0|c4 f=5000 w=3000 g=4|c5 f=10000 w=4000 g=3,
acompressor=threshold=0.1:ratio=6:attack=5:release=80:makeup=1.2,
bass=g=7:f=70:w=1.2,
treble=g=5:f=8000:w=1,
alimiter=level_in=1.6:level_out=0.9:limit=0.85
"

PRESETS["minimal"]="
highpass=f=45,
volume=2.0,
dynaudnorm=p=0.82:m=100:s=30:r=0.75,
anequalizer=c0 f=80 w=50 g=2|c1 f=300 w=200 g=-1|c2 f=1000 w=500 g=0|c3 f=4000 w=2000 g=3|c4 f=10000 w=3000 g=2,
acompressor=threshold=0.25:ratio=2.5:attack=30:release=300:makeup=0.5,
bass=g=3:f=90:w=0.8,
treble=g=3:f=12000:w=1,
alimiter=level_in=1:level_out=0.95:limit=0.9
"

# Preset descriptions
PRESET_DESCRIPTIONS["hard-techno"]="Aggressive, punchy sound with heavy compression and sub-bass emphasis"
PRESET_DESCRIPTIONS["soft-techno"]="Balanced techno sound with moderate processing"
PRESET_DESCRIPTIONS["industrial"]="Dark, aggressive sound with extreme low-end and harsh highs"
PRESET_DESCRIPTIONS["ambient-techno"]="Spacious, atmospheric sound with gentle processing"
PRESET_DESCRIPTIONS["live-coding"]="Optimized for live coding sessions with variable dynamics"
PRESET_DESCRIPTIONS["minimal"]="Clean, subtle enhancement preserving original character"

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    print_error "ffmpeg is not installed. Please install it first:"
    echo "Ubuntu/Debian: sudo apt install ffmpeg"
    echo "Arch: sudo pacman -S ffmpeg"
    echo "Fedora: sudo dnf install ffmpeg"
    exit 1
fi

# Check if bc is installed (for progress calculation)
if ! command -v bc &> /dev/null; then
    print_warning "bc is not installed. Progress percentage will not be shown."
    echo "Ubuntu/Debian: sudo apt install bc"
    echo "Arch: sudo pacman -S bc"
    echo "Fedora: sudo dnf install bc"
fi

# Check arguments
if [ $# -eq 0 ]; then
    print_error "Usage: $0 input.mkv [output.mkv]"
    echo ""
    echo "Examples:"
    echo "  $0 jam_session.mkv"
    echo "  $0 jam_session.mkv custom_output.mkv"
    echo ""
    echo "If no output file is specified, it will create: input_enhanced_[preset].mkv"
    exit 1
fi

INPUT_FILE="$1"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    print_error "Input file '$INPUT_FILE' does not exist!"
    exit 1
fi

print_header "═══════════════════════════════════════════════════════"
print_header "           TECHNO AUDIO ENHANCER v2.0"
print_header "═══════════════════════════════════════════════════════"
echo ""

# Show preset selection menu
print_status "Available audio enhancement presets:"
echo ""

# Create ordered array of presets
preset_array=("hard-techno" "soft-techno" "industrial" "ambient-techno" "live-coding" "minimal")

counter=1
for preset in "${preset_array[@]}"; do
    printf "%d) ${CYAN}%-15s${NC} - %s\n" $counter "$preset" "${PRESET_DESCRIPTIONS[$preset]}"
    ((counter++))
done

echo ""
while true; do
    read -p "Select preset (1-${#preset_array[@]}): " choice
    echo ""  # Add newline after input

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#preset_array[@]}" ]; then
        SELECTED_PRESET="${preset_array[$((choice-1))]}"
        print_status "You selected: $choice"
        break
    else
        print_error "Invalid choice '$choice'. Please enter a number between 1 and ${#preset_array[@]}."
    fi
done

print_success "Selected preset: ${CYAN}$SELECTED_PRESET${NC}"
print_detail "${PRESET_DESCRIPTIONS[$SELECTED_PRESET]}"
echo ""

# Debug output
print_status "Debug: Selected preset key is '$SELECTED_PRESET'"
if [[ -n "${PRESETS[$SELECTED_PRESET]}" ]]; then
    print_status "Debug: Preset filters found successfully"
else
    print_error "Debug: No filters found for preset '$SELECTED_PRESET'"
    print_error "Available presets: ${!PRESETS[*]}"
    exit 1
fi

# Determine output filename
if [ $# -eq 2 ]; then
    OUTPUT_FILE="$2"
else
    # Create filename with preset: input_enhanced_preset.mkv
    BASENAME=$(basename "$INPUT_FILE" .mkv)
    DIRNAME=$(dirname "$INPUT_FILE")
    OUTPUT_FILE="$DIRNAME/${BASENAME}_enhanced_${SELECTED_PRESET}.mkv"
fi

# Check if output file already exists
if [ -f "$OUTPUT_FILE" ]; then
    print_warning "Output file '$OUTPUT_FILE' already exists!"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Aborted by user."
        exit 1
    fi
fi

print_status "═══════════════════════════════════════════════════════"
print_status "Processing Details:"
print_status "  Input:  $INPUT_FILE"
print_status "  Output: $OUTPUT_FILE"
print_status "  Preset: $SELECTED_PRESET"
print_status "═══════════════════════════════════════════════════════"

# Get input file info
print_status "Analyzing input file..."
INPUT_INFO=$(ffprobe -v quiet -print_format json -show_format -show_streams "$INPUT_FILE")
DURATION=$(echo "$INPUT_INFO" | grep -o '"duration":"[^"]*"' | head -1 | cut -d'"' -f4)
AUDIO_CODEC=$(echo "$INPUT_INFO" | grep -A5 '"codec_type":"audio"' | grep '"codec_name"' | head -1 | cut -d'"' -f4)
VIDEO_CODEC=$(echo "$INPUT_INFO" | grep -A5 '"codec_type":"video"' | grep '"codec_name"' | head -1 | cut -d'"' -f4)

if [ -n "$DURATION" ] && [ "$DURATION" != "N/A" ]; then
    DURATION_MIN=$(echo "scale=1; $DURATION / 60" | bc -l 2>/dev/null || echo "unknown")
    print_detail "Duration: ${DURATION_MIN} minutes"
else
    print_warning "Could not determine file duration"
    DURATION="0"
fi

print_detail "Original audio codec: $AUDIO_CODEC"
print_detail "Original video codec: $VIDEO_CODEC"
echo ""

# Get the selected audio filter
AUDIO_FILTERS="${PRESETS[$SELECTED_PRESET]}"

print_status "Starting audio enhancement with $SELECTED_PRESET preset..."
print_detail "This process will:"
print_detail "  • Copy video stream without re-encoding (fast)"
print_detail "  • Apply advanced audio filtering chain"
print_detail "  • Encode audio to high-quality AAC 320kbps"
print_detail "  • Add fast-start flag for web compatibility"
echo ""

print_status "Starting FFmpeg process..."

# Test ffmpeg command first
print_detail "Testing FFmpeg with your file..."
if ! ffprobe -v quiet "$INPUT_FILE" > /dev/null 2>&1; then
    print_error "Cannot read input file with FFmpeg. File may be corrupted."
    exit 1
fi

print_detail "File is readable. Starting enhancement..."

# Create log file for debugging
LOG_FILE=$(mktemp)
trap "rm -f $LOG_FILE" EXIT

print_status "Enhancement in progress (this will take some time)..."
print_detail "You can watch the progress below. If it seems stuck, it's probably still working!"
echo ""

# Run ffmpeg with visible output and error capture
ffmpeg -y -i "$INPUT_FILE" \
    -af "$AUDIO_FILTERS" \
    -c:v copy \
    -c:a aac \
    -b:a 320k \
    -movflags +faststart \
    "$OUTPUT_FILE" 2>&1 | while IFS= read -r line; do

    # Show frame processing info
    if [[ $line == *"frame="* ]] && [[ $line == *"time="* ]]; then
        # Extract time from ffmpeg output
        TIME_STR=$(echo "$line" | grep -o 'time=[0-9:\.]*' | cut -d'=' -f2)
        FRAME_STR=$(echo "$line" | grep -o 'frame=[[:space:]]*[0-9]*' | grep -o '[0-9]*')

        if [ -n "$TIME_STR" ] && [ -n "$FRAME_STR" ]; then
            # Convert time to seconds for percentage calculation
            if command -v bc &> /dev/null && [ "$DURATION" != "0" ] && [ -n "$DURATION" ]; then
                # Convert HH:MM:SS.ss to seconds
                IFS=':' read -ra TIME_PARTS <<< "$TIME_STR"
                if [ ${#TIME_PARTS[@]} -eq 3 ]; then
                    HOURS=${TIME_PARTS[0]#0}  # Remove leading zero
                    MINUTES=${TIME_PARTS[1]#0}
                    SECONDS=${TIME_PARTS[2]}

                    CURRENT_SEC=$(echo "scale=2; ${HOURS:-0} * 3600 + ${MINUTES:-0} * 60 + $SECONDS" | bc -l 2>/dev/null || echo "0")
                    PERCENT=$(echo "scale=1; $CURRENT_SEC * 100 / $DURATION" | bc -l 2>/dev/null || echo "0")

                    printf "\r${BLUE}[PROGRESS]${NC} %.1f%% - Frame: %s - Time: %s - Processing %s" "$PERCENT" "$FRAME_STR" "$TIME_STR" "$SELECTED_PRESET"
                else
                    printf "\r${BLUE}[PROGRESS]${NC} Frame: %s - Time: %s - Processing %s" "$FRAME_STR" "$TIME_STR" "$SELECTED_PRESET"
                fi
            else
                printf "\r${BLUE}[PROGRESS]${NC} Frame: %s - Time: %s - Processing %s" "$FRAME_STR" "$TIME_STR" "$SELECTED_PRESET"
            fi
        fi
    fi

    # Show important messages
    if [[ $line == *"error"* ]] || [[ $line == *"Error"* ]] || [[ $line == *"failed"* ]]; then
        echo ""  # New line
        print_error "FFmpeg error: $line"
        echo "$line" >> "$LOG_FILE"
    elif [[ $line == *"warning"* ]] || [[ $line == *"Warning"* ]]; then
        echo ""  # New line
        print_warning "FFmpeg warning: $line"
    fi

    # Log everything for debugging
    echo "$line" >> "$LOG_FILE"
done

FFMPEG_EXIT_CODE=$?

# Check if processing was successful
if [ $FFMPEG_EXIT_CODE -eq 0 ] && [ -f "$OUTPUT_FILE" ]; then
    echo ""  # New line after progress
    # Get file sizes for comparison
    INPUT_SIZE=$(du -h "$INPUT_FILE" | cut -f1)
    OUTPUT_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)

    print_success "Enhancement complete!"
    echo ""
    print_header "═══════════════════════════════════════════════════════"
    print_header "                    RESULTS"
    print_header "═══════════════════════════════════════════════════════"
    echo ""
    echo "📁 Files:"
    echo "   Original: $INPUT_FILE ($INPUT_SIZE)"
    echo "   Enhanced: $OUTPUT_FILE ($OUTPUT_SIZE)"
    echo ""
    echo "🎵 Applied Preset: ${CYAN}$SELECTED_PRESET${NC}"
    echo "   ${PRESET_DESCRIPTIONS[$SELECTED_PRESET]}"
    echo ""
    echo "🔧 Technical Details:"
    echo "   ✓ Video: Copied without re-encoding ($VIDEO_CODEC)"
    echo "   ✓ Audio: Enhanced and encoded to AAC 320kbps"
    echo "   ✓ Container: Optimized for streaming (faststart)"
    echo ""

    case $SELECTED_PRESET in
        "hard-techno")
            echo "🎛️  Hard Techno Enhancements:"
            echo "   ✓ Massive sub-bass boost (25-80Hz) for powerful kicks"
            echo "   ✓ Aggressive compression (8:1 ratio) for punch"
            echo "   ✓ High-frequency emphasis for crisp synths"
            echo "   ✓ Professional limiting to prevent distortion"
            ;;
        "industrial")
            echo "🎛️  Industrial Enhancements:"
            echo "   ✓ Extreme low-end emphasis for crushing bass"
            echo "   ✓ Harsh high-frequency boost for metallic sounds"
            echo "   ✓ Ultra-aggressive compression (12:1 ratio)"
            echo "   ✓ Dark, powerful sonic character"
            ;;
        "soft-techno")
            echo "🎛️  Soft Techno Enhancements:"
            echo "   ✓ Balanced frequency response"
            echo "   ✓ Moderate compression for dynamics"
            echo "   ✓ Smooth, musical character"
            ;;
        "ambient-techno")
            echo "🎛️  Ambient Techno Enhancements:"
            echo "   ✓ Spacious, atmospheric processing"
            echo "   ✓ Gentle dynamics preservation"
            echo "   ✓ Enhanced stereo imaging"
            ;;
        "live-coding")
            echo "🎛️  Live Coding Enhancements:"
            echo "   ✓ Dynamic range normalization for variable levels"
            echo "   ✓ Optimized for real-time generated content"
            echo "   ✓ Balanced enhancement preserving creativity"
            ;;
        "minimal")
            echo "🎛️  Minimal Enhancements:"
            echo "   ✓ Subtle, transparent processing"
            echo "   ✓ Original character preservation"
            echo "   ✓ Clean, professional sound"
            ;;
    esac

    echo ""
    print_success "🎉 Ready to drop some beats! Your enhanced track is ready!"
    echo ""
else
    echo ""  # New line after progress
    print_error "Enhancement failed! Exit code: $FFMPEG_EXIT_CODE"

    if [ ! -f "$OUTPUT_FILE" ]; then
        print_error "Output file was not created."
    fi

    # Show last few lines of the log for debugging
    if [ -f "$LOG_FILE" ]; then
        print_status "Last few lines from FFmpeg log:"
        echo "----------------------------------------"
        tail -n 10 "$LOG_FILE"
        echo "----------------------------------------"
        print_status "Full log saved temporarily. Check it if needed:"
        print_status "cat $LOG_FILE"
    fi

    exit 1
fi
