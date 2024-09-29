#!/bin/bash

# Load environment variables from the .env file
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Error: .env file does not exist."
    exit 1
fi

# Display initial message
echo "This script will build the required Docker images for Transcription Stream."
echo "It will first build the 'ts-web' image, followed by the 'ts-gpu' image."
echo "Note: Building the 'ts-gpu' image may take some time as it downloads models for offline use."
echo "After building the images, it will create necessary Docker volumes, start the services, and "
echo "download the mistral model for the ts-gpt Ollama endpoint."
echo -n "Do you want to continue? [y/N]: "

# Read user input
read answer

# Check if the user input is 'y' or 'Y'
if [ "$answer" != "${answer#[Yy]}" ]; then
    # Initialize an empty string for build arguments
    build_args=""

    # Properly format environment variables as build args
    while IFS='=' read -r key value; do
        if [[ -n "$key" && "$key" != "#"* ]]; then
            build_args="$build_args --build-arg $key=\"$value\""
        fi
    done < ".env"

    # Build the Docker images
    echo "Building Docker image for ts-gpu..."
    cd ts-gpu
    docker build $build_args -t ts-gpu:latest .
    #docker build --no-cache $build_args -t ts-gpu:latest .
    cd ..

    echo "Building Docker image for ts-web..."
    cd ts-web
    docker build $build_args -t ts-web:latest . 
    #docker build --no-cache $build_args -t ts-web:latest .
    cd ..

    # Start the docker compose services
    echo "Starting services with docker compose..."
    if docker compose up --detach; then
        echo "Services started successfully."
    else
        echo "Error: Failed to start Docker Compose services."
        exit 1
    fi

    # Ensure the container is running
    container_id=$(docker ps -qf "name=ts-gpu")
    if [ -z "$container_id" ]; then
        echo "Error: ts-gpu container is not running."
        exit 1
    fi

    # Check if the /home/transcribe-ui directory exists inside the container
    echo "Checking if $USER_DIR exists in the container..."
    if ! docker exec "$container_id" [ -d "$USER_DIR" ]; then
        echo "Error: $USER_DIR does not exist inside the container. Creating it now..."
        docker exec "$container_id" mkdir -p "$USER_DIR"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to create $USER_DIR inside the container."
            exit 1
        fi
    fi

    # Check if the test.wav file exists on the host
    if [ ! -f "ts-gpu/test.wav" ]; then
        echo "Error: test.wav not found in the host directory (ts-gpu)."
        exit 1
    fi

    # Copy the test.wav file into the container
    echo "Copying test.wav to $USER_DIR in the container..."
    docker cp ts-gpu/test.wav "$container_id:$USER_DIR/"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to copy test.wav into the container."
        exit 1
    fi

    # Verify the file was successfully copied into the container
    echo "Verifying the test.wav file in the container..."
    if ! docker exec "$container_id" [ -f "$USER_DIR/test.wav" ]; then
        echo "Error: test.wav is missing in the container."
        exit 1
    fi
    echo "test.wav successfully copied to $USER_DIR in the container."


    echo "Containers are up and running. Ensuring files are present in the container."

    # Check if the required files exist inside the container's scripts directory
    echo "Verifying the scripts in the container..."
    if ! docker exec "$container_id" [ -f "$SCRIPTS_DIR/ts-control.sh" ]; then
        echo "Error: ts-control.sh is missing in the container."
        exit 1
    fi

    echo "Files copied and verified successfully."

    # Download the model on ts-gpt (requires curl)
    if [ "$REMOTE_OLLAMA" != "true" ]; then
        echo "Downloading Mistral model"
        curl -X POST "http://$OLLAMA_HOST:$OLLAMA_PORT/api/pull" -d '{"name": "'$OLLAMA_MODEL'"}'
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
