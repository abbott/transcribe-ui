#!/bin/bash

# Load environment variables from the .env file
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Error: .env file does not exist."
    exit 1
fi

# Display initial message
echo "This script will start pull the needed docker images and start Transcription Stream."
echo "Please note the main image, ts-gpu, is nearly 26GB and may take a hot second to download."
echo "-- it also checks for latest mistral model then connects you to the logs"
echo -n "Do you want to continue? [y/N]: "

# Read user input
read answer

# Check if the user input is 'y' or 'Y'
if [ "$answer" != "${answer#[Yy]}" ] ;then

    # Start the docker compose services
    echo "Starting services with docker compose..."
    docker compose -f docker-compose-nobuild.yml up --detach

    # Download the model on ts-gpt (requires curl)
    # only if Ollama is enabled in docker-compose.yaml
    if [ "$DISABLE_OLLAMA" != "true" ]; then
        echo "Downloading Mistral model"
        curl -X POST http://$OLLAMA_HOST:11434/api/pull -d '{"name": "'$OLLAMA_MODEL'"}'
    else
        echo "DISABLE_OLLAMA is true, skipping Mistral download."
    fi

    # Re-attach to compose logs
    echo "Re-attaching to console logs"
    docker compose logs -f
else
    echo "Installation canceled by the user."
fi
