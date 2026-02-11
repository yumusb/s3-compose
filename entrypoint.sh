#!/bin/bash

# Check if CRON_SCHEDULE is set
if [ -z "$CRON_SCHEDULE" ]; then
  echo "Error: CRON_SCHEDULE environment variable is not set."
  exit 1
fi

# Add the cron job
echo "$CRON_SCHEDULE /backup.sh >> /var/log/cron.log 2>&1" > /etc/crontabs/root

# Create the log file
touch /var/log/cron.log

# Run the backup immediately on start if specified
if [ "$RUN_ON_START" == "true" ]; then
  echo "Running initial backup..."
  /backup.sh
fi

echo "Starting cron with schedule: $CRON_SCHEDULE"

# Start crond in foreground
crond -f -L /var/log/cron.log
