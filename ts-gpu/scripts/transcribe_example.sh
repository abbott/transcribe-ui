#!/bin/bash
# transcription stream transcription and diarization example script - 12/2023
## 1/2024: Summaries migrated to ts-control.sh, summaries created asynchronously.

# Check if required environment variables are set
if [ -z "$DIARIZATION_MODEL" ] || [ -z "$TRANSCRIPTION_MODEL" ] || [ -z "$PROJECT_ID" ]; then
  echo "Error: Required environment variables (DIARIZATION_MODEL, TRANSCRIPTION_MODEL, PROJECT_ID) not set."
  exit 1
fi

app_dir="/${PROJECT_ID}"
upload_dir="${app_dir}/incoming"
transcribed_dir="${app_dir}/transcribed"

# Define the root directory and subdirectories
sub_dirs=("diarize" "transcribe")

# Define supported audio file extensions
audio_extensions=("wav" "mp3" "flac" "ogg")

# Loop over each subdirectory
for sub_dir in "${sub_dirs[@]}"; do
    incoming_dir="$upload_dir/$sub_dir"

    # Loop over each audio file extension
    for ext in "${audio_extensions[@]}"; do
        # Loop over the files in the incoming directory with the current extension
        for audio_file in "$incoming_dir"/*."$ext"; do
            # If this file does not exist, skip to the next iteration
            if [ ! -f "$audio_file" ]; then
                continue
            fi

            # Get the base name of the file (without the extension)
            base_name=$(basename "$audio_file" ."$ext")

            # Get the current date/time
            date_time=$(date '+%Y%m%d%H%M%S')
            
            # Rename file by adding timestamp
            new_filename="$base_name"_"$date_time.$ext"
            new_filepath="$incoming_dir/$new_filename"
            mv "$audio_file" "$new_filepath"

            # Create a new subdirectory in the transcribed directory
            new_dir="$transcribed_dir/$base_name"_"$date_time"
            mkdir -p "$new_dir"

            # Process diarization or transcription based on the subdirectory
            if [ "$sub_dir" == "diarize" ]; then
                echo "--- diarizing $new_filepath..." >> /proc/1/fd/1
                diarize_start_time=$(date +%s)
                python3 diarize_parallel.py --batch-size 16 --whisper-model $DIARIZATION_MODEL --language en -a "$new_filepath"
                diarize_end_time=$(date +%s)
                run_time=$((diarize_end_time - diarize_start_time))
            elif [ "$sub_dir" == "transcribe" ]; then
                echo "--- transcribing $new_filepath..." >> /proc/1/fd/1
                whisper_start_time=$(date +%s)
                whisperx --batch_size 12 --model $TRANSCRIPTION_MODEL --language en --output_dir "$new_dir" "$new_filepath" > "$new_dir/$new_filename.txt"
                whisper_end_time=$(date +%s)
                run_time=$((whisper_end_time - whisper_start_time))
            fi

            # Move all files with the same base_name to the new subdirectory
            mv "$incoming_dir/$new_filename"* "$new_dir/"

            # Change the owner of the files to the user transcribe-ui
            if ! chown -R ${PROJECT_ID}:${PROJECT_ID} "$new_dir"; then
              echo "Error: Failed to change ownership for $new_dir" >> /proc/1/fd/1
            fi

            # Log messages to console
            echo "--- done processing $new_filepath - output placed in $new_dir" >> /proc/1/fd/1
            if [ -f "$new_dir/$new_filename.txt" ]; then
                echo "transcription: $(cat "$new_dir/$new_filename.txt") " >> /proc/1/fd/1;
                echo "Runtime for processing $new_filepath = $run_time" >> /proc/1/fd/1;
                echo "------------------------------------";
            fi
        done
    done
done
