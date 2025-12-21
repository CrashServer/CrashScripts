#!/bin/bash

# Check if ffmpeg and sox are installed
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed. Please install it first."
    exit 1
fi

if ! command -v sox &> /dev/null; then
    echo "Error: sox is not installed. Please install it first."
    exit 1
fi

# Output settings
OUTPUT_PREFIX="30sec_mix"
SEQUENCE_DURATION=30
MIN_FILES_PER_SEQUENCE=5
MAX_FILES_PER_SEQUENCE=10
NUM_SEQUENCES=10

# Find all audio files
echo "Finding audio files..."
mapfile -t audio_files < <(find . -maxdepth 1 -type f \( -iname "*.ogg" -o -iname "*.wav" -o -iname "*.mp3" \) | sort)

if [ ${#audio_files[@]} -eq 0 ]; then
    echo "No audio files (ogg, wav, mp3) found in the current directory."
    exit 1
fi

echo "Found ${#audio_files[@]} audio files"
echo

# Check if we have enough files
if [ ${#audio_files[@]} -lt 3 ]; then
    echo "Error: Need at least 3 audio files"
    exit 1
fi

# Function to create a 30-second base track
create_base_track() {
    local input_file="$1"
    local output_file="$2"
    local start_time="$3"
    
    # First convert to standard format and create exactly 30 seconds
    ffmpeg -ss "$start_time" -i "$input_file" -t 30 -acodec pcm_s16le -ar 44100 -ac 2 "$output_file" -y 2>/dev/null
    
    # If the source was shorter than 30 seconds, loop it
    duration=$(soxi -D "$output_file" 2>/dev/null || echo "0")
    if (( $(echo "$duration < 30" | bc -l) )); then
        # Create a 30-second loop
        sox "$output_file" "temp_loop.wav" repeat 100
        sox "temp_loop.wav" "$output_file" trim 0 30
        rm -f "temp_loop.wav"
    fi
}

echo "Creating $NUM_SEQUENCES 30-second organic mixes..."

for seq_num in $(seq 1 $NUM_SEQUENCES); do
    echo
    echo "Creating sequence $seq_num..."
    
    # Randomly select number of files to use
    max_files=$MAX_FILES_PER_SEQUENCE
    if [ ${#audio_files[@]} -lt $MAX_FILES_PER_SEQUENCE ]; then
        max_files=${#audio_files[@]}
    fi
    if [ ${#audio_files[@]} -lt $MIN_FILES_PER_SEQUENCE ]; then
        num_files=${#audio_files[@]}
    else
        num_files=$((MIN_FILES_PER_SEQUENCE + RANDOM % (max_files - MIN_FILES_PER_SEQUENCE + 1)))
    fi
    
    # Select random files
    selected_files=()
    while [ ${#selected_files[@]} -lt $num_files ]; do
        rand_idx=$((RANDOM % ${#audio_files[@]}))
        file="${audio_files[$rand_idx]}"
        if [[ ! " ${selected_files[@]} " =~ " ${file} " ]]; then
            selected_files+=("$file")
        fi
    done
    
    # Create the first base track (30 seconds guaranteed)
    echo "  Creating base layer from $(basename "${selected_files[0]}")"
    create_base_track "${selected_files[0]}" "base_${seq_num}.wav" "$((RANDOM % 10))"
    
    # Process remaining files as overlay tracks
    overlay_tracks=("base_${seq_num}.wav")
    
    for i in $(seq 1 $((${#selected_files[@]} - 1))); do
        file="${selected_files[$i]}"
        echo "  Processing layer $((i+1)) from $(basename "$file")"
        
        # Get file duration
        duration=$(ffmpeg -i "$file" 2>&1 | grep "Duration" | cut -d ' ' -f 4 | sed s/,// | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
        duration=${duration%.*}
        
        # Create segments from this file
        overlay_file="overlay_${seq_num}_${i}.wav"
        sox -n -r 44100 -c 2 "$overlay_file" trim 0 30  # Create 30s silence
        
        # Add 3-5 segments at random positions
        num_segments=$((3 + RANDOM % 3))
        for seg in $(seq 1 $num_segments); do
            # Random parameters
            if [ "$duration" -gt 5 ]; then
                start=$((RANDOM % (duration - 5)))
            else
                start=0
            fi
            seg_duration=$((2 + RANDOM % 6))
            position=$((RANDOM % 25))  # Position in the 30-second timeline
            
            # Choose random effect
            effect=$((RANDOM % 5))
            temp_seg="temp_seg_${seq_num}_${i}_${seg}.wav"
            
            case $effect in
                0) # Clean segment with fade
                    ffmpeg -ss $start -i "$file" -t $seg_duration -af "afade=t=in:d=0.3,afade=t=out:d=0.3" -acodec pcm_s16le -ar 44100 "$temp_seg" -y 2>/dev/null
                    ;;
                1) # Pitch shifted
                    ffmpeg -ss $start -i "$file" -t $seg_duration -af "afade=t=in:d=0.3,afade=t=out:d=0.3,asetrate=44100*1.2,atempo=0.833" -acodec pcm_s16le -ar 44100 "$temp_seg" -y 2>/dev/null
                    ;;
                2) # Reversed
                    ffmpeg -ss $start -i "$file" -t $seg_duration -af "afade=t=in:d=0.3,afade=t=out:d=0.3,areverse" -acodec pcm_s16le -ar 44100 "$temp_seg" -y 2>/dev/null
                    ;;
                3) # Echo effect
                    ffmpeg -ss $start -i "$file" -t $seg_duration -af "afade=t=in:d=0.3,afade=t=out:d=0.3,aecho=0.8:0.9:1000:0.3" -acodec pcm_s16le -ar 44100 "$temp_seg" -y 2>/dev/null
                    ;;
                4) # Low-pass filtered
                    ffmpeg -ss $start -i "$file" -t $seg_duration -af "afade=t=in:d=0.3,afade=t=out:d=0.3,lowpass=f=1000" -acodec pcm_s16le -ar 44100 "$temp_seg" -y 2>/dev/null
                    ;;
            esac
            
            # Mix segment at position with reduced volume
            if [ -f "$temp_seg" ]; then
                sox "$overlay_file" "|sox $temp_seg -p vol 0.3" "temp_mixed_${seq_num}_${i}_${seg}.wav" splice -q $position
                mv "temp_mixed_${seq_num}_${i}_${seg}.wav" "$overlay_file"
                rm -f "$temp_seg"
            fi
        done
        
        overlay_tracks+=("$overlay_file")
    done
    
    # Final mix - ensure exactly 30 seconds
    output_file=$(printf "%s_%02d.wav" "$OUTPUT_PREFIX" "$seq_num")
    echo "  Mixing all layers..."
    
    # Mix all tracks together
    sox -m "${overlay_tracks[@]}" "temp_final_${seq_num}.wav" norm -3
    
    # Ensure exactly 30 seconds with fade out
    sox "temp_final_${seq_num}.wav" "$output_file" fade t 0.5 30 0.5 trim 0 30
    
    # Verify duration
    final_duration=$(soxi -D "$output_file" 2>/dev/null || echo "unknown")
    echo "  Created: $output_file (duration: ${final_duration}s)"
    
    # Clean up
    rm -f base_${seq_num}.wav overlay_${seq_num}_*.wav temp_final_${seq_num}.wav
done

echo
echo "Done! Created $NUM_SEQUENCES 30-second mixes:"
ls -la ${OUTPUT_PREFIX}_*.wav

# Verify all outputs are 30 seconds
echo
echo "Verifying durations:"
for f in ${OUTPUT_PREFIX}_*.wav; do
    duration=$(soxi -D "$f" 2>/dev/null || echo "error")
    echo "  $f: ${duration}s"
done