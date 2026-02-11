#!/bin/bash

# Check if required environment variables are set
if [ -z "$S3_BUCKET" ]; then
  echo "Error: S3_BUCKET environment variable is not set."
  exit 1
fi

if [ -z "$AWS_ACCESS_KEY_ID" ]; then
  echo "Error: AWS_ACCESS_KEY_ID environment variable is not set."
  exit 1
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
  echo "Error: AWS_SECRET_ACCESS_KEY environment variable is not set."
  exit 1
fi

# Set defaults
S3_REGION=${S3_REGION:-us-east-1}
DATA_PATH=${DATA_PATH:-/data}
PROJECT_NAME=${PROJECT_NAME:-$(hostname)}
RETENTION_DAYS=${RETENTION_DAYS:-30}
S3_ENDPOINT=${S3_ENDPOINT:-""}
# Comma separated list of patterns to exclude, e.g. "*.log,*.tmp"
EXCLUDE_PATTERNS=${EXCLUDE_PATTERNS:-""}

# Configure AWS CLI (s5cmd uses same env vars, but might need endpoint flag)
export AWS_DEFAULT_REGION=$S3_REGION

# Construct s5cmd flags
S5_FLAGS=""
if [ -n "$S3_ENDPOINT" ]; then
  S5_FLAGS="$S5_FLAGS --endpoint-url $S3_ENDPOINT"
fi

# Construct tar exclude flags
TAR_FLAGS=""
if [ -n "$EXCLUDE_PATTERNS" ]; then
  IFS=',' read -ra ADDR <<< "$EXCLUDE_PATTERNS"
  for i in "${ADDR[@]}"; do
    PATTERN=$(echo "$i" | xargs)
    TAR_FLAGS="$TAR_FLAGS --exclude='$PATTERN'"
  done
fi

# Determine Date and Archive Name
DATE=$(date +%Y-%m-%d)
ARCHIVE_NAME="backup-${DATE}.tar.gz"
TEMP_ARCHIVE="/tmp/${ARCHIVE_NAME}"
S3_TARGET="s3://$S3_BUCKET/$PROJECT_NAME/$DATE/$ARCHIVE_NAME"

echo "Creating archive $TEMP_ARCHIVE from $DATA_PATH at $(date)"
# Create compressed archive
# We use eval to handle the quoted exclude patterns in TAR_FLAGS correctly if they contain spaces
eval "tar -czf $TEMP_ARCHIVE $TAR_FLAGS -C $DATA_PATH ."

EXIT_CODE=$?

if [ $EXIT_CODE -eq 1 ]; then
    echo "Warning: File changed as we read it (tar exit code 1), proceeding..."
elif [ $EXIT_CODE -ne 0 ]; then
    echo "Error creating archive (exit code $EXIT_CODE)"
    exit $EXIT_CODE
fi

echo "Uploading archive to $S3_TARGET..."
# Upload to S3 using s5cmd
s5cmd $S5_FLAGS cp $TEMP_ARCHIVE $S3_TARGET

if [ $? -eq 0 ]; then
  echo "Backup completed successfully at $(date)"
  rm $TEMP_ARCHIVE
  
  # Cleanup old backups
  echo "Starting cleanup of backups older than $RETENTION_DAYS days..."
  
  # Calculate cutoff in seconds
  if [[ "$OSTYPE" == "darwin"* ]]; then
      # macOS date
      CUTOFF_DATE_SEC=$(date -v-${RETENTION_DAYS}d +%s 2>/dev/null)
  else
      # GNU date
      CUTOFF_DATE_SEC=$(date -d "$RETENTION_DAYS days ago" +%s 2>/dev/null)
  fi

  # List objects (prefixes) in the project folder
  # s5cmd ls s3://bucket/project/ returns objects
  # Since our structure is s3://bucket/project/YYYY-MM-DD/file.tar.gz
  # We look for folders (common prefixes)
  
  # Unfortunately s5cmd output parsing is different.
  # Let's list directories. s5cmd ls s3://bucket/path/
  
  s5cmd $S5_FLAGS ls "s3://$S3_BUCKET/$PROJECT_NAME/*" | while read -r line; do
      # Output format: "2024/02/09 08:00:00  DIR  2024-02-09/" OR "2024/02/09 08:00:00     1234  file.txt"
      # We look for "DIR" and the folder name
      
      # Extract parts
      IS_DIR=$(echo "$line" | awk '{print $3}')
      NAME=$(echo "$line" | awk '{print $4}' | sed 's/\///') # Extract last column, remove trailing slash
      
      if [ "$IS_DIR" == "DIR" ]; then
          # Check if it matches YYYY-MM-DD format
          if [[ "$NAME" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
              # Convert to seconds
              if [[ "$OSTYPE" == "darwin"* ]]; then
                  DIR_DATE_SEC=$(date -j -f "%Y-%m-%d" "$NAME" +%s 2>/dev/null)
              else
                  DIR_DATE_SEC=$(date -d "$NAME" +%s 2>/dev/null)
              fi
              
              if [ -n "$DIR_DATE_SEC" ] && [ -n "$CUTOFF_DATE_SEC" ]; then
                  if [ $DIR_DATE_SEC -lt $CUTOFF_DATE_SEC ]; then
                      echo "Deleting old backup: $NAME"
                      s5cmd $S5_FLAGS rm "s3://$S3_BUCKET/$PROJECT_NAME/$NAME/*"
                      s5cmd $S5_FLAGS rm "s3://$S3_BUCKET/$PROJECT_NAME/$NAME/" # Remove the dir itself if needed (S3 "dirs" are virtual, but good practice)
                  else
                      echo "Keeping backup: $NAME"
                  fi
              fi
          fi
      fi
  done
  
else
  echo "Backup failed at $(date)"
  exit 1
fi
