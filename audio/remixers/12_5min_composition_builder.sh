#!/bin/bash

# Check dependencies
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed."
    exit 1
fi

if ! command -v sox &> /dev/null; then
    echo "Error: sox is not installed."
    exit 1
fi

if ! command -v bc &> /dev/null; then
    echo "Error: bc is not installed."
    exit 1
fi

# Settings
OUTPUT_PREFIX="5min_composition"
TRACK_DURATION=300  # 5 minutes
NUM_TRACKS=5

# Track structure timing (in seconds)
INTRO_DURATION=30
BUILD1_DURATION=60
BREAK1_DURATION=20
BUILD2_DURATION=80
CLIMAX_DURATION=60
BREAK2_DURATION=20
OUTRO_DURATION=30

# Find all audio files
echo "Finding audio files..."
mapfile -t audio_files < <(find . -maxdepth 1 -type f \( -iname "*.ogg" -o -iname "*.wav" -o -iname "*.mp3" \) ! -name "30sec_*.wav" ! -name "5min_*.wav" ! -name "temp_*.wav" | sort)

if [ ${#audio_files[@]} -eq 0 ]; then
    echo "No audio files found."
    exit 1
fi

echo "Found ${#audio_files[@]} audio files"
echo

# Function to get file duration
get_duration() {
    local file="$1"
    local duration=$(ffmpeg -i "$file" 2>&1 | grep Duration | awk '{print $2}' | tr -d , | awk -F: '{print int(($1*3600)+($2*60)+$3)}')
    if [ -z "$duration" ] || [ "$duration" -eq 0 ]; then
        echo "10"
    else
        echo "$duration"
    fi
}

# Function to extract and process segment
extract_segment() {
    local input="$1"
    local output="$2"
    local start="$3"
    local duration="$4"
    local volume="$5"
    local effect="$6"
    
    # Extract
    temp_extract="temp_extract_$$.wav"
    ffmpeg -ss "$start" -i "$input" -t "$duration" -acodec pcm_s16le -ar 44100 -ac 2 "$temp_extract" -y 2>/dev/null
    
    if [ ! -f "$temp_extract" ]; then
        return 1
    fi
    
    # Apply effect
    case "$effect" in
        "clean")
            sox "$temp_extract" "$output" vol "$volume" fade 0.5
            ;;
        "reverb")
            sox "$temp_extract" "$output" reverb 80 vol "$volume" fade 0.5
            ;;
        "delay")
            sox "$temp_extract" "$output" echo 0.8 0.9 1000 0.3 echo 0.8 0.7 60 0.25 vol "$volume" fade 0.5
            ;;
        "filter_low")
            sox "$temp_extract" "$output" lowpass 500 vol "$volume" fade 0.5
            ;;
        "filter_high")
            sox "$temp_extract" "$output" highpass 2000 vol "$volume" fade 0.5
            ;;
        "pitch_up")
            sox "$temp_extract" "$output" pitch 400 vol "$volume" fade 0.5
            ;;
        "pitch_down")
            sox "$temp_extract" "$output" pitch -300 vol "$volume" fade 0.5
            ;;
        "reverse")
            sox "$temp_extract" "$output" reverse vol "$volume" fade 0.5
            ;;
        "stutter")
            sox "$temp_extract" "$output" repeat 4 trim 0 0.125 vol "$volume"
            ;;
        "phaser")
            sox "$temp_extract" "$output" phaser 0.8 0.74 3 0.4 0.5 vol "$volume" fade 0.5
            ;;
    esac
    
    rm -f "$temp_extract"
    [ -f "$output" ]
}

