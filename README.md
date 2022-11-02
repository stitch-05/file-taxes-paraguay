# Automatically file VATs in Paraguay
As a Paraguay tax resident (having a Tax ID) you have to file VATs (form 211) once a month and sometimes even the summary of receipts (even if you never claimed any). This script files all necessary taxes for you (in case of VAT it files 0 guarani tax).

> :warning: ** Don't use the script if your VAT is not 0!

Feel free to [support me](#support-me) if you find this helfpul. Thank you!

## 1) Dependencies (choose one)
You need these two packages to parse json and html: `jq`, `xmllint`

### 1.1) Install on Mac
Install [brew](https://brew.sh/) first if you haven't done so already.

Now install `jq`:
````
brew install jq
````

`xmllint` is installed by default on MacOS Ventura (and perhaps older).

### 1.2) Install on Debian based distros
Update repo and install the packages:

````
sudo apt update && sudo apt install jq libxml2-utils
````

### 1.3) Install on RedHad distros
Install the packages:

````
sudo dnf install jq libxml2-utils
````

## 2) Basic Setup
Go to a directory of your choice and clone the repo:

````
git clone https://github.com/stitch-05/file-vat-paraguay.git && cd file-vat-paraguay
````

Either fill in your login information (`USERNAME` and `PASSWORD`) in `.env` or create `.env.local` and add those parameters there.

## 3) Run
````
./file-taxes.sh
````
It may take up to a minute for the script to finish because of random pauses between each request. Let it finish.

## 4) Setup cron job (optional)
You can use cron to run the script automatically on the 2nd day of each month at 3am of your local time.

Open crontab for editing:

````
crontab -e
````

and add the following:

````
0 3 2 * * /home/<user>/<path to script/file-taxes.sh >/dev/null 2>&1
````

## 5) Receive Notifications (optional)

Receive a notification everytime the script fails or succeeds to file VAT. 

### 5.1) Pushover
To use [Pushover](https://pushover.net/) as your notification service, create your pushover token and add the following to `.env` or `.env.local`:

````
NOTIFICATION_SERVICE="pushover"

PUSHOVER_TOKEN=<your pushover token>
PUSHOVER_USER=<your pushover user>
````

### 5.2) Signal
To use [Signal](https://signal.org) as your notification service, install [signal-cli](https://github.com/asamk/signal-cli) (beyond the scope of this tutorial) and add the following to `.env` or `.env.local`:
````
NOTIFICATION_SERVICE="signal"

SIGNAL_NUMBER=<your signal phone number>
````

## Support me
I spent a lot of time figuring out Paraguay's tax portal (kudos to Paraguay gov for making it fairly hard to automatize) and making it work. 

If you find this script helpful, your Bitcoin or Monero donation is very much appreciated:

#### Bitcoin Address
````
bc1qxwuj3rty9krmtaf6tvah6cktkaktfgx0jagtva
````

![qr-btc](https://user-images.githubusercontent.com/104267488/199220610-878b531d-5387-4fa3-b99c-702d83dbe717.png)


#### Monero Address
````
87D74aNPpJs6cfJJStv9yj7LYaAW4oJcQX1YqzpvaGokYd2dhMeYzhPNHBrBUdzKrvW9LyFkL2xVBTrhT9rpNocAAH1Z2Qt
````

![qr-xmr](https://user-images.githubusercontent.com/104267488/199220635-ae90a9cd-e4d4-4e34-b6ec-502c6f3b0517.png)


# Thank you!
