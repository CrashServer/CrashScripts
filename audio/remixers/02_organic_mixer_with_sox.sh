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

# Convert all files to a standard format and get their durations
echo "Converting files to standard format and analyzing durations..."
rm -f temp_*.wav
declare -a converted_files
declare -a file_durations

for i in "${!audio_files[@]}"; do
    input_file="${audio_files[$i]}"
    temp_file="temp_$(printf "%04d" $i).wav"
    
    echo "Converting: $input_file -> $temp_file"
    ffmpeg -i "$input_file" -acodec pcm_s16le -ar 44100 -ac 2 "$temp_file" -y 2>/dev/null
    
    if [ -f "$temp_file" ]; then
        converted_files+=("$temp_file")
        # Get duration in seconds
        duration=$(soxi -D "$temp_file" 2>/dev/null)
        if [ -z "$duration" ]; then
            duration=$(ffmpeg -i "$temp_file" 2>&1 | grep "Duration" | cut -d ' ' -f 4 | sed s/,// | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
        fi
        file_durations+=("$duration")
        echo "  Duration: ${duration}s"
    fi
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
        rand_idx=$((RANDOM % ${#converted_files[@]}))
        # Check if already selected
        if [[ ! " ${selected_indices[@]} " =~ " ${rand_idx} " ]]; then
            selected_indices+=($rand_idx)
        fi
    done
    
    # Calculate segment duration for each file
    segment_duration=$((SEQUENCE_DURATION / num_files))
    remainder=$((SEQUENCE_DURATION % num_files))
    
    # Create segments with crossfades
    segment_files=()
    for i in "${!selected_indices[@]}"; do
        file_idx=${selected_indices[$i]}
        file="${converted_files[$file_idx]}"
        duration="${file_durations[$file_idx]}"
        
        # Add remainder seconds to the last segment
        if [ $i -eq $((${#selected_indices[@]} - 1)) ]; then
            this_segment_duration=$((segment_duration + remainder))
        else
            this_segment_duration=$segment_duration
        fi
        
        # Random start position (ensure we don't go past the end)
        max_start=$(echo "$duration - $this_segment_duration" | bc)
        if (( $(echo "$max_start > 0" | bc -l) )); then
            start_time=$(echo "scale=2; $RANDOM/32768 * $max_start" | bc)
        else
            start_time=0
        fi
        
        segment_file="segment_${seq_num}_${i}.wav"
        
        echo "  - Taking ${this_segment_duration}s from ${audio_files[$file_idx]} (starting at ${start_time}s)"
        
        # Extract segment with fade in/out for smooth transitions
        sox "$file" "$segment_file" trim "$start_time" "$this_segment_duration" fade t 0.5 0 0.5
        
        segment_files+=("$segment_file")
    done
    
    # Mix all segments with overlapping crossfades
    output_file=$(printf "%s_%02d.wav" "$OUTPUT_PREFIX" "$seq_num")
    
    if [ ${#segment_files[@]} -eq 1 ]; then
        # If only one segment, just copy it
        cp "${segment_files[0]}" "$output_file"
    else
        # Create mix with crossfades using sox
        sox_cmd="sox -m"
        for i in "${!segment_files[@]}"; do
            delay=$(echo "scale=2; $i * ($segment_duration - 1)" | bc)
            sox_cmd="$sox_cmd "|${segment_files[$i]}| pad ${delay}|"
        done
        sox_cmd="$sox_cmd -v 0.8 $output_file norm -3"
        
        echo "  Mixing segments..."
        eval $sox_cmd
    fi
    
    # Clean up segment files
    rm -f segment_${seq_num}_*.wav
    
    echo "  Created: $output_file"
done

# Final cleanup
echo
echo "Cleaning up temporary files..."
rm -f temp_*.wav

echo
echo "Done! Created $NUM_SEQUENCES organic mixes:"
ls -la ${OUTPUT_PREFIX}_*.wav