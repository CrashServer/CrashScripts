#!/bin/bash

# Set locale to handle floating point numbers properly
export LC_NUMERIC=C

# SIMPLE Film Roll Test - 50 seconds with 3 colored strips
INPUT_VIDEO="$1"
OUTPUT_VIDEO="film_roll_test.mp4"
TEMP_DIR="temp_film_test"

# 120 BPM = 2 beats per second = 0.5 seconds per beat
BEAT_DURATION=0.5
TOTAL_DURATION=50
NUM_CUTS=$((TOTAL_DURATION * 2))  # 100 cuts for 50 seconds

# Simple text overlays
TEXTS=("CHAOS LAB VII" "TOPLAP STRASBOURG" "Ralt144MI" "nuance" "SHADOK" "ULTRATECH RECORDS")
TEXT_DURATION=8

# Check if input file is provided
if [ -z "$INPUT_VIDEO" ]; then
    echo "Usage: $0 <input_video.mov>"
    echo "Example: $0 myvideo.mov"
    exit 1
fi

# Check if input file exists
if [ ! -f "$INPUT_VIDEO" ]; then
    echo "Error: Input file '$INPUT_VIDEO' not found!"
    exit 1
fi

# Create temporary directory
mkdir -p "$TEMP_DIR"

echo "🎞️ Starting SIMPLE film roll test..."
echo "📁 Input: $INPUT_VIDEO"
echo "⏱️ Duration: ${TOTAL_DURATION} seconds"
echo "🎨 Testing: RED/GREEN/BLUE strips"

# Get video duration
DURATION=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$INPUT_VIDEO")
DURATION_INT=$(awk -v dur="$DURATION" 'BEGIN{printf "%.0f", dur}')

echo "📏 Original video duration: ${DURATION_INT}s"

# Generate timestamps
echo "📐 Generating timestamps..."
> "$TEMP_DIR/timestamps.txt"

interval=$(awk -v duration="$DURATION_INT" -v cuts="$NUM_CUTS" 'BEGIN{printf "%.2f", (duration-1)/cuts}')

for i in $(seq 0 $((NUM_CUTS-1))); do
    base_time=$(awk -v i="$i" -v interval="$interval" 'BEGIN{printf "%.2f", i*interval}')
    random_offset=$(awk -v interval="$interval" 'BEGIN{srand(); printf "%.2f", (rand()-0.5)*interval*0.2}')
    final_time=$(awk -v base="$base_time" -v offset="$random_offset" 'BEGIN{t=base+offset; if(t<0) t=0; printf "%.2f", t}')
    echo "$final_time" >> "$TEMP_DIR/timestamps.txt"
done

sort -n "$TEMP_DIR/timestamps.txt" > "$TEMP_DIR/sorted_timestamps.txt"

# Process segments with SIMPLE color approach
echo "🎨 Processing segments with SIMPLE color separation..."

