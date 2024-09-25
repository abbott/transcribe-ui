#!/bin/bash

# Display initial message
echo "This script will start pull the needed docker images and start Transcription Stream."
echo "Please note the main image, ts-gpu, is nearly 26GB and may take a hot second to download."
echo "-- it also checks for latest mistral model then connects you to the logs"
echo -n "Do you want to continue? (y/n): "

# Read user input
read answer

# Check if the user input is 'y' or 'Y'
if [ "$answer" != "${answer#[Yy]}" ] ;then

    # Adjust the path to the .env file
    env_file=".env"

    # Check if the .env file exists
    if [ ! -f "$env_file" ]; then
        echo "Error: .env file does not exist at $env_file"
        exit 1
    fi

    # Init disable_ollama
    disable_ollama=""

    # Read each line from .env, ignoring comments and empty lines
    while IFS= read -r line; do
        if [[ $line =~ ^DISABLE_OLLAMA= ]]; then
            disable_ollama="${line#*=}" # Extract the value after '='
            break
        fi
    done < "$env_file"

    # Check if DISABLE_OLLAMA was found and process accordingly
    if [ -n "$disable_ollama" ]; then
        echo "DISABLE_OLLAMA is set to $disable_ollama"
    fi

    # Create necessary Docker volume
    echo "Creating Docker volume..."
    docker volume create --name=transcribe-ui

    # Start the docker compose services
    echo "Starting services with docker compose..."
    docker compose -f docker-compose-nobuild.yml up --detach

    # Get the model installed on ts-gpt (requires curl)
    # Check if DISABLE_OLLAMA is set to "true"
    if [ "$disable_ollama" != "true" ]; then
        echo "Downloading transcribe-ui Mistral model"
        curl -X POST http://172.30.1.3:11434/api/pull -d '{"name": "transcribe-ui/transcribe-ui"}'
    else
        echo "DISABLE_OLLAMA is true, skipping Mistral download."
    fi

    # Re-attach to compose logs
    echo "Re-attaching to console logs"
    docker compose logs -f
else
    echo "Installation canceled by the user."
fi
