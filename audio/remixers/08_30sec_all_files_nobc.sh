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
OUTPUT_PREFIX="30sec_maxmix"
SEQUENCE_DURATION=30
NUM_SEQUENCES=10

# Find all audio files
echo "Finding audio files..."
mapfile -t audio_files < <(find . -maxdepth 1 -type f \( -iname "*.ogg" -o -iname "*.wav" -o -iname "*.mp3" \) | sort)

if [ ${#audio_files[@]} -eq 0 ]; then
    echo "No audio files (ogg, wav, mp3) found in the current directory."
    exit 1
fi

echo "Found ${#audio_files[@]} audio files - will use ALL of them in each mix!"
echo

# Function to get random segment from file
extract_random_segment() {
    local input_file="$1"
    local output_file="$2"
    local seg_duration="$3"
    local effect="$4"
    
    # Get file duration (integer seconds)
    duration=$(ffmpeg -i "$input_file" 2>&1 | grep "Duration" | cut -d ' ' -f 4 | sed s/,// | awk -F: '{ print int(($1 * 3600) + ($2 * 60) + $3) }')
    
    # Random start
    if [ -n "$duration" ] && [ "$duration" -gt "$seg_duration" ]; then
        start=$((RANDOM % (duration - seg_duration)))
    else
        start=0
    fi
    
    # Apply different effects
    case $effect in
        0) # Clean
            ffmpeg -ss $start -i "$input_file" -t $seg_duration -af "afade=t=in:d=0.2,afade=t=out:d=0.2" -acodec pcm_s16le -ar 44100 "$output_file" -y 2>/dev/null
            ;;
        1) # Pitch up
            ffmpeg -ss $start -i "$input_file" -t $seg_duration -af "afade=t=in:d=0.2,afade=t=out:d=0.2,asetrate=44100*1.5,atempo=0.667" -acodec pcm_s16le -ar 44100 "$output_file" -y 2>/dev/null
            ;;
        2) # Pitch down
            ffmpeg -ss $start -i "$input_file" -t $seg_duration -af "afade=t=in:d=0.2,afade=t=out:d=0.2,asetrate=44100*0.8,atempo=1.25" -acodec pcm_s16le -ar 44100 "$output_file" -y 2>/dev/null
            ;;
        3) # Reverse
            ffmpeg -ss $start -i "$input_file" -t $seg_duration -af "afade=t=in:d=0.2,afade=t=out:d=0.2,areverse" -acodec pcm_s16le -ar 44100 "$output_file" -y 2>/dev/null
            ;;
        4) # Echo
            ffmpeg -ss $start -i "$input_file" -t $seg_duration -af "afade=t=in:d=0.2,afade=t=out:d=0.2,aecho=0.8:0.88:120:0.4" -acodec pcm_s16le -ar 44100 "$output_file" -y 2>/dev/null
            ;;
        5) # Distortion
            ffmpeg -ss $start -i "$input_file" -t $seg_duration -af "afade=t=in:d=0.2,afade=t=out:d=0.2,overdrive=10:20" -acodec pcm_s16le -ar 44100 "$output_file" -y 2>/dev/null
            ;;
        6) # Phaser
            ffmpeg -ss $start -i "$input_file" -t $seg_duration -af "afade=t=in:d=0.2,afade=t=out:d=0.2,aphaser=in_gain=0.4" -acodec pcm_s16le -ar 44100 "$output_file" -y 2>/dev/null
            ;;
        7) # Tremolo
            ffmpeg -ss $start -i "$input_file" -t $seg_duration -af "afade=t=in:d=0.2,afade=t=out:d=0.2,tremolo=5:0.9" -acodec pcm_s16le -ar 44100 "$output_file" -y 2>/dev/null
            ;;
    esac
}

echo "Creating $NUM_SEQUENCES 30-second mixes using ALL ${#audio_files[@]} files..."

