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
TEXTS=("GENERATIVE AUDIO" "PROTOTYPE")
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

    # Calculate different timestamps with more chaos + separate audio timestamp
    timestamp1="$timestamp"
    timestamp2=$(awk -v t="$timestamp" -v dur="$DURATION_INT" 'BEGIN{t2=t+(dur/4); if(t2>dur-2) t2=t2-dur/3; printf "%.2f", t2}')
    timestamp3=$(awk -v t="$timestamp" -v dur="$DURATION_INT" 'BEGIN{t3=t+(dur*3/4); if(t3>dur-2) t3=t3-dur/3; printf "%.2f", t3}')

    # SEPARATE AUDIO TIMESTAMP - completely random from whole video
    audio_timestamp=$(awk -v dur="$DURATION_INT" 'BEGIN{srand(); t=rand()*(dur-2); printf "%.2f", t}')

    echo "Video: $timestamp1, $timestamp2, $timestamp3 | Audio: $audio_timestamp"

    # Ultra dynamic scene changes (every 3 segments for maximum chaos)
    is_mega_glitch=$((segment_num % 3))

    if [ $is_mega_glitch -eq 0 ] && [ $segment_num -gt 0 ]; then
        # MEGA GLITCH MODE
        text_jump_y="100"
        text_size="180"
        text_color="00ff00"
        text_shadow="ff0000"
        glitch_effect="noise=alls=100:allf=t+u,"
        box_color="ff0000@0.95"
        video_brightness="0.8"
        video_contrast="3.0"
        video_saturation="2.0"
        blink_speed="0.08"
        overlay_shake="8"
    elif [ $is_mega_glitch -eq 1 ]; then
        # MEDIUM GLITCH MODE
        text_jump_y="$((500 + (segment_num * 100) % 600))"
        text_size="140"
        text_color="ffff00"
        text_shadow="ff00ff"
        glitch_effect="noise=alls=60:allf=t+u,"
        box_color="0000ff@0.9"
        video_brightness="0.4"
        video_contrast="2.5"
        video_saturation="2.0"
        blink_speed="0.15"
        overlay_shake="5"
    else
        # NORMAL CYBERPUNK MODE
        text_jump_y="$((700 + (segment_num * 50) % 400))"
        text_size="110"
        text_color="ffffff"
        text_shadow="000000"
        glitch_effect="noise=alls=30:allf=t+u,"
        box_color="000000@0.85"
        video_brightness="0.2"
        video_contrast="2.0"
        video_saturation="2.0"
        blink_speed="0.3"
        overlay_shake="2"
    fi

    # CYBERPUNK MATRIX with diverse audio + YouTube promo
    ffmpeg -ss "$timestamp1" -i "$INPUT_VIDEO" -ss "$timestamp2" -i "$INPUT_VIDEO" -ss "$timestamp3" -i "$INPUT_VIDEO" -ss "$audio_timestamp" -i "$INPUT_VIDEO" -t $BEAT_DURATION \
        -filter_complex "
        [0:v]scale=1080:640,eq=contrast=${video_contrast}:brightness=${video_brightness}:saturation=${video_saturation},colorchannelmixer=rr=2:gg=0.3:bb=0.2,setpts=PTS-STARTPTS+0.05/TB[red_vid];
        [1:v]scale=1080:640,eq=contrast=${video_contrast}:brightness=${video_brightness}:saturation=${video_saturation},colorchannelmixer=rr=0.2:gg=2:bb=0.3,setpts=PTS-STARTPTS+0.15/TB[green_vid];
        [2:v]scale=1080:640,eq=contrast=${video_contrast}:brightness=${video_brightness}:saturation=${video_saturation},colorchannelmixer=rr=0.3:gg=0.2:bb=2,setpts=PTS-STARTPTS+0.25/TB[blue_vid];
        color=black:1080x1920[bg];
        [bg][red_vid]overlay=0:0:eval=frame:x='0+${overlay_shake}*sin(t*10)':y='0+${overlay_shake}*cos(t*8)'[with_red];
        [with_red][green_vid]overlay=0:640:eval=frame:x='0+${overlay_shake}*cos(t*12)':y='640+${overlay_shake}*sin(t*9)'[with_green];
        [with_green][blue_vid]overlay=0:1280:eval=frame:x='0+${overlay_shake}*sin(t*14)':y='1280+${overlay_shake}*cos(t*11)'[with_strips];
        [with_strips]${glitch_effect}drawgrid=w=1080:h=8:t=2:c=00ff00@0.2,drawtext=text='${safe_text}':fontsize=${text_size}:fontcolor=${text_color}:x='(1080-text_w)/2+15*sin(t*6)':y='${text_jump_y}+25*cos(t*4)':shadowcolor=${text_shadow}:shadowx=15:shadowy=15:box=1:boxcolor=${box_color}:boxborderw=30:enable='lt(mod(t,${blink_speed}),${blink_speed}/2)',drawtext=text='◉ NEURAL LINK':fontsize=38:fontcolor=00ff00:x='60+8*sin(t*20)':y='60+6*cos(t*15)':shadowcolor=000000:shadowx=4:shadowy=4:box=1:boxcolor=000000@0.9:boxborderw=10:enable='lt(mod(t,0.7),0.35)',drawtext=text='▓▓ CHAOS MATRIX ▓▓':fontsize=32:fontcolor=ff0000:x='50+12*cos(t*18)':y='1780+8*sin(t*22)':shadowcolor=ffffff:shadowx=3:shadowy=3:box=1:boxcolor=ff0000@0.8:boxborderw=8:enable='lt(mod(t,0.5),0.25)',drawtext=text='>>> DATA BREACH':fontsize=40:fontcolor=ffff00:x='780+20*sin(t*25)':y='120+15*cos(t*30)':shadowcolor=000000:shadowx=5:shadowy=5:enable='lt(mod(t,0.3),0.15)',drawtext=text='SIGNAL LOST':fontsize=28:fontcolor=ff00ff:x='820+10*cos(t*35)':y='1720+12*sin(t*28)':shadowcolor=000000:shadowx=3:shadowy=3:enable='lt(mod(t,1.0),0.1)',drawtext=text='█':fontsize=250:fontcolor=00ff00@0.4:x='950+30*sin(t*40)':y='850+20*cos(t*45)':enable='lt(mod(t,0.15),0.05)',drawtext=text='VIDEO ON NUANCE YT CHANNEL AT 8 PM':fontsize=28:fontcolor=ffff00:x='(1080-text_w)/2+5*sin(t*8)':y='1850+3*cos(t*12)':shadowcolor=000000:shadowx=3:shadowy=3:box=1:boxcolor=ff0000@0.9:boxborderw=8:enable='lt(mod(t,1.5),0.8)'
        " \
        -map 3:a \
        -c:v libx264 -preset ultrafast -crf 20 \
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
