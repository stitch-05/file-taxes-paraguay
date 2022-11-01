#!/bin/bash

WORKING_DIR=$(dirname "$0")

# Load variables
. $WORKING_DIR/../.env
. $WORKING_DIR/../.env.local

TITLE=$1
MESSAGE=$2

if [ -z "$TITLE" ]; then
  echo "No title provided"
  exit 1
fi

if [ -z "$MESSAGE" ]; then
  echo "No message provided"
  exit 1
fi

curl -s \
--form-string "token=$PUSHOVER_TOKEN" \
--form-string "user=$PUSHOVER_USER" \
--form-string "message=$MESSAGE" \
--form-string "title=$TITLE" \
--form-string "device=iPhone12" \
--form-string "html=1" \
https://api.pushover.net/1/messages.json