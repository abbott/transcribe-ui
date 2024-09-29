import os
import subprocess
import pwd
import grp


# Use the PROJECT_ID environment variable from the .env file
PROJECT_ID = os.getenv('PROJECT_ID', 'transcribe-ui')  

APP_DIR = os.getenv('APP_DIR', f'/{PROJECT_ID}') 
SCRIPTS_DIR = os.getenv('SCRIPTS_DIR', f'{APP_DIR}/scripts') 

TRANSCRIBED_DIR = f'{APP_DIR}/transcribed'

OLLAMA_HOST = os.getenv('OLLAMA_HOST', '172.30.1.3') 
OLLAMA_PORT = os.getenv('OLLAMA_PORT', '11434') 

DISABLE_OLLAMA = os.getenv('DISABLE_OLLAMA', 'false').lower() == 'true'  # Check if Ollama is disabled


def scan_and_summarize(base_directory):
    # Get the user and group ID for the PROJECT_ID
    uid = pwd.getpwnam(PROJECT_ID).pw_uid
    gid = grp.getgrnam(PROJECT_ID).gr_gid

    if DISABLE_OLLAMA:
        print("Ollama is disabled, skipping summary generation.")
        return

    # Iterate through all items in the base directory
    for item in os.listdir(base_directory):
        path = os.path.join(base_directory, item)

        # Check if the item is a directory
        if os.path.isdir(path):
            # Check for the presence of any .txt and .srt files in the subdirectory
            txt_files = [file for file in os.listdir(path) if file.endswith('.txt')]
            srt_exists = any(file.endswith('.srt') for file in os.listdir(path))

            # If .txt and .srt files exist, check for summary.txt
            if txt_files and srt_exists:
                summary_file = os.path.join(path, 'summary.txt')

                # Check if summary.txt does not exist in the subdirectory
                if not os.path.isfile(summary_file):
                    for txt_file in txt_files:
                        # Print message indicating creation of summary.txt for each .txt file
                        print(f"Creating summary.txt for {txt_file} in {path}")

                        # Call the external script with the directory path and the URL
                        command = f'python3 {SCRIPTS_DIR}/ts-summarize.py {path} http://{OLLAMA_HOST}:{OLLAMA_PORT}'
                        subprocess.run(command, shell=True)

                        # Change the ownership of the new summary.txt file
                        if os.path.isfile(summary_file):
                            os.chown(summary_file, uid, gid)
                        else:
                            print(f"Warning: summary.txt was not created for {txt_file} in {path}")

# Example usage
scan_and_summarize(TRANSCRIBED_DIR)
