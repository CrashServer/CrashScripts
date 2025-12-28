#!/bin/bash

# Set locale to handle floating point numbers properly
export LC_NUMERIC=C

# ABSOLUTE CHAOS MACHINE - DATAMOSH INSANITY
INPUT_VIDEO="$1"
OUTPUT_VIDEO="CHAOS_DATAMOSH_INSANITY.mp4"
TEMP_DIR="temp_chaos_insanity"

# INSANE BPM - 140 BPM for maximum chaos
BEAT_DURATION=0.43  # 140 BPM
TOTAL_DURATION=50
NUM_CUTS=$((TOTAL_DURATION * 2))  # Still 100 cuts but faster

# CHAOS TEXT OVERLAYS
TEXTS=("CHAOS LAB VII" "TOPLAP STRASBOURG" "PIERRE DANGER" "NUANCE" "SHADOK" "ULTRATECH RECORDS")
CHAOS_TEXTS=("GLITCH MATRIX" "DATA BREACH" "SYSTEM OVERLOAD" "NEURAL COLLAPSE" "SIGNAL LOST" "REALITY CORRUPTED")
TEXT_DURATION=4  # Faster text changes

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

echo "💀💀💀 STARTING ABSOLUTE CHAOS MACHINE 💀💀💀"
echo "📁 Input: $INPUT_VIDEO"
echo "⏱️ Duration: ${TOTAL_DURATION} seconds"
echo "🎵 BPM: 140 (INSANE SPEED)"
echo "🌀 Mode: DATAMOSH + SLICE + CHAOS"

# Get video duration
DURATION=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$INPUT_VIDEO")
DURATION_INT=$(awk -v dur="$DURATION" 'BEGIN{printf "%.0f", dur}')

echo "📏 Original video duration: ${DURATION_INT}s"

# Generate chaotic timestamps
echo "🌀 Generating CHAOTIC timestamps..."
> "$TEMP_DIR/timestamps.txt"

# More chaotic timestamp generation
for i in $(seq 0 $((NUM_CUTS-1))); do
    # Use multiple random factors for pure chaos
    chaos_factor1=$(awk 'BEGIN{srand(); printf "%.2f", rand()}')
    chaos_factor2=$(awk 'BEGIN{srand(); printf "%.2f", rand()}')
    chaos_factor3=$(awk 'BEGIN{srand(); printf "%.2f", rand()}')

    # Combine factors for maximum unpredictability
    timestamp=$(awk -v dur="$DURATION_INT" -v c1="$chaos_factor1" -v c2="$chaos_factor2" -v c3="$chaos_factor3" 'BEGIN{
        t = (c1 * dur * 0.4) + (c2 * dur * 0.3) + (c3 * dur * 0.3)
        if(t > dur-2) t = dur-2
        if(t < 0) t = 0
        printf "%.2f", t
    }')
    echo "$timestamp" >> "$TEMP_DIR/timestamps.txt"
done

sort -n "$TEMP_DIR/timestamps.txt" > "$TEMP_DIR/sorted_timestamps.txt"

# Process segments with ABSOLUTE CHAOS
echo "🌀💀 PROCESSING WITH DATAMOSH INSANITY 💀🌀"

