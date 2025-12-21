#!/bin/bash

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed. Please install it first."
    exit 1
fi

# Output filenames
MERGED_FILE="merged_audio.wav"
OUTPUT_PREFIX="random_sequence"

# Create a list of all audio files
echo "Finding audio files..."
audio_files=$(find . -maxdepth 1 -type f \( -iname "*.ogg" -o -iname "*.wav" -o -iname "*.mp3" \) | sort)

if [ -z "$audio_files" ]; then
    echo "No audio files (ogg, wav, mp3) found in the current directory."
    exit 1
fi

echo "Found audio files:"
echo "$audio_files"
echo

# Process each audio file

# Merge all audio files into one
echo "Merging all audio files into $MERGED_FILE..."
# First convert each file to a standard format, then concatenate
rm -f temp_*.wav
counter=0
while IFS= read -r file; do
    temp_file="temp_$(printf "%04d" $counter).wav"
    echo "Converting: $file -> $temp_file"
    ffmpeg -i "$file" -acodec pcm_s16le -ar 44100 -ac 2 "$temp_file" -y 2>/dev/null
    counter=$((counter + 1))
done <<< "$audio_files"

# Now create a new filelist with the converted files
> filelist.txt
for f in temp_*.wav; do
    echo "file '$f'" >> filelist.txt
done

# Concatenate the converted files
ffmpeg -f concat -safe 0 -i filelist.txt -c copy "$MERGED_FILE" -y

# Check if merge was successful
if [ ! -f "$MERGED_FILE" ]; then
    echo "Error: Failed to create merged audio file."
    rm -f filelist.txt
    exit 1
fi

# Get the duration of the merged file in seconds
duration=$(ffmpeg -i "$MERGED_FILE" 2>&1 | grep "Duration" | cut -d ' ' -f 4 | sed s/,// | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
duration=${duration%.*}  # Convert to integer

echo "Merged file duration: $duration seconds"

# Check if the merged file is at least 30 seconds
if [ "$duration" -lt 30 ]; then
    echo "Error: Merged audio is less than 30 seconds. Cannot create 30-second sequences."
    rm -f filelist.txt
    exit 1
fi

# Calculate the maximum start time for a 30-second clip
max_start=$((duration - 30))

# Create 10 random 30-second sequences
echo
echo "Creating 10 random 30-second sequences..."
for i in {1..10}; do
    # Generate random start time
    start_time=$((RANDOM % (max_start + 1)))
    
    # Format output filename with leading zeros
    output_file=$(printf "%s_%02d.wav" "$OUTPUT_PREFIX" "$i")
    
    echo "Creating sequence $i: starting at ${start_time}s -> $output_file"
    
    # Extract 30-second clip
    ffmpeg -ss "$start_time" -i "$MERGED_FILE" -t 30 -c:a pcm_s16le "$output_file" -y
done

# Clean up
rm -f filelist.txt temp_*.wav

echo
echo "Done! Created:"
echo "- Merged file: $MERGED_FILE"
echo "- 10 random sequences: ${OUTPUT_PREFIX}_01.wav to ${OUTPUT_PREFIX}_10.wav"