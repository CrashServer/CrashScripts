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

# Get durations of all files
echo "Analyzing file durations..."
declare -a file_durations

for i in "${!audio_files[@]}"; do
    input_file="${audio_files[$i]}"
    duration=$(ffmpeg -i "$input_file" 2>&1 | grep "Duration" | cut -d ' ' -f 4 | sed s/,// | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
    file_durations+=("$duration")
    echo "  $input_file: ${duration}s"
done

echo
echo "Creating $NUM_SEQUENCES organic sequences..."

for seq_num in $(seq 1 $NUM_SEQUENCES); do
    echo
    echo "Creating sequence $seq_num..."
    
    # Randomly select between 3-6 files for this sequence
    num_files=$((MIN_FILES_PER_SEQUENCE + RANDOM % 4))
    
    # Create array of selected file indices
    selected_indices=()
    while [ ${#selected_indices[@]} -lt $num_files ]; do
        rand_idx=$((RANDOM % ${#audio_files[@]}))
        if [[ ! " ${selected_indices[@]} " =~ " ${rand_idx} " ]]; then
            selected_indices+=($rand_idx)
        fi
    done
    
    # Calculate segment duration for each file
    segment_duration=$((SEQUENCE_DURATION / num_files))
    remainder=$((SEQUENCE_DURATION % num_files))
    
    # Build ffmpeg filter complex for mixing
    filter_complex=""
    inputs=""
    
    for i in "${!selected_indices[@]}"; do
        file_idx=${selected_indices[$i]}
        file="${audio_files[$file_idx]}"
        duration="${file_durations[$file_idx]}"
        
        # Add remainder seconds to the last segment
        if [ $i -eq $((${#selected_indices[@]} - 1)) ]; then
            this_segment_duration=$((segment_duration + remainder))
        else
            this_segment_duration=$segment_duration
        fi
        
        # Random start position
        max_start=$(echo "$duration - $this_segment_duration" | bc 2>/dev/null || echo "0")
        if (( $(echo "$max_start > 0" | bc -l 2>/dev/null || echo "0") )); then
            start_time=$(awk -v max="$max_start" 'BEGIN{srand(); print rand()*max}')
        else
            start_time=0
        fi
        
        echo "  - Taking ${this_segment_duration}s from $(basename "$file") (starting at ${start_time}s)"
        
        inputs="$inputs -ss $start_time -t $this_segment_duration -i \"$file\""
        
        # Build filter for this input with fade in/out
        # For overlapping mix, each segment starts at its position in the sequence
        start_position=$(echo "$i * $segment_duration / 2" | bc 2>/dev/null || echo "0")
        delay_samples=$(echo "$start_position * 44100" | bc 2>/dev/null || echo "0")
        
        filter_complex="${filter_complex}[$i:a]aformat=sample_rates=44100:channel_layouts=stereo,afade=t=in:st=0:d=0.5,afade=t=out:st=$((this_segment_duration - 1)):d=0.5"
        
        if [ "$i" -gt 0 ]; then
            filter_complex="${filter_complex},adelay=${delay_samples}|${delay_samples}"
        fi
        
        filter_complex="${filter_complex}[a$i];"
    done
    
    # Mix all audio streams
    for i in "${!selected_indices[@]}"; do
        filter_complex="${filter_complex}[a$i]"
    done
    filter_complex="${filter_complex}amix=inputs=$num_files:duration=longest:normalize=0,volume=0.8,atrim=0:30[out]"
    
    output_file=$(printf "%s_%02d.wav" "$OUTPUT_PREFIX" "$seq_num")
    
    # Execute ffmpeg command
    echo "  Mixing segments..."
    eval "ffmpeg -y $inputs -filter_complex \"$filter_complex\" -map \"[out]\" -acodec pcm_s16le -ar 44100 \"$output_file\" 2>/dev/null"
    
    echo "  Created: $output_file"
done

echo
echo "Done! Created $NUM_SEQUENCES organic mixes:"
ls -la ${OUTPUT_PREFIX}_*.wav