segment_num=0
while IFS= read -r timestamp && [ $segment_num -lt $NUM_CUTS ]; do
    if [ -z "$timestamp" ]; then
        continue
    fi

    segment_file="$TEMP_DIR/segment_${segment_num}.mp4"

    # Calculate text indices
    text_index=$(awk -v seg="$segment_num" -v beat="$BEAT_DURATION" -v txt_dur="$TEXT_DURATION" 'BEGIN{printf "%.0f", (seg * beat) / txt_dur}')
    chaos_index=$(awk -v seg="$segment_num" 'BEGIN{printf "%.0f", (seg/2) % 6}')

    num_texts=${#TEXTS[@]}
    num_chaos=${#CHAOS_TEXTS[@]}

    if [ $text_index -ge $num_texts ]; then
        text_index=$(awk -v idx="$text_index" -v num="$num_texts" 'BEGIN{printf "%.0f", idx % num}')
    fi
    if [ $chaos_index -ge $num_chaos ]; then
        chaos_index=$(awk -v idx="$chaos_index" -v num="$num_chaos" 'BEGIN{printf "%.0f", idx % num}')
    fi

    current_text="${TEXTS[$text_index]}"
    chaos_text="${CHAOS_TEXTS[$chaos_index]}"
    safe_text=$(echo "$current_text" | sed 's/[^a-zA-Z0-9 ]/_/g')
    safe_chaos=$(echo "$chaos_text" | sed 's/[^a-zA-Z0-9 ]/_/g')

    # CHAOS LEVELS - every segment is different
    chaos_level=$((segment_num % 5))

    # Calculate multiple random timestamps for DATAMOSH effect
    timestamp1="$timestamp"
    timestamp2=$(awk -v t="$timestamp" -v dur="$DURATION_INT" 'BEGIN{srand(); t2=t+(rand()*dur*0.5); if(t2>dur-2) t2=t2-dur/3; printf "%.2f", t2}')
    timestamp3=$(awk -v t="$timestamp" -v dur="$DURATION_INT" 'BEGIN{srand(); t3=t+(rand()*dur*0.7); if(t3>dur-2) t3=t3-dur/3; printf "%.2f", t3}')
    timestamp4=$(awk -v t="$timestamp" -v dur="$DURATION_INT" 'BEGIN{srand(); t4=rand()*(dur-2); printf "%.2f", t4}')
    timestamp5=$(awk -v t="$timestamp" -v dur="$DURATION_INT" 'BEGIN{srand(); t5=rand()*(dur-2); printf "%.2f", t5}')

    # COMPLETELY RANDOM AUDIO
    audio_timestamp=$(awk -v dur="$DURATION_INT" 'BEGIN{srand(); t=rand()*(dur-2); printf "%.2f", t}')

    case $chaos_level in
        0) # SLICE MODE
            echo "🔪 SLICE MODE - Segment $segment_num"
            ffmpeg -ss "$timestamp1" -i "$INPUT_VIDEO" -ss "$timestamp2" -i "$INPUT_VIDEO" -ss "$timestamp3" -i "$INPUT_VIDEO" -ss "$audio_timestamp" -i "$INPUT_VIDEO" -t $BEAT_DURATION \
                -filter_complex "
                [0:v]scale=1080:1920,eq=contrast=3:brightness=0.6:saturation=2,colorchannelmixer=rr=2:gg=0.5:bb=0.3,crop=1080:640:0:0[slice1];
                [1:v]scale=1080:1920,eq=contrast=2.5:brightness=0.3:saturation=2,colorchannelmixer=rr=0.3:gg=2:bb=0.5,crop=1080:640:0:640[slice2];
                [2:v]scale=1080:1920,eq=contrast=2:brightness=0.1:saturation=2,colorchannelmixer=rr=0.5:gg=0.3:bb=2,crop=1080:640:0:1280[slice3];
                color=black:1080x1920[bg];
                [bg][slice1]overlay=0:0:eval=frame:x='0+20*sin(t*30)':y='0+15*cos(t*25)'[with_slice1];
                [with_slice1][slice2]overlay=0:640:eval=frame:x='0+15*cos(t*35)':y='640+10*sin(t*40)'[with_slice2];
                [with_slice2][slice3]overlay=0:1280:eval=frame:x='0+10*sin(t*45)':y='1280+20*cos(t*20)'[sliced];
                [sliced]noise=alls=80:allf=t+u,drawtext=text='${safe_text}':fontsize=200:fontcolor=ff0000:x='(1080-text_w)/2+50*sin(t*20)':y='200+100*cos(t*15)':shadowcolor=ffffff:shadowx=20:shadowy=20:box=1:boxcolor=00ff00@0.9:boxborderw=40:enable='lt(mod(t,0.1),0.05)',drawtext=text='${safe_chaos}':fontsize=60:fontcolor=ffff00:x='100+30*sin(t*50)':y='1700+50*cos(t*30)':shadowcolor=000000:shadowx=8:shadowy=8:enable='lt(mod(t,0.2),0.1)',drawtext=text='NUANCE YT 8PM':fontsize=32:fontcolor=00ff00:x='(1080-text_w)/2+10*sin(t*10)':y='1850+5*cos(t*15)':shadowcolor=000000:shadowx=4:shadowy=4:box=1:boxcolor=ff0000@0.8:boxborderw=10
                " \
                -map 3:a -c:v libx264 -preset ultrafast -crf 18 -c:a aac -b:a 128k -y "$segment_file"
            ;;
        1) # DATAMOSH MODE
            echo "🌀 DATAMOSH MODE - Segment $segment_num"
            ffmpeg -ss "$timestamp1" -i "$INPUT_VIDEO" -ss "$timestamp2" -i "$INPUT_VIDEO" -ss "$timestamp3" -i "$INPUT_VIDEO" -ss "$timestamp4" -i "$INPUT_VIDEO" -ss "$audio_timestamp" -i "$INPUT_VIDEO" -t $BEAT_DURATION \
                -filter_complex "
                [0:v]scale=540:960,eq=contrast=4:brightness=0.8:saturation=2,colorchannelmixer=rr=2:gg=0:bb=0[red_mosh];
                [1:v]scale=540:960,eq=contrast=3:brightness=0.5:saturation=2,colorchannelmixer=rr=0:gg=2:bb=0[green_mosh];
                [2:v]scale=540:960,eq=contrast=2:brightness=0.2:saturation=2,colorchannelmixer=rr=0:gg=0:bb=2[blue_mosh];
                [3:v]scale=270:480,eq=contrast=5:brightness=1:saturation=2[mini_mosh];
                color=black:1080x1920[bg];
                [bg][red_mosh]overlay=0:0:eval=frame:x='0+100*sin(t*50)':y='0+80*cos(t*60)'[bg1];
                [bg1][green_mosh]overlay=540:0:eval=frame:x='540+80*cos(t*70)':y='0+60*sin(t*80)'[bg2];
                [bg2][blue_mosh]overlay=0:960:eval=frame:x='0+60*sin(t*90)':y='960+100*cos(t*40)'[bg3];
                [bg3][mini_mosh]overlay=540:960:eval=frame:x='540+150*sin(t*100)':y='960+120*cos(t*110)'[moshed];
                [moshed]noise=alls=100:allf=t+u,drawtext=text='${safe_text}':fontsize=150:fontcolor=00ff00:x='(1080-text_w)/2+80*sin(t*25)':y='400+150*cos(t*20)':shadowcolor=ff0000:shadowx=25:shadowy=25:box=1:boxcolor=ffff00@0.9:boxborderw=50:enable='lt(mod(t,0.15),0.075)',drawtext=text='DATAMOSH':fontsize=80:fontcolor=ff00ff:x='50+100*sin(t*60)':y='100+80*cos(t*45)':shadowcolor=000000:shadowx=10:shadowy=10:enable='lt(mod(t,0.3),0.1)',drawtext=text='NUANCE YT 8PM':fontsize=28:fontcolor=ffffff:x='(1080-text_w)/2+15*sin(t*12)':y='1850+8*cos(t*18)':shadowcolor=000000:shadowx=4:shadowy=4:box=1:boxcolor=ff0000@0.8:boxborderw=8
                " \
                -map 4:a -c:v libx264 -preset ultrafast -crf 18 -c:a aac -b:a 128k -y "$segment_file"
            ;;
        2) # MIRROR CHAOS MODE
            echo "🪞 MIRROR CHAOS - Segment $segment_num"
            ffmpeg -ss "$timestamp1" -i "$INPUT_VIDEO" -ss "$timestamp2" -i "$INPUT_VIDEO" -ss "$audio_timestamp" -i "$INPUT_VIDEO" -t $BEAT_DURATION \
                -filter_complex "
                [0:v]scale=1080:960,eq=contrast=3:brightness=0.4:saturation=2,colorchannelmixer=rr=1.5:gg=1.5:bb=0.5[main];
                [1:v]scale=1080:960,eq=contrast=2.5:brightness=0.6:saturation=2,colorchannelmixer=rr=0.5:gg=1.5:bb=1.5,vflip[mirror];
                color=black:1080x1920[bg];
                [bg][main]overlay=0:0:eval=frame:x='0+30*sin(t*40)':y='0+20*cos(t*30)'[with_main];
                [with_main][mirror]overlay=0:960:eval=frame:x='0+20*cos(t*50)':y='960+30*sin(t*35)'[mirrored];
                [mirrored]noise=alls=70:allf=t+u,drawtext=text='${safe_text}':fontsize=180:fontcolor=ffffff:x='(1080-text_w)/2+60*sin(t*30)':y='480+100*cos(t*25)':shadowcolor=000000:shadowx=30:shadowy=30:box=1:boxcolor=ff0000@0.9:boxborderw=60:enable='lt(mod(t,0.2),0.1)',drawtext=text='MIRROR WORLD':fontsize=50:fontcolor=00ffff:x='200+80*sin(t*40)':y='1400+60*cos(t*35)':shadowcolor=000000:shadowx=6:shadowy=6:enable='lt(mod(t,0.4),0.2)',drawtext=text='NUANCE YT 8PM':fontsize=30:fontcolor=ffff00:x='(1080-text_w)/2+12*sin(t*8)':y='1850+6*cos(t*12)':shadowcolor=000000:shadowx=4:shadowy=4:box=1:boxcolor=ff0000@0.8:boxborderw=10
                " \
                -map 2:a -c:v libx264 -preset ultrafast -crf 18 -c:a aac -b:a 128k -y "$segment_file"
            ;;
        3) # KALEIDOSCOPE MODE
            echo "🌈 KALEIDOSCOPE - Segment $segment_num"
            ffmpeg -ss "$timestamp1" -i "$INPUT_VIDEO" -ss "$timestamp2" -i "$INPUT_VIDEO" -ss "$timestamp3" -i "$INPUT_VIDEO" -ss "$audio_timestamp" -i "$INPUT_VIDEO" -t $BEAT_DURATION \
                -filter_complex "
                [0:v]scale=360:640,eq=contrast=4:brightness=0.7:saturation=2,colorchannelmixer=rr=2:gg=0.5:bb=0.5[k1];
                [1:v]scale=360:640,eq=contrast=3:brightness=0.4:saturation=2,colorchannelmixer=rr=0.5:gg=2:bb=0.5[k2];
                [2:v]scale=360:640,eq=contrast=2:brightness=0.1:saturation=2,colorchannelmixer=rr=0.5:gg=0.5:bb=2[k3];
                color=black:1080x1920[bg];
                [bg][k1]overlay=0:0:eval=frame:x='0+50*sin(t*80)':y='0+40*cos(t*90)'[bg1];
                [bg1][k2]overlay=360:0:eval=frame:x='360+40*cos(t*100)':y='0+30*sin(t*110)'[bg2];
                [bg2][k3]overlay=720:0:eval=frame:x='720+30*sin(t*120)':y='0+50*cos(t*70)'[bg3];
                [bg3][k1]overlay=0:640:eval=frame:x='0+60*cos(t*60)':y='640+70*sin(t*50)'[bg4];
                [bg4][k2]overlay=360:640:eval=frame:x='360+70*sin(t*40)':y='640+80*cos(t*30)'[bg5];
                [bg5][k3]overlay=720:640:eval=frame:x='720+80*cos(t*20)':y='640+90*sin(t*10)'[bg6];
                [bg6][k1]overlay=0:1280:eval=frame:x='0+90*sin(t*130)':y='1280+100*cos(t*140)'[bg7];
                [bg7][k2]overlay=360:1280:eval=frame:x='360+100*cos(t*150)':y='1280+60*sin(t*160)'[bg8];
                [bg8][k3]overlay=720:1280:eval=frame:x='720+60*sin(t*170)':y='1280+50*cos(t*180)'[kaleidoscope];
                [kaleidoscope]noise=alls=90:allf=t+u,drawtext=text='${safe_text}':fontsize=120:fontcolor=ff00ff:x='(1080-text_w)/2+100*sin(t*35)':y='960+200*cos(t*40)':shadowcolor=00ffff:shadowx=40:shadowy=40:box=1:boxcolor=ffffff@0.9:boxborderw=80:enable='lt(mod(t,0.12),0.06)',drawtext=text='KALEIDOSCOPE':fontsize=40:fontcolor=ffff00:x='400+120*sin(t*70)':y='200+100*cos(t*80)':shadowcolor=000000:shadowx=8:shadowy=8:enable='lt(mod(t,0.25),0.125)',drawtext=text='NUANCE YT 8PM':fontsize=26:fontcolor=00ff00:x='(1080-text_w)/2+8*sin(t*6)':y='1850+4*cos(t*9)':shadowcolor=000000:shadowx=3:shadowy=3:box=1:boxcolor=ff0000@0.8:boxborderw=6
                " \
                -map 3:a -c:v libx264 -preset ultrafast -crf 18 -c:a aac -b:a 128k -y "$segment_file"
            ;;
        4) # TOTAL CHAOS MODE
            echo "💀 TOTAL CHAOS - Segment $segment_num"
            ffmpeg -ss "$timestamp1" -i "$INPUT_VIDEO" -ss "$timestamp2" -i "$INPUT_VIDEO" -ss "$timestamp3" -i "$INPUT_VIDEO" -ss "$timestamp4" -i "$INPUT_VIDEO" -ss "$timestamp5" -i "$INPUT_VIDEO" -ss "$audio_timestamp" -i "$INPUT_VIDEO" -t $BEAT_DURATION \
                -filter_complex "
                [0:v]scale=200:400,eq=contrast=5:brightness=1:saturation=2,colorchannelmixer=rr=2:gg=0:bb=0[chaos1];
                [1:v]scale=300:600,eq=contrast=4:brightness=0.8:saturation=2,colorchannelmixer=rr=0:gg=2:bb=0[chaos2];
                [2:v]scale=400:800,eq=contrast=3:brightness=0.6:saturation=2,colorchannelmixer=rr=0:gg=0:bb=2[chaos3];
                [3:v]scale=150:300,eq=contrast=6:brightness=1.2:saturation=2,colorchannelmixer=rr=1.5:gg=1.5:bb=0[chaos4];
                [4:v]scale=250:500,eq=contrast=2:brightness=0.4:saturation=2,colorchannelmixer=rr=0.5:gg=0.5:bb=1.5[chaos5];
                color=black:1080x1920[bg];
                [bg][chaos1]overlay=0:0:eval=frame:x='0+200*sin(t*100)':y='0+300*cos(t*120)'[bg1];
                [bg1][chaos2]overlay=200:400:eval=frame:x='200+150*cos(t*80)':y='400+200*sin(t*140)'[bg2];
                [bg2][chaos3]overlay=500:800:eval=frame:x='500+100*sin(t*60)':y='800+250*cos(t*160)'[bg3];
                [bg3][chaos4]overlay=100:1200:eval=frame:x='100+300*cos(t*40)':y='1200+150*sin(t*180)'[bg4];
                [bg4][chaos5]overlay=800:200:eval=frame:x='800+250*sin(t*20)':y='200+100*cos(t*200)'[total_chaos];
                [total_chaos]noise=alls=100:allf=t+u,drawtext=text='${safe_text}':fontsize=250:fontcolor=ffffff:x='(1080-text_w)/2+200*sin(t*50)':y='600+400*cos(t*30)':shadowcolor=000000:shadowx=50:shadowy=50:box=1:boxcolor=ff0000@0.95:boxborderw=100:enable='lt(mod(t,0.08),0.04)',drawtext=text='TOTAL CHAOS':fontsize=60:fontcolor=ff0000:x='300+200*sin(t*90)':y='1600+150*cos(t*70)':shadowcolor=ffffff:shadowx=12:shadowy=12:enable='lt(mod(t,0.1),0.05)',drawtext=text='NUANCE YT 8PM':fontsize=24:fontcolor=ffff00:x='(1080-text_w)/2+20*sin(t*15)':y='1850+10*cos(t*20)':shadowcolor=000000:shadowx=3:shadowy=3:box=1:boxcolor=ff0000@0.8:boxborderw=5
                " \
                -map 5:a -c:v libx264 -preset ultrafast -crf 18 -c:a aac -b:a 128k -y "$segment_file"
            ;;
    esac

    if [ -f "$segment_file" ] && [ -s "$segment_file" ]; then
        echo "  ✅ CHAOS segment $segment_num created"
    else
        echo "  ❌ Failed chaos segment $segment_num"
    fi

    segment_num=$((segment_num + 1))

    if [ $((segment_num % 10)) -eq 0 ]; then
        echo "  🌀💀 $segment_num/$NUM_CUTS CHAOS segments processed 💀🌀"
    fi

