#!/bin/bash

# Check dependencies
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed."
    exit 1
fi

if ! command -v sox &> /dev/null; then
    echo "Error: sox is not installed."
    exit 1
fi

# Output settings
OUTPUT_PREFIX="30sec_mix"
SEQUENCE_DURATION=30
NUM_SEQUENCES=10

# Find all audio files
echo "Finding audio files..."
mapfile -t audio_files < <(find . -maxdepth 1 -type f \( -iname "*.ogg" -o -iname "*.wav" -o -iname "*.mp3" \) ! -name "30sec_*.wav" ! -name "base_*.wav" ! -name "temp_*.wav" | sort)

if [ ${#audio_files[@]} -eq 0 ]; then
    echo "No audio files found."
    exit 1
fi

echo "Found ${#audio_files[@]} audio files"
echo

echo "Creating $NUM_SEQUENCES dense 30-second mixes..."

for seq_num in $(seq 1 $NUM_SEQUENCES); do
    echo
    echo "=== Creating sequence $seq_num ==="
    
    # Create segments from all files
    segment_files=()
    
    # Shuffle files for variety
    mapfile -t shuffled_files < <(printf '%s\n' "${audio_files[@]}" | sort -R)
    
    # Process each file
    for i in "${!shuffled_files[@]}"; do
        file="${shuffled_files[$i]}"
        base_name=$(basename "$file")
        
        # Skip if we already have enough segments
        if [ ${#segment_files[@]} -gt 40 ]; then
            break
        fi
        
        echo -n "  Processing $base_name: "
        
        # Get file duration
        echo -n "getting duration..."
        duration=$(ffmpeg -i "$file" 2>&1 | grep Duration | awk '{print $2}' | tr -d , | awk -F: '{print ($1*3600)+($2*60)+$3}' | cut -d. -f1)
        if [ -z "$duration" ] || [ "$duration" -eq 0 ]; then
            echo -n "(using default 10s)..."
            duration=10
        else
            echo -n "(${duration}s)..."
        fi
        
        # Create 1-2 segments from this file
        num_segments=$((1 + RANDOM % 2))
        
        echo -n "creating $num_segments segments..."
        
        for seg in $(seq 1 $num_segments); do
            # Segment duration 2-6 seconds
            seg_duration=$((2 + RANDOM % 5))
            echo -n "[seg$seg:${seg_duration}s"
            
            # Random start position
            if [ "$duration" -gt "$seg_duration" ]; then
                start=$((RANDOM % (duration - seg_duration)))
            else
                start=0
                seg_duration=$duration
            fi
            echo -n "@${start}s]"
            
            # Extract segment
            seg_file="temp_seg_${seq_num}_${i}_${seg}.wav"
            echo -n "[extracting]"
            ffmpeg -y -ss $start -i "$file" -t $seg_duration -acodec pcm_s16le -ar 44100 -ac 2 "$seg_file" 2>/dev/null
            
            if [ -f "$seg_file" ] && [ -s "$seg_file" ]; then
                echo -n "[exists]"
                # Apply random effect
                effect=$((RANDOM % 5))
                effect_file="temp_fx_${seq_num}_${i}_${seg}.wav"
                
                echo -n "[fx:$effect]"
                case $effect in
                    0) echo -n "[clean]"; cp "$seg_file" "$effect_file" ;;
                    1) echo -n "[pitch]"; sox "$seg_file" "$effect_file" pitch 200 2>/dev/null || cp "$seg_file" "$effect_file" ;;
                    2) echo -n "[reverse]"; sox "$seg_file" "$effect_file" reverse 2>/dev/null || cp "$seg_file" "$effect_file" ;;
                    3) echo -n "[echo]"; sox "$seg_file" "$effect_file" echo 0.8 0.9 60 0.4 2>/dev/null || cp "$seg_file" "$effect_file" ;;
                    4) echo -n "[reverb]"; sox "$seg_file" "$effect_file" reverb 40 2>/dev/null || cp "$seg_file" "$effect_file" ;;
                esac
                
                # Apply volume and fade
                final_file="temp_final_${seq_num}_${i}_${seg}.wav"
                volume="0.$((3 + RANDOM % 5))"  # 0.3 to 0.7
                echo -n "[vol:$volume]"
                sox "$effect_file" "$final_file" fade 0.1 0 0.1 vol $volume 2>/dev/null
                
                if [ -f "$final_file" ] && [ -s "$final_file" ]; then
                    segment_files+=("$final_file")
                    echo -n "[OK]"
                else
                    echo -n "[FAILED]"
                fi
                
                rm -f "$seg_file" "$effect_file"
            else
                echo -n "[EXTRACT FAILED]"
                rm -f "$seg_file"
            fi
        done
        echo " done"
    done
    
    echo "  Total segments: ${#segment_files[@]}"
    
    # Create the final mix
    if [ ${#segment_files[@]} -gt 0 ]; then
        output_file=$(printf "%s_%02d.wav" "$OUTPUT_PREFIX" "$seq_num")
        
        # Build ffmpeg command for mixing with random delays
        echo "  Creating final mix..."
        
        # Create filter complex for overlapping
        filter=""
        inputs=""
        
        for i in "${!segment_files[@]}"; do
            inputs="$inputs -i ${segment_files[$i]}"
            # Random delay between 0 and 25 seconds
            delay=$((RANDOM % 25000))
            filter="${filter}[${i}:a]adelay=${delay}|${delay}[d${i}];"
        done
        
        # Mix all delayed inputs
        for i in "${!segment_files[@]}"; do
            filter="${filter}[d${i}]"
        done
        filter="${filter}amix=inputs=${#segment_files[@]}:duration=longest[out]"
        
        # Execute mix
        ffmpeg -y $inputs -filter_complex "$filter" -map "[out]" -t 30 "temp_premix_${seq_num}.wav" 2>/dev/null
        
        # Final processing
        sox "temp_premix_${seq_num}.wav" "$output_file" \
            norm -2 \
            fade 0.5 30 0.5 \
            trim 0 30 2>/dev/null
        
        # Verify
        if [ -f "$output_file" ]; then
            duration=$(soxi -D "$output_file" 2>/dev/null || echo "unknown")
            echo "  Created: $output_file (${duration}s)"
        else
            echo "  ERROR: Failed to create output file"
        fi
        
        # Cleanup
        rm -f temp_premix_${seq_num}.wav ${segment_files[@]}
    fi
done

# Final cleanup
rm -f temp_*.wav

echo
echo "Done! Created mixes:"
ls -la ${OUTPUT_PREFIX}_*.wav

# Verification
echo
echo "Duration check:"
for f in ${OUTPUT_PREFIX}_*.wav; do
    if [ -f "$f" ]; then
        duration=$(soxi -D "$f" 2>/dev/null || echo "error")
        echo "  $f: ${duration}s"
    fi
done