#!/bin/bash

# Beat-Synced Image Sequence Video Generator
# Combines multiple image sequence folders into one video
# Switches folders every 4 beats at 120 BPM (every 2 seconds / 60 frames at 30fps)

set -e

# Configuration
FPS=30
FRAMES_PER_SEGMENT=60  # 2 seconds at 30fps = 4 beats at 120 BPM
WIDTH=1920
HEIGHT=1080
OUTPUT="output_beat_synced.mp4"
PREVIEW_INTERVAL=600  # Create preview every 600 frames (20 seconds)
MAX_PARALLEL_JOBS=8  # Limit parallel jobs to reduce memory usage

# Check if directory argument provided, default to current directory
if [ $# -eq 0 ]; then
    BASE_DIR="."
    echo "Using current directory: $(pwd)"
else
    BASE_DIR="$1"
fi

if [ ! -d "$BASE_DIR" ]; then
    echo "Error: Directory '$BASE_DIR' not found"
    exit 1
fi

# Create temporary working directory
TEMP_DIR=$(mktemp -d)
echo "Working directory: $TEMP_DIR"

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Step 1: Scan all folders and their images
echo "Scanning folders..."
declare -A folder_images
declare -A folder_index

for folder in "$BASE_DIR"/*/; do
    if [ -d "$folder" ]; then
        folder_name=$(basename "$folder")

        # Find all jpg/jpeg images, sort them numerically
        images=($(find "$folder" -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) | sort -V))

        if [ ${#images[@]} -gt 0 ]; then
            folder_images["$folder_name"]="${images[@]}"
            folder_index["$folder_name"]=0
            echo "  Found folder: $folder_name (${#images[@]} images)"
        fi
    fi
done

# Check if we found any folders
if [ ${#folder_images[@]} -eq 0 ]; then
    echo "Error: No folders with images found in $BASE_DIR"
    exit 1
fi

echo ""
echo "Total folders: ${#folder_images[@]}"
echo ""

# Step 2: Create concat file
CONCAT_FILE="$TEMP_DIR/concat.txt"
SEGMENT_NUM=0
TOTAL_FRAMES=0
PREVIEW_NUM=0

# Create previews directory
PREVIEW_DIR="previews"
mkdir -p "$PREVIEW_DIR"

# Create array of available folders
available_folders=(${!folder_images[@]})

echo "Generating video segments..."

while [ ${#available_folders[@]} -gt 0 ]; do
    # Pick random folder
    random_idx=$((RANDOM % ${#available_folders[@]}))
    current_folder="${available_folders[$random_idx]}"

    # Get images array for this folder
    read -ra images <<< "${folder_images[$current_folder]}"
    current_idx=${folder_index[$current_folder]}

    # Check if folder has enough frames left for a full segment
    remaining=$((${#images[@]} - current_idx))

    if [ $remaining -lt $FRAMES_PER_SEGMENT ]; then
        # Not enough frames for a full segment - remove folder and try another
        echo "    → $current_folder has only $remaining frames left, skipping..."
        unset 'available_folders[$random_idx]'
        available_folders=("${available_folders[@]}")
        continue
    fi

    # Take exactly FRAMES_PER_SEGMENT frames
    frames_to_take=$FRAMES_PER_SEGMENT

    echo "  Segment $SEGMENT_NUM: $current_folder (frames $current_idx - $((current_idx + frames_to_take - 1)))"

    # Create segment directory
    SEGMENT_DIR="$TEMP_DIR/segment_$SEGMENT_NUM"
    mkdir -p "$SEGMENT_DIR"

    # Copy and rename frames for this segment (parallelized with memory limit)
    job_count=0
    for ((i=0; i<frames_to_take; i++)); do
        src_img="${images[$((current_idx + i))]}"
        dst_img="$SEGMENT_DIR/$(printf "%06d.jpg" $i)"

        # Scale and pad image to fit 1920x1080 (parallel processing)
        (ffmpeg -i "$src_img" -vf "scale=$WIDTH:$HEIGHT:force_original_aspect_ratio=decrease,pad=$WIDTH:$HEIGHT:(ow-iw)/2:(oh-ih)/2:black" -q:v 2 "$dst_img" -y 2>/dev/null) &

        job_count=$((job_count + 1))

        # Limit parallel jobs to reduce memory usage
        if [ $job_count -ge $MAX_PARALLEL_JOBS ]; then
            wait
            job_count=0
        fi
    done
    wait  # Wait for remaining jobs

    # Update folder index
    folder_index[$current_folder]=$((current_idx + frames_to_take))

    # If folder doesn't have enough frames for another full segment, remove it
    new_remaining=$((${#images[@]} - folder_index[$current_folder]))
    if [ $new_remaining -lt $FRAMES_PER_SEGMENT ]; then
        echo "    → $current_folder will be exhausted after this segment"
        unset 'available_folders[$random_idx]'
        available_folders=("${available_folders[@]}")
    fi

    SEGMENT_NUM=$((SEGMENT_NUM + 1))
    TOTAL_FRAMES=$((TOTAL_FRAMES + FRAMES_PER_SEGMENT))

    # Check if we should create a preview
    if [ $((TOTAL_FRAMES % PREVIEW_INTERVAL)) -eq 0 ] || [ ${#available_folders[@]} -eq 0 ]; then
        PREVIEW_NUM=$((PREVIEW_NUM + 1))
        echo ""
        echo "  → Creating preview $PREVIEW_NUM at $TOTAL_FRAMES frames..."

        # Create temporary concat file for preview
        PREVIEW_CONCAT="$TEMP_DIR/preview_concat_$PREVIEW_NUM.txt"
        > "$PREVIEW_CONCAT"

        for ((seg=0; seg<SEGMENT_NUM; seg++)); do
            for ((j=0; j<FRAMES_PER_SEGMENT; j++)); do
                frame_path="$TEMP_DIR/segment_$seg/$(printf "%06d.jpg" $j)"
                if [ -f "$frame_path" ]; then
                    echo "file '$frame_path'" >> "$PREVIEW_CONCAT"
                    echo "duration 0.033333" >> "$PREVIEW_CONCAT"
                fi
            done
        done

        # Add last frame
        last_seg=$((SEGMENT_NUM - 1))
        last_frame_path="$TEMP_DIR/segment_$last_seg/$(printf "%06d.jpg" $((FRAMES_PER_SEGMENT - 1)))"
        echo "file '$last_frame_path'" >> "$PREVIEW_CONCAT"

        # Generate preview video
        PREVIEW_FILE="$PREVIEW_DIR/preview_$(printf "%03d" $PREVIEW_NUM)_${TOTAL_FRAMES}frames.mp4"
        ffmpeg -f concat -safe 0 -i "$PREVIEW_CONCAT" \
            -vf "fps=$FPS" \
            -c:v libx264 \
            -preset ultrafast \
            -crf 23 \
            -pix_fmt yuv420p \
            -threads 0 \
            -y "$PREVIEW_FILE" 2>/dev/null

        echo "  ✓ Preview saved: $PREVIEW_FILE"
        echo ""
    fi
done

echo ""
echo "Generated $SEGMENT_NUM segments ($TOTAL_FRAMES frames total)"
echo "Duration: $((TOTAL_FRAMES / FPS)) seconds"
echo ""

# Step 3: Generate video with ffmpeg
echo "Creating final video..."

# Create a proper concat demuxer file
CONCAT_DEMUX="$TEMP_DIR/concat_demux.txt"
> "$CONCAT_DEMUX"

for ((i=0; i<SEGMENT_NUM; i++)); do
    for ((j=0; j<FRAMES_PER_SEGMENT; j++)); do
        frame_path="$TEMP_DIR/segment_$i/$(printf "%06d.jpg" $j)"
        echo "file '$frame_path'" >> "$CONCAT_DEMUX"
        echo "duration 0.033333" >> "$CONCAT_DEMUX"
    done
done

# Add last frame again (ffmpeg concat requirement)
last_segment=$((SEGMENT_NUM - 1))
last_frame="$TEMP_DIR/segment_$last_segment/$(printf "%06d.jpg" $((FRAMES_PER_SEGMENT - 1)))"
echo "file '$last_frame'" >> "$CONCAT_DEMUX"

ffmpeg -f concat -safe 0 -i "$CONCAT_DEMUX" \
    -vf "fps=$FPS" \
    -c:v libx264 \
    -preset ultrafast \
    -crf 18 \
    -pix_fmt yuv420p \
    -threads 0 \
    -y "$OUTPUT"

echo ""
echo "✓ Video created: $OUTPUT"
echo "  Resolution: ${WIDTH}x${HEIGHT}"
echo "  Frame rate: ${FPS} fps"
echo "  Duration: $((TOTAL_FRAMES / FPS)) seconds"
echo "  Folder switches: every 4 beats (2 seconds) at 120 BPM"
echo ""
echo "You can now add your 120 BPM audio track to this video!"
