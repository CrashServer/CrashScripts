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
OUTPUT_PREFIX="30sec_dense"
SEQUENCE_DURATION=30
NUM_SEQUENCES=10

# Find all audio files
echo "Finding audio files..."
mapfile -t audio_files < <(find . -maxdepth 1 -type f \( -iname "*.ogg" -o -iname "*.wav" -o -iname "*.mp3" \) ! -name "30sec_*.wav" ! -name "base_*.wav" | sort)

if [ ${#audio_files[@]} -eq 0 ]; then
    echo "No audio files found."
    exit 1
fi

echo "Found ${#audio_files[@]} audio files"
echo

# Function to extract segment
extract_segment() {
    local input_file="$1"
    local output_file="$2"
    local start_time="$3"
    local duration="$4"
    local effect="$5"
    local volume="$6"
    
    # Extract with ffmpeg
    temp_file="temp_extract_$$.wav"
    ffmpeg -ss "$start_time" -i "$input_file" -t "$duration" -acodec pcm_s16le -ar 44100 -ac 2 "$temp_file" -y 2>/dev/null
    
    if [ ! -f "$temp_file" ]; then
        return 1
    fi
    
    # Apply effect and volume with sox
    case $effect in
        0) sox "$temp_file" "$output_file" vol "$volume" ;;
        1) sox "$temp_file" "$output_file" pitch 200 vol "$volume" ;;
        2) sox "$temp_file" "$output_file" pitch -200 vol "$volume" ;;
        3) sox "$temp_file" "$output_file" reverse vol "$volume" ;;
        4) sox "$temp_file" "$output_file" echo 0.8 0.9 40 0.3 vol "$volume" ;;
        5) sox "$temp_file" "$output_file" flanger vol "$volume" ;;
        6) sox "$temp_file" "$output_file" reverb 50 vol "$volume" ;;
        7) sox "$temp_file" "$output_file" tremolo 4 30 vol "$volume" ;;
    esac
    
    rm -f "$temp_file"
    [ -f "$output_file" ]
}

echo "Creating $NUM_SEQUENCES dense 30-second mixes..."

for seq_num in $(seq 1 $NUM_SEQUENCES); do
    echo
    echo "=== Creating sequence $seq_num ==="
    
    # We'll create overlapping layers to ensure no silence
    all_segments=()
    segment_info=()  # Store start_time:duration for each segment
    
    # Calculate segments needed to fill 30 seconds with overlap
    # Each file will contribute multiple overlapping segments
    total_duration_needed=90  # 3x coverage for density
    current_total=0
    
    # Shuffle files for variety
    shuffled_files=($(printf '%s\n' "${audio_files[@]}" | sort -R))
    
    file_index=0
    while [ "$current_total" -lt "$total_duration_needed" ]; do
        file="${shuffled_files[$file_index]}"
        
        # Get file duration
        file_duration=$(ffmpeg -i "$file" 2>&1 | grep "Duration" | cut -d ' ' -f 4 | sed s/,// | awk -F: '{ print int(($1 * 3600) + ($2 * 60) + $3) }')
        
        if [ -z "$file_duration" ] || [ "$file_duration" -eq 0 ]; then
            file_duration=30
        fi
        
        # Extract 2-8 second segments
        seg_duration=$((2 + RANDOM % 7))
        if [ "$seg_duration" -gt "$file_duration" ]; then
            seg_duration="$file_duration"
        fi
        
        # Random start in source file
        max_start=$((file_duration - seg_duration))
        if [ "$max_start" -gt 0 ]; then
            source_start=$((RANDOM % max_start))
        else
            source_start=0
        fi
        
        # Random effect and volume
        effect=$((RANDOM % 8))
        volume=$(echo "scale=2; 0.3 + $RANDOM/32768 * 0.4" | bc)
        
        # Create segment
        seg_file="seg_${seq_num}_${file_index}_${RANDOM}.wav"
        if extract_segment "$file" "$seg_file" "$source_start" "$seg_duration" "$effect" "$volume"; then
            # Random position in the 30-second timeline
            position=$((RANDOM % 25))
            segment_info+=("$position:$seg_duration:$seg_file")
            current_total=$((current_total + seg_duration))
        else
            rm -f "$seg_file"
        fi
        
        # Move to next file
        file_index=$(((file_index + 1) % ${#shuffled_files[@]}))
    done
    
    echo "  Created ${#segment_info[@]} segments"
    
    # Now create the final mix by layering all segments
    if [ ${#segment_info[@]} -gt 0 ]; then
        # Create mix command
        mix_inputs=""
        mix_delays=""
        
        for i in "${!segment_info[@]}"; do
            IFS=':' read -r position duration segfile <<< "${segment_info[$i]}"
            if [ -f "$segfile" ]; then
                mix_inputs="$mix_inputs -i $segfile"
                delay_ms=$((position * 1000))
                
                if [ $i -eq 0 ]; then
                    mix_delays="${mix_delays}[${i}:a]adelay=0|0[a${i}];"
                else
                    mix_delays="${mix_delays}[${i}:a]adelay=${delay_ms}|${delay_ms}[a${i}];"
                fi
                all_segments+=("$segfile")
            fi
        done
        
        # Build filter complex
        filter_complex="$mix_delays"
        for i in "${!all_segments[@]}"; do
            filter_complex="${filter_complex}[a${i}]"
        done
        filter_complex="${filter_complex}amix=inputs=${#all_segments[@]}:duration=longest,aformat=sample_rates=44100:channel_layouts=stereo[mixed]"
        
        # Create the mix
        output_file=$(printf "%s_%02d.wav" "$OUTPUT_PREFIX" "$seq_num")
        temp_mix="temp_mix_${seq_num}.wav"
        
        # Mix all segments
        eval "ffmpeg -y $mix_inputs -filter_complex \"$filter_complex\" -map '[mixed]' -t 30 \"$temp_mix\" 2>/dev/null"
        
        # Final processing with sox
        if [ -f "$temp_mix" ]; then
            sox "$temp_mix" "$output_file" \
                compand 0.01,0.1 -60,-60,-30,-20,-20,-15,-10,-10,0,-7 6 \
                norm -1 \
                fade 0.1 30 0.2 \
                trim 0 30
            
            echo "  Created: $output_file"
            
            # Verify
            duration=$(soxi -D "$output_file" 2>/dev/null || echo "unknown")
            echo "  Duration: ${duration}s, Segments: ${#all_segments[@]}"
        fi
        
        # Cleanup
        rm -f "$temp_mix" "${all_segments[@]}"
    fi
done

echo
echo "Done! Created $NUM_SEQUENCES dense 30-second mixes:"
ls -la ${OUTPUT_PREFIX}_*.wav

# Verification
echo
echo "Verifying all outputs:"
for f in ${OUTPUT_PREFIX}_*.wav; do
    if [ -f "$f" ]; then
        duration=$(soxi -D "$f" 2>/dev/null || echo "error")
        size=$(du -h "$f" | cut -f1)
        echo "  $f: ${duration}s, size: $size"
    fi
done