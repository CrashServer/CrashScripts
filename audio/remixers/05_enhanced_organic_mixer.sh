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
OUTPUT_PREFIX="30sec_organic_mix"
SEQUENCE_DURATION=30
MIN_FILES_PER_SEQUENCE=5  # Increased minimum for more variety
MAX_FILES_PER_SEQUENCE=10 # Use up to 10 files per sequence
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
    echo "Warning: Only ${#audio_files[@]} files found. Will use all available files."
    MIN_FILES_PER_SEQUENCE=${#audio_files[@]}
fi

# Convert all files to a standard format and analyze
echo "Converting files to standard format and analyzing..."
rm -f temp_*.wav
declare -a converted_files
declare -a file_durations

for i in "${!audio_files[@]}"; do
    input_file="${audio_files[$i]}"
    temp_file="temp_$(printf "%04d" $i).wav"
    
    echo "Converting: $(basename "$input_file")"
    ffmpeg -i "$input_file" -acodec pcm_s16le -ar 44100 -ac 2 "$temp_file" -y 2>/dev/null
    
    if [ -f "$temp_file" ]; then
        converted_files+=("$temp_file")
        # Get duration and other info
        duration=$(soxi -D "$temp_file")
        file_durations+=("$duration")
        
        # Analyze audio characteristics
        rms=$(sox "$temp_file" -n stat 2>&1 | grep "RMS amplitude" | awk '{print $3}')
        echo "  Duration: ${duration}s, RMS: $rms"
    fi
done

echo
echo "Creating $NUM_SEQUENCES organic sequences with enhanced variety..."

for seq_num in $(seq 1 $NUM_SEQUENCES); do
    echo
    echo "=== Creating sequence $seq_num ==="
    
    # Randomly select number of files (more files = more variety)
    max_files=$MAX_FILES_PER_SEQUENCE
    if [ ${#audio_files[@]} -lt $MAX_FILES_PER_SEQUENCE ]; then
        max_files=${#audio_files[@]}
    fi
    num_files=$((MIN_FILES_PER_SEQUENCE + RANDOM % (max_files - MIN_FILES_PER_SEQUENCE + 1)))
    
    echo "Using $num_files files for this sequence"
    
    # Create array of selected file indices
    selected_indices=()
    while [ ${#selected_indices[@]} -lt $num_files ]; do
        rand_idx=$((RANDOM % ${#converted_files[@]}))
        if [[ ! " ${selected_indices[@]} " =~ " ${rand_idx} " ]]; then
            selected_indices+=($rand_idx)
        fi
    done
    
    # Create multiple layers for the mix
    layer_files=()
    
    # Layer 1: Background ambience (3-4 files mixed at low volume)
    echo "  Creating background layer..."
    bg_files=()
    for i in {0..2}; do
        if [ $i -lt ${#selected_indices[@]} ]; then
            idx=${selected_indices[$i]}
            file="${converted_files[$idx]}"
            duration="${file_durations[$idx]}"
            
            # Random start and loop if needed
            start=$((RANDOM % ${duration%.*}))
            
            bg_file="bg_${seq_num}_${i}.wav"
            # Create looped background with fade (ensure 30+ seconds)
            sox "$file" "$bg_file" trim $start 10 fade t 2 0 2 : newfile : restart
            # Apply effects: reverb, low-pass filter, volume reduction
            sox "$bg_file" "bg_proc_${seq_num}_${i}.wav" reverb 50 lowpass 800 vol 0.2
            bg_files+=("bg_proc_${seq_num}_${i}.wav")
        fi
    done
    
    # Mix background files
    if [ ${#bg_files[@]} -gt 0 ]; then
        sox -m "${bg_files[@]}" "background_${seq_num}.wav" trim 0 30
        layer_files+=("background_${seq_num}.wav")
    fi
    
    # Layer 2: Mid-range elements (3-4 files with various effects)
    echo "  Creating mid-range layer..."
    mid_files=()
    for i in {3..6}; do
        if [ $i -lt ${#selected_indices[@]} ]; then
            idx=${selected_indices[$i]}
            file="${converted_files[$idx]}"
            duration="${file_durations[$idx]}"
            
            # Take random segments
            num_segments=$((2 + RANDOM % 3))
            mid_file="mid_${seq_num}_${i}.wav"
            
            # Create silence
            sox -n -r 44100 -c 2 "$mid_file" trim 0 30
            
            for seg in $(seq 1 $num_segments); do
                start=$((RANDOM % ${duration%.*}))
                seg_duration=$((3 + RANDOM % 8))
                position=$((RANDOM % 25))  # Random position within 30 seconds
                
                # Extract segment with random effect
                effect=$((RANDOM % 4))
                temp_seg="temp_mid_${seq_num}_${i}_${seg}.wav"
                
                case $effect in
                    0) # Pitch shift
                        pitch=$((200 - RANDOM % 400))
                        sox "$file" "$temp_seg" trim $start $seg_duration pitch $pitch fade t 0.5 0 0.5
                        ;;
                    1) # Reverse with echo
                        sox "$file" "$temp_seg" trim $start $seg_duration reverse echo 0.8 0.9 1000 0.3 echo 0.8 0.7 60 0.25 fade t 0.5 0 0.5
                        ;;
                    2) # Flanger
                        sox "$file" "$temp_seg" trim $start $seg_duration flanger fade t 0.5 0 0.5
                        ;;
                    3) # Time stretch
                        tempo=$((80 + RANDOM % 40))
                        sox "$file" "$temp_seg" trim $start $seg_duration tempo -s 0.$tempo fade t 0.5 0 0.5
                        ;;
                esac
                
                # Mix segment at random position
                sox "$mid_file" "$temp_seg" "temp_mixed_${seq_num}_${i}_${seg}.wav" splice -q $position
                mv "temp_mixed_${seq_num}_${i}_${seg}.wav" "$mid_file"
                rm -f "$temp_seg"
            done
            
            # Apply volume adjustment
            sox "$mid_file" "mid_proc_${seq_num}_${i}.wav" vol 0.5
            mid_files+=("mid_proc_${seq_num}_${i}.wav")
        fi
    done
    
    # Mix mid-range files
    if [ ${#mid_files[@]} -gt 0 ]; then
        sox -m "${mid_files[@]}" "midrange_${seq_num}.wav" trim 0 30
        layer_files+=("midrange_${seq_num}.wav")
    fi
    
    # Layer 3: Foreground accents (remaining files)
    echo "  Creating foreground accents..."
    fg_files=()
    for i in {7..9}; do
        if [ $i -lt ${#selected_indices[@]} ]; then
            idx=${selected_indices[$i]}
            file="${converted_files[$idx]}"
            duration="${file_durations[$idx]}"
            
            # Create sparse accents
            fg_file="fg_${seq_num}_${i}.wav"
            sox -n -r 44100 -c 2 "$fg_file" trim 0 30
            
            # Add 2-4 accents
            num_accents=$((2 + RANDOM % 3))
            for acc in $(seq 1 $num_accents); do
                start=$((RANDOM % ${duration%.*}))
                acc_duration=$((1 + RANDOM % 4))
                position=$((RANDOM % 26))  # Keep some space at the end
                
                temp_acc="temp_fg_${seq_num}_${i}_${acc}.wav"
                
                # Apply dynamic processing
                sox "$file" "$temp_acc" trim $start $acc_duration \
                    compand 0.3,1 6:-70,-60,-20 -10 -90 0.2 \
                    fade t 0.2 0 0.2 \
                    bandpass 1000 2000
                
                # Mix at position
                sox "$fg_file" "$temp_acc" "temp_mixed_fg_${seq_num}_${i}_${acc}.wav" splice -q $position
                mv "temp_mixed_fg_${seq_num}_${i}_${acc}.wav" "$fg_file"
                rm -f "$temp_acc"
            done
            
            # Add some presence
            sox "$fg_file" "fg_proc_${seq_num}_${i}.wav" vol 0.7 highpass 200
            fg_files+=("fg_proc_${seq_num}_${i}.wav")
        fi
    done
    
    # Mix foreground files
    if [ ${#fg_files[@]} -gt 0 ]; then
        sox -m "${fg_files[@]}" "foreground_${seq_num}.wav" trim 0 30
        layer_files+=("foreground_${seq_num}.wav")
    fi
    
    # Final mix of all layers
    output_file=$(printf "%s_%02d.wav" "$OUTPUT_PREFIX" "$seq_num")
    echo "  Mixing all layers..."
    
    if [ ${#layer_files[@]} -gt 0 ]; then
        # Mix with dynamic normalization and final mastering
        sox -m "${layer_files[@]}" "$output_file" \
            compand 0.3,1 6:-70,-60,-20 -5 -90 0.2 \
            reverb 20 \
            norm -3 \
            fade t 0.5 0 1 \
            trim 0 30
    fi
    
    # Clean up temporary files
    rm -f bg_*.wav mid_*.wav fg_*.wav background_${seq_num}.wav midrange_${seq_num}.wav foreground_${seq_num}.wav
    
    # Verify final duration
    if [ -f "$output_file" ]; then
        final_duration=$(soxi -D "$output_file")
        echo "  Created: $output_file (${final_duration}s)"
    fi
done

# Final cleanup
echo
echo "Cleaning up temporary files..."
rm -f temp_*.wav

echo
echo "Done! Created $NUM_SEQUENCES organic mixes with enhanced variety:"
ls -la ${OUTPUT_PREFIX}_*.wav