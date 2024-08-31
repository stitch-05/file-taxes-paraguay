#!/bin/sh

WORKING_DIR=$(dirname "$0")
 
# Load variables
[ -f $WORKING_DIR/../.env ] && . $WORKING_DIR/../.env
[ -f $WORKING_DIR/../.env.local ] && . $WORKING_DIR/../.env.local
 
MESSAGE=$1

if [ -z "$MESSAGE" ]; then
  echo "No message provided"
  exit 1
fi
 
NL="
"

curl --silent -X POST --retry 5 --retry-delay 0 --retry-max-time 60 --data-urlencode "parse_mode=html" --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" --data-urlencode "text=${MESSAGE}" "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage?disable_web_page_preview=true" | grep -q '"ok":true'

