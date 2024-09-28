import os
import re
import sys
import requests
from meilisearch import Client

# Get the MEILI_MASTER_KEY from the environment variable
MEILI_MASTER_KEY = os.getenv('MEILI_MASTER_KEY')
if not MEILI_MASTER_KEY:
    print("Error: MEILI_MASTER_KEY environment variable is not set.")
    sys.exit(1)

meili_url = f'http://172.30.1.12:7700'

# MeiliSearch setup
meili_client = Client(meili_url, MEILI_MASTER_KEY)
index = meili_client.index('transcriptions')

def is_meilisearch_responsive(url):
    try:
        response = requests.get(url)
        if response.status_code == 200:
            return True
        else:
            print(f"MeiliSearch API responded with status code: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"Error connecting to MeiliSearch API: {e}")
        return False

def read_file(file_path):
    if os.path.exists(file_path):
        try:
            with open(file_path, 'r') as file:
                return file.read()
        except IOError as e:
            print(f"Error reading file {file_path}: {e}")
            return None
    else:
        print(f"File not found: {file_path}")
        return None

def index_data(base_path):
    # Check if MeiliSearch API is responsive
    if not is_meilisearch_responsive(meili_url):
        print("MeiliSearch API is not responsive. Please check the API status and try again.")
        sys.exit(1)

    documents = []

    for root, dirs, files in os.walk(base_path):
        for name in files:
            # Check for summary and transcript files
            if name.endswith("summary.txt") or name.endswith(".txt"):
                folder_name = os.path.basename(root)
                # Remove the _YYYYMMddhhmmss part from the folder_name
                # Assumes the format is always _ followed by 14 digits
                #cleaned_folder_name = re.sub(r'_[\d]{14}$', '', folder_name)

                summary_file = os.path.join(root, "summary.txt")
                transcript_file = os.path.join(root, folder_name + ".txt")
                #transcript_file = os.path.join(root, cleaned_folder_name + ".txt")

                summary = read_file(summary_file)
                transcript = read_file(transcript_file)

                document = {
                    "id": folder_name  # Using folder name as unique identifier
                }

                if summary:
                    document["summary"] = summary
                else:
                    print(f"Warning: No summary found in {folder_name}")

                if transcript:
                    document["transcript"] = transcript
                else:
                    print(f"Warning: No transcript found in {folder_name}")

                documents.append(document)

    if documents:
        try:
            index.add_documents(documents)
            print(f"Successfully indexed {len(documents)} documents.")
        except Exception as e:
            print(f"Error indexing documents: {e}")
    else:
        print("No valid documents found to index.")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        folder_path = sys.argv[1]  # Get the folder path from the command line
        index_data(folder_path)
    else:
        print("Please provide a path to the folder you want to index.")
