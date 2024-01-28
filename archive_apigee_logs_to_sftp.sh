#!/bin/bash

# Log File
LOG_FILE="/var/log/sftp_upload.log"

# Function for logging
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="{ \"timestamp\": \"$timestamp\", \"state\": \"$1\", \"message\": \"$2\" }"
    echo "$log_entry" >> "$LOG_FILE"
}

# SFTP Server Details
SFTP_USER="your_sftp_username"
SFTP_PORT="22"
SFTP_DEST_DIR="prod-$(hostname)-$(date +%Y-%m-%d)"

# Determine SFTP_HOST based on hostname
if [[ "$(hostname)" == k* ]]; then
    SFTP_HOST="10.104.252.208"
elif [[ "$(hostname)" == g* ]]; then
    SFTP_HOST="10.114.252.208"
else
    log "Unsupported hostname prefix. Exiting." "error"
    exit 1
fi

# Source Path
SOURCE_PATH="/opt/apigee/var/log/*/logs/*.log.gz"

# Temporary Local Directory
TMP_DIR="/tmp/sftp_upload"

# Ensure the temporary directory exists
mkdir -p "$TMP_DIR"

# Use find to get a list of files and copy them to the temporary local directory
find "$SOURCE_PATH" -maxdepth 1 -type f -exec cp {} "$TMP_DIR" \;

# Check if there are files to upload
if [ "$(ls -A "$TMP_DIR")" ]; then
    log "Starting SFTP upload." "info"

    # Iterate through files in the temporary local directory
    for FILE_PATH in "$TMP_DIR"/*.log.gz; do
        # Extract file name from path
        FILE_NAME=$(basename "$FILE_PATH")

        # SFTP Upload
        sftp -P "$SFTP_PORT" "$SFTP_USER@$SFTP_HOST:$SFTP_DEST_DIR" <<< $"put $FILE_PATH"

        # Check the exit status of the sftp command
        if [ $? -eq 0 ]; then
            log "Uploaded $FILE_NAME successfully." "success"
            # Optionally, you can delete the file after successful upload
            # Uncomment the following line if you want to delete the file
            # rm "$FILE_PATH"
        else
            log "Error uploading $FILE_NAME. Exiting." "error"
            exit 1
        fi
    done

    # Remove temporary local directory
    rm -rf "$TMP_DIR"

    log "SFTP Upload Complete." "success"

else
    log "No files to upload. Exiting." "info"
    exit 1
fi
