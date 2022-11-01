#!/bin/bash

WORKING_DIR=$(dirname "$0")

# Load variables
. $WORKING_DIR/.env
. $WORKING_DIR/.env.local

if [[ ! "$USERNAME" || ! "$PASSWORD"  ]]; then
  echo "Please set login credentials in .env or .env.local"
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
      echo "sudo dnf install libxml2-utils"
    ;;
    *)          
      echo "Install xmllint manually using your system's package manager or source code."
  esac

  exit 1; 
}

encrypt() {
  if [[ ! -z "$1" ]]; then
    KEY=707265696d707265736f436f72726563
    IV=50506172736574696d65313773327733

    echo -n $1 | openssl enc -aes128 -a -A -K $KEY -iv $IV
  else
    return 1;
  fi
}

urlencode() {
  local l=${#1}
  for (( i = 0 ; i < l ; i++ )); do
    local c=${1:i:1}
    case "$c" in
      [a-zA-Z0-9.~_-]) printf "$c" ;;
      ' ') printf + ;;
      *) printf '%%%.2X' "'$c"
    esac
  done
}

send_message() {
  if [[ -z "$1" || -z "$2" ]]; then
    echo "Notification error: No title or message defined"
    exit
  fi

  case $NOTIFICATION_SERVICE in
    pushover)
      $WORKING_DIR/services/pushover.sh "$1" "$2"
    ;;

    # signal)
    #   ./services/signal.sh "$2"
    # ;;
  *)
    echo "No notification service configured"
    exit 1
  esac
}

random_sleep() {
  MAX=4
  RAND=$(od -d -N2 -An /dev/urandom)
  RAND_NUM=$(( $RAND % $MAX + 1 ))

  echo "Waiting ${RAND_NUM}s between requests..."
  sleep $RAND_NUM
}

pad_to_two() {
  printf "%0*d\n" 2 $1
}

COOKIES_FILE=$WORKING_DIR/cookies.txt

URL_HOST="https://marangatu.set.gov.py"
URL_BASE="$URL_HOST/eset"

METHOD_AUTH="authenticate"
METHOD_MENU="perfil/menu"
METHOD_PROFILE="perfil/publico"
METHOD_PERMITE="declaracion/permite"
METHOD_PRESENTAR="presentar"

# Tax form related data
FORM_AFFIDAVIT=SG00005
TYPE="211"
FORM="120"

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
    echo "Error: Incorrect login credentials"
    exit
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
YEAR=$(date +%Y)
MONTH=$(date +%m)

[ $MONTH -eq "01" ] && ((YEAR--)) || YEAR=$YEAR
[ $MONTH -eq "01" ] && MONTH=12 || ((MONTH--))
MONTH=$(pad_to_two $MONTH)

if [[ ! "$NAME" = "" ]]; then
  echo "Welcome $(echo $NAME | awk '{print $2}')!"
else
  echo "Error: Could not get user data"
  exit
fi

echo "Preparing tax form..."
random_sleep
MENU=$(wget $WGET_FLAGS $WGET_OUTPUT --load-cookies $COOKIES_FILE --user-agent="$UA" "$URL_BASE/$METHOD_MENU?t3=$TOKEN")

# Necessary step to be able to create form later
METHOD_TAXPAYER=$(echo $MENU | jq --raw-output '.[] | select(.aplicacion == "'$FORM_AFFIDAVIT'") | .url')

TAXPAYER=$(wget $WGET_FLAGS $WGET_OUTPUT --load-cookies $COOKIES_FILE --user-agent="$UA" "$URL_BASE/$METHOD_TAXPAYER")

if ! echo $TAXPAYER | grep -q "Presentar Declaración"; then
  echo "Error: Tax payer not found"
  exit
fi

# Create tax form and get its url
echo "Retrieving tax form..."

TOKEN=$(encrypt '{"ruc":"'$CEDULA'","dv":"'$DV'","periodo":"'$YEAR$MONTH'","impuesto":"'$TYPE'","formulario":"'$FORM'","fechaDiferida":null}')
TOKEN=$(urlencode $TOKEN)

