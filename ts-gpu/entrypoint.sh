#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

# Only create app-specific directories if they don't already exist (because they are mounted)
if [ ! -d "${SCRIPTS_DIR}" ]; then
    echo "[missing] creating ${SCRIPTS_DIR}"
    mkdir -p "${SCRIPTS_DIR}"
fi
if [ ! -d "${APP_DIR}/transcribed" ]; then
    echo "[missing] creating ${APP_DIR}/transcribed"
    mkdir -p "${APP_DIR}/transcribed"
fi
if [ ! -d "${APP_DIR}/incoming/diarize" ]; then
    echo "[missing] creating ${APP_DIR}/incoming/diarize"
    mkdir -p "${APP_DIR}/incoming/diarize"
fi
if [ ! -d "${APP_DIR}/incoming/transcribe" ]; then
    echo "[missing] creating ${APP_DIR}/incoming/transcribe"
    mkdir -p "${APP_DIR}/incoming/transcribe"
fi

# Only create user-specific directories if they don't already exist (because they are mounted)
if [ ! -d "${USER_DIR}/transcribed" ]; then
    echo "[missing] creating ${USER_DIR}/transcribed"
    mkdir -p "${USER_DIR}/transcribed"
fi
if [ ! -d "${USER_DIR}/incoming/diarize" ]; then
    echo "[missing] creating ${USER_DIR}/incoming/diarize"
    mkdir -p "${USER_DIR}/incoming/diarize"
fi
if [ ! -d "${USER_DIR}/incoming/transcribe" ]; then
    echo "[missing] creating ${USER_DIR}/incoming/transcribe"
    mkdir -p "${USER_DIR}/incoming/transcribe"
fi

# Copy the test file if it doesn't exist
if [ ! -f "${USER_DIR}/test.wav" ]; then
    echo "[missing] copying ${USER_DIR}/test.wav"
    cp "/test.wav" "${USER_DIR}/"
fi

# Copy test file and set permissions
if [ "$(stat -c %U:%G "${USER_DIR}")" != "${PROJECT_ID}:${PROJECT_ID}" ]; then
    chown -R "${PROJECT_ID}:${PROJECT_ID}" "${USER_DIR}"
fi

# Run diarization and transcription on test.wav if it exists (remove if not necessary for every start)
if [ -f "${USER_DIR}/test.wav" ]; then
    if ! python3 diarize.py -a "${USER_DIR}/test.wav" \
        && ! whisperx --model "${TRANSCRIPTION_MODEL}" --language en "${USER_DIR}/test.wav" --compute_type int8; then
        echo "Error: Diarization or transcription failed."
        exit 1
    fi
else
    echo "Error: ${USER_DIR}/test.wav not found."
    exit 1
fi

# Check if ts-control.sh exists and run it
if [ -f "${SCRIPTS_DIR}/ts-control.sh" ]; then
    exec bash "${SCRIPTS_DIR}/ts-control.sh"
else
    echo "Error: ${SCRIPTS_DIR}/ts-control.sh not found."
    exit 1
fi