for seq_num in $(seq 1 $NUM_SEQUENCES); do
    echo
    echo "=== Creating sequence $seq_num ==="
    echo "This mix will include elements from ALL ${#audio_files[@]} files"
    
    all_segments=()
    
    # Process EVERY file
    for i in "${!audio_files[@]}"; do
        file="${audio_files[$i]}"
        base_name=$(basename "$file")
        
        # Determine how many segments this file contributes (1-4)
        num_segments=$((1 + RANDOM % 4))
        
        echo -n "  Processing $base_name: "
        
        for seg in $(seq 1 $num_segments); do
            # Random segment duration (1 to 5 seconds)
            seg_duration=$((1 + RANDOM % 5))
            
            # Random effect
            effect=$((RANDOM % 8))
            
            # Extract segment
            seg_file="seg_${seq_num}_${i}_${seg}.wav"
            extract_random_segment "$file" "$seg_file" "$seg_duration" "$effect"
            
            if [ -f "$seg_file" ]; then
                # Random volume (10% to 80%)
                volume_percent=$((10 + RANDOM % 71))
                volume=$(awk "BEGIN {print $volume_percent / 100}")
                
                # Apply volume and additional processing
                processed_file="proc_${seq_num}_${i}_${seg}.wav"
                
                # Random additional processing
                proc=$((RANDOM % 4))
                case $proc in
                    0) # Just volume
                        sox "$seg_file" "$processed_file" vol $volume
                        ;;
                    1) # Low-pass filter
                        sox "$seg_file" "$processed_file" vol $volume lowpass 2000
                        ;;
                    2) # High-pass filter
                        sox "$seg_file" "$processed_file" vol $volume highpass 500
                        ;;
                    3) # Reverb
                        sox "$seg_file" "$processed_file" vol $volume reverb 50
                        ;;
                esac
                
                # Random position in the 30-second timeline (0-28 seconds)
                position=$((RANDOM % 29))
                
                # Create positioned segment
                final_seg="final_${seq_num}_${i}_${seg}.wav"
                sox -n -r 44100 -c 2 "$final_seg" trim 0 30
                sox "$final_seg" "$processed_file" "temp_mix.wav" splice -q $position
                mv "temp_mix.wav" "$final_seg"
                
                all_segments+=("$final_seg")
                
                # Clean up
                rm -f "$seg_file" "$processed_file"
                
                echo -n "."
            fi
        done
        echo " done"
    done
    
    # Mix all segments together
    output_file=$(printf "%s_%02d.wav" "$OUTPUT_PREFIX" "$seq_num")
    echo "  Mixing ${#all_segments[@]} segments from ${#audio_files[@]} files..."
    
    if [ ${#all_segments[@]} -gt 0 ]; then
        # First mix all segments
        sox -m "${all_segments[@]}" "premix_${seq_num}.wav"
        
        # Final processing: normalize, compress, ensure 30 seconds
        sox "premix_${seq_num}.wav" "$output_file" \
            compand 0.3,1 6:-70,-60,-20 -5 -90 0.2 \
            norm -3 \
            fade t 0.5 30 0.5 \
            trim 0 30
        
        # Clean up
        rm -f "${all_segments[@]}" "premix_${seq_num}.wav"
    fi
    
    # Verify duration
    final_duration=$(soxi -D "$output_file" 2>/dev/null || echo "unknown")
    echo "  Created: $output_file (duration: ${final_duration}s)"
    echo "  Total segments used: ${#all_segments[@]}"
done

echo
echo "Done! Created $NUM_SEQUENCES 30-second mixes:"
ls -la ${OUTPUT_PREFIX}_*.wav

# Final verification
echo
echo "Duration verification:"
for f in ${OUTPUT_PREFIX}_*.wav; do
    duration=$(soxi -D "$f" 2>/dev/null || echo "error")
    channels=$(soxi -c "$f" 2>/dev/null || echo "?")
    rate=$(soxi -r "$f" 2>/dev/null || echo "?")
    echo "  $f: ${duration}s, ${channels}ch, ${rate}Hz"
done