# Function to create a section
create_section() {
    local section_name="$1"
    local section_duration="$2"
    local density="$3"  # low, medium, high
    local energy="$4"  # low, medium, high
    local track_num="$5"
    
    echo "    Creating $section_name section (${section_duration}s, density: $density, energy: $energy)..."
    
    local section_file="temp_section_${track_num}_${section_name}.wav"
    local layer_files=()
    
    # Determine number of layers based on density
    case "$density" in
        "low") num_layers=$((2 + RANDOM % 2)) ;;
        "medium") num_layers=$((4 + RANDOM % 3)) ;;
        "high") num_layers=$((7 + RANDOM % 4)) ;;
    esac
    
    # Create layers
    for layer in $(seq 1 $num_layers); do
        # Select random file
        file="${audio_files[$((RANDOM % ${#audio_files[@]}))]}"
        duration=$(get_duration "$file")
        
        # Determine layer characteristics based on energy
        case "$energy" in
            "low")
                volume=$(echo "scale=2; 0.1 + $RANDOM/32768 * 0.3" | bc)
                effects=("filter_low" "reverb" "pitch_down")
                segment_duration=$((15 + RANDOM % 20))
                ;;
            "medium")
                volume=$(echo "scale=2; 0.3 + $RANDOM/32768 * 0.3" | bc)
                effects=("clean" "reverb" "delay" "filter_high")
                segment_duration=$((8 + RANDOM % 15))
                ;;
            "high")
                volume=$(echo "scale=2; 0.4 + $RANDOM/32768 * 0.4" | bc)
                effects=("clean" "pitch_up" "stutter" "phaser" "delay")
                segment_duration=$((3 + RANDOM % 10))
                ;;
        esac
        
        # Select effect
        effect="${effects[$((RANDOM % ${#effects[@]}))]}"
        
        # Create multiple segments for this layer
        layer_segments=()
        total_created=0
        
        while [ $total_created -lt $section_duration ]; do
            if [ $segment_duration -gt $duration ]; then
                segment_duration=$duration
            fi
            
            # Ensure minimum segment duration
            if [ $segment_duration -lt 2 ]; then
                segment_duration=2
            fi
            
            start=$((RANDOM % (duration - segment_duration + 1)))
            seg_file="temp_seg_${track_num}_${section_name}_${layer}_${total_created}.wav"
            
            if extract_segment "$file" "$seg_file" "$start" "$segment_duration" "$volume" "$effect"; then
                layer_segments+=("$seg_file")
                total_created=$((total_created + segment_duration - 2))  # Overlap by 2 seconds
            fi
        done
        
        # Concatenate segments for this layer
        if [ ${#layer_segments[@]} -gt 0 ]; then
            layer_file="temp_layer_${track_num}_${section_name}_${layer}.wav"
            if [ ${#layer_segments[@]} -eq 1 ]; then
                sox "${layer_segments[0]}" "$layer_file" pad 0 $section_duration trim 0 $section_duration
            else
                sox "${layer_segments[@]}" "$layer_file" splice -q
                sox "$layer_file" temp_trim.wav trim 0 $section_duration
                mv temp_trim.wav "$layer_file"
            fi
            layer_files+=("$layer_file")
            rm -f "${layer_segments[@]}"
        fi
    done
    
    # Mix all layers
    if [ ${#layer_files[@]} -gt 0 ]; then
        if [ ${#layer_files[@]} -eq 1 ]; then
            cp "${layer_files[0]}" "$section_file"
        else
            sox -m "${layer_files[@]}" "$section_file" norm -3
        fi
        rm -f "${layer_files[@]}"
    else
        # Create silence if no layers
        sox -n -r 44100 -c 2 "$section_file" trim 0 $section_duration
    fi
    
    echo "$section_file"
}

# Function to create transition
create_transition() {
    local from_file="$1"
    local to_file="$2"
    local output="$3"
    local duration="$4"
    
    # Create crossfade
    sox "$from_file" temp_fade_out.wav fade t 0 0 $duration
    sox "$to_file" temp_fade_in.wav fade t $duration
    sox -m temp_fade_out.wav temp_fade_in.wav "$output"
    rm -f temp_fade_out.wav temp_fade_in.wav
}

echo "Creating $NUM_TRACKS 5-minute compositions..."

for track in $(seq 1 $NUM_TRACKS); do
    echo
    echo "=== Creating composition $track ==="
    
    sections=()
    
    # 1. INTRO (30s) - Low density, low energy
    intro_file=$(create_section "intro" $INTRO_DURATION "low" "low" $track)
    sections+=("$intro_file")
    
    # 2. BUILD 1 (60s) - Medium density, gradually increasing energy
    build1_file=$(create_section "build1" $BUILD1_DURATION "medium" "medium" $track)
    sections+=("$build1_file")
    
    # 3. BREAK 1 (20s) - Low density, low energy
    break1_file=$(create_section "break1" $BREAK1_DURATION "low" "low" $track)
    sections+=("$break1_file")
    
    # 4. BUILD 2 (80s) - High density, high energy
    build2_file=$(create_section "build2" $BUILD2_DURATION "high" "high" $track)
    sections+=("$build2_file")
    
    # 5. CLIMAX (60s) - High density, maximum energy
    climax_file=$(create_section "climax" $CLIMAX_DURATION "high" "high" $track)
    sections+=("$climax_file")
    
    # 6. BREAK 2 (20s) - Low density, medium energy
    break2_file=$(create_section "break2" $BREAK2_DURATION "low" "medium" $track)
    sections+=("$break2_file")
    
    # 7. OUTRO (30s) - Medium density, low energy
    outro_file=$(create_section "outro" $OUTRO_DURATION "medium" "low" $track)
    sections+=("$outro_file")
    
    # Concatenate all sections with smooth transitions
    echo "    Assembling final composition..."
    
    output_file=$(printf "%s_%02d.wav" "$OUTPUT_PREFIX" $track)
    
    # Join all sections
    sox "${sections[@]}" temp_joined_$track.wav
    
    # Apply final mastering
    sox temp_joined_$track.wav "$output_file" \
        compand 0.3,1 6:-70,-60,-20 -5 -90 0.2 \
        equalizer 100 0.7q +3 \
        equalizer 1000 0.7q +1 \
        equalizer 10000 0.7q +2 \
        norm -1 \
        fade 2 300 3
    
    # Cleanup
    rm -f "${sections[@]}" temp_joined_$track.wav
    
    # Verify
    duration=$(soxi -D "$output_file" 2>/dev/null || echo "unknown")
    size=$(du -h "$output_file" | cut -f1)
    echo "    Created: $output_file (${duration}s, $size)"
    echo "    Structure: Intro(30s) → Build1(60s) → Break1(20s) → Build2(80s) → Climax(60s) → Break2(20s) → Outro(30s)"
done

# Cleanup any remaining temp files
rm -f temp_*.wav

echo
echo "Done! Created $NUM_TRACKS 5-minute compositions:"
ls -la ${OUTPUT_PREFIX}_*.wav

# Display structure
echo
echo "Each track follows this structure:"
echo "  0:00-0:30   - Intro (ambient, sparse)"
echo "  0:30-1:30   - Build 1 (increasing energy)"
echo "  1:30-1:50   - Break 1 (tension release)"
echo "  1:50-3:10   - Build 2 (high energy)"
echo "  3:10-4:10   - Climax (peak energy)"
echo "  4:10-4:30   - Break 2 (cooling down)"
echo "  4:30-5:00   - Outro (fade out)"