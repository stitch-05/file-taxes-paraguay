#!/bin/bash

WORKING_DIR=$(dirname "$0")

# Load variables
[ -f $WORKING_DIR/.env ] && . $WORKING_DIR/.env
[ -f $WORKING_DIR/.env.local ] && . $WORKING_DIR/.env.local

. $WORKING_DIR/functions

# Handle arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --username=*|-u=*)
      USERNAME="${1#*=}"
      shift
      ;;
    --username|-u)
      USERNAME="$2"
      shift 2
      ;;
    --password=*|-p=*)
      PASSWORD="${1#*=}"
      shift
      ;;
    --password|-p)
      PASSWORD="$2"
      shift 2
      ;;
    --notification-service=*|-ns=*)
      NOTIFICATION_SERVICE="${1#*=}"
      shift
      ;;
    --notification-service|-ns)
      NOTIFICATION_SERVICE="$2"
      shift 2
      ;;
    --pushover-token=*|-pt=*)
      PUSHOVER_TOKEN="${1#*=}"
      shift
      ;;
    --pushover-token|-pt)
      PUSHOVER_TOKEN="$2"
      shift 2
      ;;
    --pushover-user=*|-pu=*)
      PUSHOVER_USER="${1#*=}"
      shift
      ;;
    --pushover-user|-pu)
      PUSHOVER_USER="$2"
      shift 2
      ;;
    --signal-user=*|-su=*)
      SIGNAL_USER="${1#*=}"
      shift
      ;;
    --signal-user|-su)
      SIGNAL_USER="$2"
      shift 2
      ;;
    --signal-recipient=*|-sr=*)
      SIGNAL_RECIPIENT="${1#*=}"
      shift
      ;;
    --signal-recipient|-sr)
      SIGNAL_RECIPIENT="$2"
      shift 2
      ;;
    --message-prefix=*|-mp=*)
      MESSAGE_PREFIX="${1#*=}"
      shift
      ;;
    --message-prefix|-mp)
      MESSAGE_PREFIX="$2"
      shift 2
      ;;
    --wget-output=*|-wo=*)
      WGET_OUTPUT="${1#*=}"
      shift
      ;;
    --wget-output|-wo)
      WGET_OUTPUT="$2"
      shift 2
      ;;
    --wget-flags=*|-wf=*)
      WGET_FLAGS="${1#*=}"
      shift
      ;;
    --wget-flags|-wf)
      WGET_FLAGS="$2"
      shift 2
      ;;
    --help|-h)
      SHOW_HELP=1
      shift
      ;;
    *)
      echo "Unknown argument $1"
      shift
      exit 1
      ;;
  esac
done

SCRIPT_NAME=$(basename "$0")
if [ "$SHOW_HELP" = "1" ]; then
  echo "Automatically file taxes in Paraguay."
  echo -e "Usage: ./$SCRIPT_NAME [OPTIONS]\n"
  echo -e "You can combine these arguments with .env and .env.local variables.\n"
  echo -e "Startup:" 
  echo "  -h --help                                 print this help information"
  echo "  -u --username=\"USERNAME\"                  marangatu login username"
  echo "  -p --username=\"PASSWORD\"                  marangatu login password"
  echo -e "\nNotification:"
  echo "  -ns --notification-service=\"SERVICE\"      Choose notification service: pushover or signal (default: none)"
  echo "  -pt --pushover-token=\"TOKEN\"              Your application's API token. Create it at https://pushover.net"
  echo "  -pu --pushover-user=\"USER\"                Your user/group key. Viewable in the Pushover's dashboard."
  echo "  -su --signal-user=\"USER\"                  Phone number of the sender. Needs signal-cli."
  echo "  -sr --signal-recipient=\"RECIPIENT\"        Phone number of the recipient. Needs signal-cli."
  echo -e "  -mp --message-prefix=\"PREFIX\"             Prefix for notification message. Supports emojis. (default: \"🇵🇾 taxes\")"
  echo -e "\nWget:"
  echo "  -wo --wget-output=\"OUTPUT\"                wget output for debugging (default: -qO-)"
  echo -e "  -wf --wget-flags=\"FLAGS\"                  wget flags in case you run into SSL certificate issues
                                        (default: --cipher=DEFAULT:!DH --no-check-certificate)"

  exit 1
fi

if [[ ! "$USERNAME" || ! "$PASSWORD"  ]]; then
  echo -e "Please set login credentials in .env, .env.local, or as script arguments.\nSee ./$SCRIPT_NAME --help"
  exit 1
fi

# Make sure to install wget
if ! is_required wget; then
  install_instructions wget
fi

# Make sure to install jq
if ! is_required jq; then
  install_instructions jq
fi

# Make sure to install xmllint
if ! is_required xmllint; then
  install_instructions xmllint libxml2-utils libxml2
fi

COOKIES_FILE=$WORKING_DIR/cookies.txt

URL_HOST="https://marangatu.set.gov.py"
URL_BASE="$URL_HOST/eset"

METHOD_AUTH="authenticate"
METHOD_PROFILE="perfil/publico"
METHOD_PENDING="perfil/vencimientos"
METHOD_MENU="perfil/menu"
METHOD_CHECK_PROFILE="perfil/informacionControlesPerfil"

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

# Check profile info
echo "Checking profile info changes..."

random_sleep
CHECK_PROFILE=$(wget $WGET_FLAGS $WGET_OUTPUT --load-cookies $COOKIES_FILE --user-agent="$UA" "$URL_BASE/$METHOD_CHECK_PROFILE?t3=$TOKEN")

MUST_UPDATE=$(echo "${CHECK_PROFILE}" | jq --raw-output '.debeActualizar' 2>/dev/null)

if [[ "$MUST_UPDATE" == "true" ]]; then
  for row in $(echo "${CHECK_PROFILE}" | jq -r '.vinculos[] | @base64'); do
    _jq() {
      echo ${row} | base64 --decode | jq -r ${1}
    }

    NAME=$(_jq '.texto')
    NAME_SAFE=$(echo "$NAME" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')
    LINK=$(_jq '.url')

    echo "================"
    echo "Profile data $NAME must be updated"

    if [ -f $WORKING_DIR/forms/$NAME_SAFE ]; then
      . $WORKING_DIR/forms/$NAME_SAFE $LINK
    else
      ERROR="Profile data $NAME requested but not yet implemented. Please update it manually."

      send_message "Error" "$ERROR"
    fi
  done
else
  echo "No pending profile actions"
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
      ERROR="Tax form no. $TAX requested but not yet implemented. Please file it manually."

      send_message "Error" "$ERROR"
    fi
  done
else
  echo "No pending actions"
fi

exit 0