#!/bin/bash

# Display initial message
echo "This script will build the required Docker images for Transcription Stream."
echo "It will first build the 'ts-web' image, followed by the 'ts-gpu' image."
echo "Note: Building the 'ts-gpu' image may take some time as it downloads models for offline use."
echo "After building the images, it will create necessary Docker volumes, start the services, and "
echo "downloade the mistral model for the ts-gpt Ollama endpoint."
echo -n "Do you want to continue? (y/n): "

# Read user input
read answer

# Check if the user input is 'y' or 'Y'
if [ "$answer" != "${answer#[Yy]}" ] ;then
    # Initialize an empty string for build arguments
    build_args=""

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
        # Skip comments and empty lines
        if [[ ! $line =~ ^#.*$ ]] && [[ -n $line ]]; then
            build_args="$build_args --build-arg $line"
            
            # Extract DISABLE_OLLAMA if present
            if [[ $line =~ ^DISABLE_OLLAMA= ]]; then
                disable_ollama="${line#*=}" # Extract the value after '='
            fi
        fi
    done < "$env_file"

    # Check if DISABLE_OLLAMA was found and process accordingly
    if [ -n "$disable_ollama" ]; then
        echo "DISABLE_OLLAMA is set to $disable_ollama"
    fi

    # Navigate to the ts-web directory and build the Dockerfile
    echo "Building Docker image for ts-web..."
    cd ts-web
    docker build $build_args -t ts-web:latest .
    cd ..

    # Navigate to the ts-gpu directory and build the Dockerfile
    echo "Building Docker image for ts-gpu..."
    cd ts-gpu
    docker build $build_args -t ts-gpu:latest .
    cd ..

    # Create necessary Docker volumes
    echo "Creating Docker volumes..."
    docker volume create --name=transcribe-ui

    # Start the docker compose services
    echo "Starting services with docker compose..."
    docker compose up --detach

    # Get the model installed on ts-gpt (requires curl)
    # only if ollama is enabled in docker-compose.yaml
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

    echo "All services are up and running."
else
    echo "Installation canceled by the user."
fi
