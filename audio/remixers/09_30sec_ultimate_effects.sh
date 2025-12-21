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

# Output settings
OUTPUT_PREFIX="30sec_ultimate"
SEQUENCE_DURATION=30
NUM_SEQUENCES=10

# Find all audio files
echo "Finding audio files..."
mapfile -t audio_files < <(find . -maxdepth 1 -type f \( -iname "*.ogg" -o -iname "*.wav" -o -iname "*.mp3" \) | sort)

if [ ${#audio_files[@]} -eq 0 ]; then
    echo "No audio files found."
    exit 1
fi

echo "Found ${#audio_files[@]} audio files - will use ALL of them in each mix!"
echo

# Function to convert any audio to standard format
standardize_audio() {
    local input="$1"
    local output="$2"
    ffmpeg -i "$input" -acodec pcm_s16le -ar 44100 -ac 2 "$output" -y 2>/dev/null
}

# Function to extract random segment with effect
extract_segment() {
    local input_file="$1"
    local output_file="$2"
    local seg_duration="$3"
    local effect="$4"
    
    # Get file duration
    duration=$(ffmpeg -i "$input_file" 2>&1 | grep "Duration" | cut -d ' ' -f 4 | sed s/,// | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
    duration=$(echo "$duration" | cut -d'.' -f1)
    
    # Random start position
    seg_duration_int=$(echo "$seg_duration" | cut -d'.' -f1)
    if [ -z "$seg_duration_int" ] || [ "$seg_duration_int" -eq 0 ]; then
        seg_duration_int=1
    fi
    
    if [ -n "$duration" ] && [ "$duration" -gt "$seg_duration_int" ]; then
        max_start=$((duration - seg_duration_int))
        start=$(echo "scale=2; $RANDOM/32768 * $max_start" | bc)
    else
        start=0
    fi
    
    # Extract and apply effect
    temp_extract="temp_extract_$$.wav"
    ffmpeg -ss $start -i "$input_file" -t $seg_duration -acodec pcm_s16le -ar 44100 -ac 2 "$temp_extract" -y 2>/dev/null
    
    if [ ! -f "$temp_extract" ]; then
        return 1
    fi
    
    # Apply sox effect
    case $effect in
        0) # Clean with fade
            sox "$temp_extract" "$output_file" fade 0.2
            ;;
        1) # Pitch shift up
            sox "$temp_extract" "$output_file" pitch 300 fade 0.2
            ;;
        2) # Pitch shift down
            sox "$temp_extract" "$output_file" pitch -300 fade 0.2
            ;;
        3) # Reverse
            sox "$temp_extract" "$output_file" reverse fade 0.2
            ;;
        4) # Echo
            sox "$temp_extract" "$output_file" echo 0.8 0.88 60 0.4 fade 0.2
            ;;
        5) # Flanger
            sox "$temp_extract" "$output_file" flanger fade 0.2
            ;;
        6) # Reverb
            sox "$temp_extract" "$output_file" reverb 80 fade 0.2
            ;;
        7) # Tremolo
            sox "$temp_extract" "$output_file" tremolo 6 40 fade 0.2
            ;;
    esac
    
    rm -f "$temp_extract"
    return 0
}

echo "Creating $NUM_SEQUENCES 30-second mixes..."

for seq_num in $(seq 1 $NUM_SEQUENCES); do
    echo
    echo "=== Creating sequence $seq_num ==="
    
    # Create base 30-second track
    base_track="base_${seq_num}.wav"
    sox -n -r 44100 -c 2 "$base_track" synth 30 whitenoise vol 0.001
    
    # Track segments for this sequence
    segment_count=0
    
    # Process each file
    for i in "${!audio_files[@]}"; do
        file="${audio_files[$i]}"
        base_name=$(basename "$file")
        
        # Each file contributes 1-3 segments
        num_segments=$((1 + RANDOM % 3))
        
        echo -n "  Processing $base_name: "
        
        for seg in $(seq 1 $num_segments); do
            # Random parameters
            seg_duration=$(echo "scale=1; 1 + $RANDOM/32768 * 4" | bc)
            effect=$((RANDOM % 8))
            volume=$(echo "scale=2; 0.1 + $RANDOM/32768 * 0.5" | bc)
            position=$(echo "scale=1; $RANDOM/32768 * 25" | bc)
            
            # Extract segment
            seg_file="seg_${seq_num}_${i}_${seg}.wav"
            if extract_segment "$file" "$seg_file" "$seg_duration" "$effect"; then
                # Apply volume
                vol_file="vol_${seq_num}_${i}_${seg}.wav"
                sox "$seg_file" "$vol_file" vol $volume
                
                # Mix into base track at position
                temp_mix="temp_mix_${seq_num}.wav"
                sox -m "$base_track" "|sox $vol_file -p pad $position" "$temp_mix"
                mv "$temp_mix" "$base_track"
                
                # Cleanup
                rm -f "$seg_file" "$vol_file"
                
                ((segment_count++))
                echo -n "."
            fi
        done
        echo " done"
    done
    
    # Final processing
    output_file=$(printf "%s_%02d.wav" "$OUTPUT_PREFIX" "$seq_num")
    echo "  Finalizing with $segment_count segments..."
    
    # Normalize, compress, ensure exactly 30 seconds
    sox "$base_track" "$output_file" \
        compand 0.1,0.3 -60,-60,-30,-15,-20,-12,0,-8 5 \
        norm -3 \
        fade 0.5 30 0.5 \
        trim 0 30
    
    # Cleanup
    rm -f "$base_track"
    
    # Verify
    duration=$(soxi -D "$output_file" 2>/dev/null || echo "unknown")
    echo "  Created: $output_file (${duration}s, $segment_count segments)"
done

echo
echo "Done! Created $NUM_SEQUENCES 30-second mixes:"
ls -la ${OUTPUT_PREFIX}_*.wav

# Verification
echo
echo "Duration verification:"
for f in ${OUTPUT_PREFIX}_*.wav; do
    if [ -f "$f" ]; then
        duration=$(soxi -D "$f" 2>/dev/null || echo "error")
        echo "  $f: ${duration}s"
    fi
done