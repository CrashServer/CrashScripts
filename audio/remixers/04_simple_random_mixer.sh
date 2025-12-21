#!/bin/bash

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed."
    exit 1
fi

# Output settings
OUTPUT_PREFIX="organic_mix"
SEQUENCE_DURATION=30
MIN_FILES_PER_SEQUENCE=3
NUM_SEQUENCES=10

# Find all audio files
echo "Finding audio files..."
mapfile -t audio_files < <(find . -maxdepth 1 -type f \( -iname "*.ogg" -o -iname "*.wav" -o -iname "*.mp3" \) | sort)

if [ ${#audio_files[@]} -eq 0 ]; then
    echo "No audio files (ogg, wav, mp3) found in the current directory."
    exit 1
fi

echo "Found ${#audio_files[@]} audio files:"
printf '%s\n' "${audio_files[@]}"
echo

# Check if we have enough files
if [ ${#audio_files[@]} -lt $MIN_FILES_PER_SEQUENCE ]; then
    echo "Error: Need at least $MIN_FILES_PER_SEQUENCE audio files, but only found ${#audio_files[@]}"
    exit 1
fi

echo
echo "Creating $NUM_SEQUENCES organic sequences..."

for seq_num in $(seq 1 $NUM_SEQUENCES); do
    echo
    echo "Creating sequence $seq_num..."
    
    # Randomly select between 3-6 files for this sequence
    num_files=$((MIN_FILES_PER_SEQUENCE + RANDOM % 4))
    
    # Create array of selected files
    selected_files=()
    while [ ${#selected_files[@]} -lt $num_files ]; do
        rand_idx=$((RANDOM % ${#audio_files[@]}))
        file="${audio_files[$rand_idx]}"
        if [[ ! " ${selected_files[@]} " =~ " ${file} " ]]; then
            selected_files+=("$file")
        fi
    done
    
    # Create individual 30-second segments from each file
    segment_files=()
    for i in "${!selected_files[@]}"; do
        file="${selected_files[$i]}"
        
        # Get file duration
        duration=$(ffmpeg -i "$file" 2>&1 | grep "Duration" | cut -d ' ' -f 4 | sed s/,// | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
        duration=${duration%.*}  # Convert to integer
        
        # Random start position
        if [ "$duration" -gt "$SEQUENCE_DURATION" ]; then
            max_start=$((duration - SEQUENCE_DURATION))
            start_time=$((RANDOM % (max_start + 1)))
        else
            start_time=0
        fi
        
        echo "  - Processing $(basename "$file") (starting at ${start_time}s)"
        
        # Create a 30-second segment with fade in/out
        segment_file="temp_segment_${seq_num}_${i}.wav"
        ffmpeg -y -ss $start_time -i "$file" -t $SEQUENCE_DURATION -af "afade=t=in:st=0:d=1,afade=t=out:st=29:d=1,aformat=sample_rates=44100:channel_layouts=stereo" -acodec pcm_s16le "$segment_file" 2>/dev/null
        
        segment_files+=("$segment_file")
    done
    
    # Mix all segments together with volume adjustment
    output_file=$(printf "%s_%02d.wav" "$OUTPUT_PREFIX" "$seq_num")
    
    # Build ffmpeg command for mixing
    mix_cmd="ffmpeg -y"
    for f in "${segment_files[@]}"; do
        mix_cmd="$mix_cmd -i \"$f\""
    done
    
    # Create filter complex for mixing with different volumes
    filter=""
    for i in "${!segment_files[@]}"; do
        # Give each input a different volume level for variety
        vol=$(echo "scale=2; 0.3 + ($RANDOM % 70) / 100" | bc)
        filter="${filter}[$i:a]volume=$vol[a$i];"
    done
    
    # Mix all inputs
    for i in "${!segment_files[@]}"; do
        filter="${filter}[a$i]"
    done
    filter="${filter}amix=inputs=$num_files:duration=first:dropout_transition=2,dynaudnorm,atrim=0:30"
    
    mix_cmd="$mix_cmd -filter_complex \"$filter\" -acodec pcm_s16le -ar 44100 \"$output_file\""
    
    echo "  Mixing segments..."
    eval $mix_cmd 2>/dev/null
    
    # Clean up segment files
    rm -f temp_segment_${seq_num}_*.wav
    
    # Verify duration
    result_duration=$(ffmpeg -i "$output_file" 2>&1 | grep "Duration" | cut -d ' ' -f 4 | cut -d'.' -f1)
    echo "  Created: $output_file (duration: $result_duration)"
done

echo
echo "Done! Created $NUM_SEQUENCES organic mixes:"
ls -la ${OUTPUT_PREFIX}_*.wav