segment_num=0
while IFS= read -r timestamp && [ $segment_num -lt $NUM_CUTS ]; do
    if [ -z "$timestamp" ]; then
        continue
    fi

    segment_file="$TEMP_DIR/segment_${segment_num}.mp4"

    # Calculate text
    text_index=$(awk -v seg="$segment_num" -v beat="$BEAT_DURATION" -v txt_dur="$TEXT_DURATION" 'BEGIN{printf "%.0f", (seg * beat) / txt_dur}')
    num_texts=${#TEXTS[@]}
    if [ $text_index -ge $num_texts ]; then
        text_index=$(awk -v idx="$text_index" -v num="$num_texts" 'BEGIN{printf "%.0f", idx % num}')
    fi
    current_text="${TEXTS[$text_index]}"
    safe_text=$(echo "$current_text" | sed 's/[^a-zA-Z0-9 ]/_/g')

    echo "Processing segment $segment_num at $timestamp..."

    # Calculate different timestamps for each strip + delays
    timestamp1="$timestamp"
    timestamp2=$(awk -v t="$timestamp" -v dur="$DURATION_INT" 'BEGIN{t2=t+(dur/3); if(t2>dur-2) t2=t2-dur/2; printf "%.2f", t2}')
    timestamp3=$(awk -v t="$timestamp" -v dur="$DURATION_INT" 'BEGIN{t3=t+(dur*2/3); if(t3>dur-2) t3=t3-dur/2; printf "%.2f", t3}')

    # Enhanced scene change detection (every 6 segments for more action)
    is_scene_change=$((segment_num % 6))
    if [ $is_scene_change -eq 0 ] && [ $segment_num -gt 0 ]; then
        text_jump_y="150"
        text_size="140"
        text_color="ff0000"
        text_shadow="ffffff"
        glitch_effect="noise=alls=150:allf=t+u,rgbshift=rh=5:rv=5:gh=-3:gv=3:bh=3:bv=-5,"
        box_color="ffff00@0.9"
        blink_effect="enable='lt(mod(t,0.3),0.15)'"
    else
        # Calculate smooth vertical movement based on segment
        text_y_offset=$((segment_num % 20))
        text_jump_y=$((900 + text_y_offset * 10))
        text_size="90"
        text_color="ffffff"
        text_shadow="000000"
        glitch_effect="noise=alls=25:allf=t+u,"
        box_color="000000@0.8"
        blink_effect="enable='1'"
    fi

    # 3 different video inputs with enhanced time delays and effects
    ffmpeg -ss "$timestamp1" -i "$INPUT_VIDEO" -ss "$timestamp2" -i "$INPUT_VIDEO" -ss "$timestamp3" -i "$INPUT_VIDEO" -t $BEAT_DURATION \
        -filter_complex "
        [0:v]scale=1080:640,eq=contrast=2.2:brightness=0.4:saturation=3.5,colorchannelmixer=rr=2:gg=0:bb=0,setpts=PTS-STARTPTS[red_vid];
        [1:v]scale=1080:640,eq=contrast=2.0:brightness=0.2:saturation=3.2,colorchannelmixer=rr=0:gg=2:bb=0,setpts=PTS-STARTPTS+0.15/TB[green_vid];
        [2:v]scale=1080:640,eq=contrast=1.8:brightness=0.0:saturation=2.8,colorchannelmixer=rr=0:gg=0:bb=2,setpts=PTS-STARTPTS+0.3/TB[blue_vid];
        color=black:1080x1920[bg];
        [bg][red_vid]overlay=0:0[with_red];
        [with_red][green_vid]overlay=0:640[with_green];
        [with_green][blue_vid]overlay=0:1280[with_strips];
        [with_strips]${glitch_effect}drawtext=text='${safe_text}':fontsize=${text_size}:fontcolor=${text_color}:x=(1080-text_w)/2:y=${text_jump_y}:shadowcolor=${text_shadow}:shadowx=8:shadowy=8:box=1:boxcolor=${box_color}:boxborderw=20:${blink_effect},drawtext=text='◉ LIVE':fontsize=42:fontcolor=ff0000:x=50:y=1750:shadowcolor=000000:shadowx=4:shadowy=4:box=1:boxcolor=000000@0.9:boxborderw=12:enable='lt(mod(t,1.0),0.5)',drawtext=text='▲▲▲':fontsize=48:fontcolor=00ff00:x=950:y=100:shadowcolor=000000:shadowx=3:shadowy=3:enable='lt(mod(t,0.4),0.2)',drawtext=text='█ █ █':fontsize=32:fontcolor=ffff00:x=950:y=1750:shadowcolor=000000:shadowx=2:shadowy=2:enable='lt(mod(t,0.6),0.3)'
        " \
        -map 1:a \
        -c:v libx264 -preset ultrafast -crf 23 \
        -c:a aac -b:a 128k \
        -y "$segment_file"

    if [ -f "$segment_file" ] && [ -s "$segment_file" ]; then
        echo "  ✅ Segment $segment_num created"
    else
        echo "  ❌ Failed segment $segment_num"
    fi

    segment_num=$((segment_num + 1))

    if [ $((segment_num % 20)) -eq 0 ]; then
        echo "  🎞️ $segment_num/$NUM_CUTS segments processed"
    fi

done < "$TEMP_DIR/sorted_timestamps.txt"

# Create filelist
echo "📝 Creating segment list..."
> "$TEMP_DIR/filelist.txt"

valid_segments=0
for i in $(seq 0 $((segment_num-1))); do
    segment_file="$TEMP_DIR/segment_${i}.mp4"
    if [ -f "$segment_file" ] && [ -s "$segment_file" ]; then
        echo "file '$(pwd)/$segment_file'" >> "$TEMP_DIR/filelist.txt"
        valid_segments=$((valid_segments + 1))
    fi
done

echo "✅ Found $valid_segments valid segments"

# Final concatenation
echo "🔗 Final assembly..."

if [ ! -s "$TEMP_DIR/filelist.txt" ]; then
    echo "❌ Error: No valid segments created!"
    exit 1
fi

ffmpeg -f concat -safe 0 -i "$TEMP_DIR/filelist.txt" \
    -c:v libx264 -preset medium -crf 20 \
    -c:a aac -b:a 128k \
    -movflags +faststart \
    -y "$OUTPUT_VIDEO"

# Cleanup
echo "🧹 Cleaning up..."
rm -rf "$TEMP_DIR"

echo ""
echo "🎞️ FILM ROLL TEST COMPLETE!"
echo "📱 Output: $OUTPUT_VIDEO"
echo "⏱️ Duration: ${TOTAL_DURATION} seconds"
echo "🎨 Test: RED/GREEN/BLUE film strips"
echo "🎬 Segments: $valid_segments"
echo ""
echo "If this is still blue, the issue is with your video source or FFmpeg build!"
