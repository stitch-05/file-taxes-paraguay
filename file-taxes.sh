#!/bin/bash

WORKING_DIR=$(dirname "$0")

# Load variables
[ -f $WORKING_DIR/.env ] && . $WORKING_DIR/.env
[ -f $WORKING_DIR/.env.local ] && . $WORKING_DIR/.env.local

. $WORKING_DIR/functions

if [[ ! "$USERNAME" || ! "$PASSWORD"  ]]; then
  echo "Please set login credentials in .env or .env.local"
  exit 1
fi

# Make sure to install jq
command -v jq >/dev/null 2>&1 || { 
  echo >&2 "'jq' is required but not installed. Aborting."; 
  
  OS="$(uname -s)"

  case "${OS}" in
    Linux*)
      echo "To install on a Debian based distro, run:"
      echo "sudo apt update && sudo apt install jq"
      echo ""
      echo "To install on a RedHat based distro, run:"
      echo "sudo dnf install jq"
    ;;
    Darwin*)
      echo "To install on MacOS, run:"
      echo "brew install jq"
    ;;
    *)          
      echo "Install jq manually using your system's package manager or source code."
  esac

  exit 1; 
}

# Make sure to install xmllint
command -v xmllint >/dev/null 2>&1 || { 
  echo >&2 "'xmllint' is required but not installed. Aborting."; 
  
  OS="$(uname -s)"

  case "${OS}" in
    Linux*)
      echo "To install on a Debian based distro, run:"
      echo "sudo apt update && sudo apt install libxml2-utils"
      echo ""
      echo "To install on a RedHat based distro, run:"
      echo "sudo dnf install libxml2"
    ;;
    *)          
      echo "Install xmllint manually using your system's package manager or source code."
  esac

  exit 1; 
}

COOKIES_FILE=$WORKING_DIR/cookies.txt

URL_HOST="https://marangatu.set.gov.py"
URL_BASE="$URL_HOST/eset"

METHOD_AUTH="authenticate"
METHOD_PROFILE="perfil/publico"
METHOD_PENDING="perfil/vencimientos"
METHOD_MENU="perfil/menu"

# Load random user agent
UA_FILE=$WORKING_DIR/user-agents.txt
RAND=$(od -d -N2 -An /dev/urandom)
LINES=$(cat $UA_FILE | wc -l)
LINE=$(( RAND % LINES + 1 ))
UA=$(head -$LINE $UA_FILE | tail -1)

echo "Checking session..."

HOME=$(wget $WGET_FLAGS $WGET_OUTPUT --load-cookies $COOKIES_FILE $URL_BASE)

if echo $HOME | grep -q "/eset/logout"; then
  echo "Logged in"
else
  echo "Logging in..."

  random_sleep
  LOGIN=$(wget $WGET_FLAGS $WGET_OUTPUT --save-cookies $COOKIES_FILE --keep-session-cookies --post-data "usuario=$USERNAME&clave=$PASSWORD" --auth-no-challenge --user-agent="$UA" $URL_BASE/$METHOD_AUTH)

  if echo $LOGIN | grep -q "Usuario o Contraseña incorrectos"; then
    send_message "Error" "Incorrect login credentials"
    exit 1
  elif echo $LOGIN | grep -q "Código de Seguridad no es correcto"; then
    send_message "Error" "Login on the website and fill out a captcha first https://marangatu.set.gov.py/eset/login?login_error=2&usuario=$USERNAME"
    exit 1
  else
    echo "Logged in"
  fi
fi

TOKEN=$(encrypt {})
TOKEN=$(urlencode $TOKEN)

random_sleep
PROFILE=$(wget $WGET_FLAGS $WGET_OUTPUT --load-cookies $COOKIES_FILE --user-agent="$UA" "$URL_BASE/$METHOD_PROFILE?t3=$TOKEN")

CEDULA=$(echo $PROFILE | jq --raw-output '.rucActivo' 2>/dev/null)
DV=$(echo $PROFILE | jq --raw-output '.dvActivo' 2>/dev/null)
NAME=$(echo $PROFILE | jq --raw-output '.nombre' 2>/dev/null)

if [[ ! "$NAME" = "" ]]; then
  echo "Welcome $(echo $NAME | awk '{print $2}')!"
else
  send_message "Error" "Could not get user data"
  exit 1
fi

# See if there's any pending forms
echo "Checking pending forms..."

random_sleep
PENDING=$(wget $WGET_FLAGS $WGET_OUTPUT --load-cookies $COOKIES_FILE --user-agent="$UA" "$URL_BASE/$METHOD_PENDING?t3=$TOKEN")

PENDING_ACTIONS=$(echo "${PENDING}" | jq -r '.[] | @base64')

if [[ ! "$PENDING_ACTIONS" = "" ]]; then
  # Get the current list of menu items
  echo "Fetching menu items..."

  random_sleep
  MENU=$(wget $WGET_FLAGS $WGET_OUTPUT --load-cookies $COOKIES_FILE --user-agent="$UA" "$URL_BASE/$METHOD_MENU?t3=$TOKEN")

  # Fill out a pending form
  for row in $(echo "${PENDING}" | jq -r '.[] | @base64'); do
    _jq() {
      echo ${row} | base64 --decode | jq -r ${1}
    }

    TAX=$(_jq '.impuesto')
    REQUESTED_PERIOD=$(_jq '.periodo')
    CURRENT_PERIOD=$(period)

    echo "================"
    echo "Tax form no. $TAX needs to be filed"
    if [ -f $WORKING_DIR/forms/$TAX ]; then
      if [[ "$REQUESTED_PERIOD" = "$CURRENT_PERIOD" ]]; then
        [ -f $WORKING_DIR/forms/$TAX ] && . $WORKING_DIR/forms/$TAX $REQUESTED_PERIOD
      else
        echo "Please wait for the next fiscal period (e.g. next month) to begin."
      fi
    else
      ERROR="Tax form no. $TAX requested but not implemented yet"

      send_message "Error" "$ERROR"
    fi
  done
else
  echo "No pending actions"
fi

exit 0