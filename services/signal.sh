#!/bin/bash

WORKING_DIR=$(dirname "$0")

# Load variables
[ -f $WORKING_DIR/../.env ] && . $WORKING_DIR/../.env
[ -f $WORKING_DIR/../.env.local ] && . $WORKING_DIR/../.env.local

MESSAGE=$1

if [ -z "$MESSAGE" ]; then
  echo "No message provided"
  exit 1
fi

signal-cli -a "${SIGNAL_USER}" send -m "$MESSAGE" "${SIGNAL_RECIPIENT}"

exit 0