done < "$TEMP_DIR/sorted_timestamps.txt"

# Create filelist
echo "📝 Creating CHAOS segment list..."
> "$TEMP_DIR/filelist.txt"

valid_segments=0
for i in $(seq 0 $((segment_num-1))); do
    segment_file="$TEMP_DIR/segment_${i}.mp4"
    if [ -f "$segment_file" ] && [ -s "$segment_file" ]; then
        echo "file '$(pwd)/$segment_file'" >> "$TEMP_DIR/filelist.txt"
        valid_segments=$((valid_segments + 1))
    fi
done

echo "✅ Found $valid_segments CHAOS segments"

# Final concatenation with extra chaos
echo "🔗 Final CHAOS ASSEMBLY..."

if [ ! -s "$TEMP_DIR/filelist.txt" ]; then
    echo "❌ Error: No valid segments created!"
    exit 1
fi

# Add final chaos layer
ffmpeg -f concat -safe 0 -i "$TEMP_DIR/filelist.txt" \
    -vf "noise=alls=20:allf=t+u,drawtext=text='CHAOS LAB VII DATAMOSH':fontsize=40:fontcolor=ff0000:x='(1080-text_w)/2+50*sin(t*10)':y='50+30*cos(t*15)':shadowcolor=ffffff:shadowx=6:shadowy=6:enable='lt(mod(t,2),0.5)'" \
    -c:v libx264 -preset medium -crf 16 \
    -c:a aac -b:a 128k \
    -movflags +faststart \
    -y "$OUTPUT_VIDEO"

# Cleanup
echo "🧹 Cleaning up chaos..."
rm -rf "$TEMP_DIR"

echo ""
echo "💀🌀💀🌀💀 ABSOLUTE CHAOS COMPLETE! 💀🌀💀🌀💀"
echo "📱 INSANE video: $OUTPUT_VIDEO"
echo "⏱️ Duration: ${TOTAL_DURATION} seconds"
echo "🎵 BPM: 140 (INSANE)"
echo "🌀 Modes: SLICE + DATAMOSH + MIRROR + KALEIDOSCOPE + TOTAL CHAOS"
echo "🎬 Segments: $valid_segments CHAOS segments"
echo "💀 WARNING: MAY CAUSE SEIZURES!"
echo ""
echo "🔥🔥🔥 READY FOR CHAOS LAB VII! 🔥🔥🔥"
