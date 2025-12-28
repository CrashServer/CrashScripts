#!/bin/bash

# Extract 86 seconds from 3:20 and format for Instagram
# Input file: 2025-07-27 04-40-00.mkv
# Start time: 3:20 (3 minutes 20 seconds)
# Duration: 86 seconds
# Output: Instagram-compatible format

INPUT_FILE="2025-07-27 04-40-00.mkv"
OUTPUT_FILE="chaos_lab_extract_instagram.mp4"
START_TIME="00:03:20"
DURATION="86"

# Basic Instagram-compatible extract
ffmpeg -i "$INPUT_FILE" \
    -ss "$START_TIME" \
    -t "$DURATION" \
    -c:v libx264 \
    -c:a aac \
    -preset fast \
    -crf 23 \
    -pix_fmt yuv420p \
    -movflags +faststart \
    "$OUTPUT_FILE"

echo "Extract complete: $OUTPUT_FILE"
echo "Duration: 86 seconds starting from 3:20"

# Alternative: For Instagram Stories (9:16 aspect ratio)
# Uncomment if you want vertical format
# OUTPUT_STORIES="chaos_lab_stories_instagram.mp4"
#
# ffmpeg -i "$INPUT_FILE" \
#     -ss "$START_TIME" \
#     -t "$DURATION" \
#     -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:black" \
#     -c:v libx264 \
#     -c:a aac \
#     -preset fast \
#     -crf 23 \
#     -pix_fmt yuv420p \
#     -movflags +faststart \
#     "$OUTPUT_STORIES"

# Alternative: For Instagram Reels (9:16 with better quality)
# Uncomment if you want Reels format
# OUTPUT_REELS="chaos_lab_reels_instagram.mp4"
#
# ffmpeg -i "$INPUT_FILE" \
#     -ss "$START_TIME" \
#     -t "$DURATION" \
#     -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:black" \
#     -c:v libx264 \
#     -c:a aac \
#     -preset medium \
#     -crf 20 \
#     -pix_fmt yuv420p \
#     -movflags +faststart \
#     -r 30 \
#     "$OUTPUT_REELS"