random_sleep
PERMIT=$(wget $WGET_FLAGS $WGET_OUTPUT --load-cookies $COOKIES_FILE --user-agent="$UA" "$URL_BASE/$METHOD_PERMITE?t3=$TOKEN")

IS_PERMITED=$(echo $PERMIT | jq --raw-output '.permite')

if [[ "$IS_PERMITED" = "false" ]]; then
  echo "Error: Tax form could not be retreived"
  exit
fi

# Load tax form
PERMIT_URL=$(echo $PERMIT | jq --raw-output '.url')
DECLARATION_FORM=$(wget $WGET_FLAGS $WGET_OUTPUT --load-cookies $COOKIES_FILE --user-agent="$UA" $HEADER "$URL_HOST$PERMIT_URL")

# Get name and value from HTML inputs
NAMES=$(xmllint --html --xpath "//input/@name" 2>/dev/null - <<< "$DECLARATION_FORM")
NAMES=$(echo $NAMES | sed 's/\s*name="dynamicProps(\([^"]*\))"/\1\n/g') # Remove dynamicProps()

VALUES=$(xmllint --html --xpath "//input/@value" 2>/dev/null - <<< "$DECLARATION_FORM")
VALUES=$(echo $VALUES | sed 's/value=""/value="null"\n/g') # Add null to empty string for better parsing later
VALUES=$(echo $VALUES | sed 's/\s*value="\([^"]*\)"/\1\n/g')

# Create arrays from the HTML inputs
set -f # Avoid globbing (expansion of *)
NAMES_ARR=(${NAMES// / })
VALUES_ARR=(${VALUES// / })
set +f

# Get the form's _cyp token
CYP=$(echo $PERMIT_URL | awk -F'[=&]' '{print $2}')

# Create a temporary json file for easier json operations
TMP_JSON=/tmp/tmp.json
rm -rf $TMP_JSON
touch $TMP_JSON

# Create JSON with _cyp
echo '{"_cyp":"'$CYP'"}' > $TMP_JSON

echo "Please wait! Processing tax form data..."
for I in "${!NAMES_ARR[@]}"; do
  NAME=${NAMES_ARR[I]}
  VALUE=${VALUES_ARR[I]:=0}

  # If middle name doesn't exists use empty string
  if [[ "$NAME" = "segundoApellido" && "$VALUE" = "0" ]]; then
    VALUE=""
  fi

  # Not used
  if [[ "$NAME" = "fechaDiferida" ]]; then
    VALUE=""
  fi

  # Manually added field
  if [[ "$NAME" = "exportador" ]]; then
    VALUE="0"
  fi

  if [[ "$NAME" != "C2" && "$NAME" != "C3" && "$VALUE" != "null" ]]; then
    echo $(jq --arg name "$NAME" --arg value "$VALUE" '.[$name] = $value' $TMP_JSON) > $TMP_JSON
  fi
done

# Remove spaces. Can't use jq because it adds slashes infront of "
echo $(cat $TMP_JSON | sed 's/ //g') > $TMP_JSON

DATA=$(cat $TMP_JSON)

# Temporary json file no longer needed
rm -rf $TMP_JSON

# TODO: submit the form and get a response
echo "Sending tax form..."
random_sleep
FINAL=$(wget $WGET_FLAGS $WGET_OUTPUT --load-cookies $COOKIES_FILE --header='Content-Type:application/json' --user-agent="$UA" --post-data=$DATA "$URL_BASE/$METHOD_PRESENTAR")

STATUS=$(echo $FINAL | jq --raw-output '.exito' 2>/dev/null)

if [[ "$STATUS" = "false" ]]; then
  ERROR=$(echo $FINAL | jq --raw-output '.operacion.errores[0].descripcion' 2>/dev/null)
  echo "Error: $ERROR"

  send_message "Error" "$ERROR"
else
  echo "VAT filed!"
  URL=$(echo $FINAL | jq --raw-output '.herramientas[1].url' 2>/dev/null)

  send_message "Success!" "Paraguay VAT filed successfully."
fi