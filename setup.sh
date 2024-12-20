#!/bin/bash
# Andino IO setup for POP script by Daniel Do Canto Batista @ MABU Concepts
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'



println_green (){
    printf "${GREEN}%s${NC}\n" "${1}"
}

println_red (){
    printf "${RED}%s${NC}\n" "${1}"
}

println (){
    printf "%s\n" "${1}"
}

if [ ! -w "${PWD}" ]; then
    println_red "Directory is not writable!"
fi

println_red "!!! Installation started !!!"


# update and upgrade
println_green "Updating & upgrading packages..."

sudo apt-get update
sudo apt-get upgrade -y



# wifi config
println_green "Configuring wifi..."
println_green "Configuring wifi password:"
read PASSWORD
println_green "Configuring wifi interface:"
read INTERFACE

sudo nmcli device wifi Hotspot ssid Sensora password $PASSWORD ifname $INTERFACE

sudo nmcli connection modify Hotspot connection.autoconnect yes



# install mosquitto broker
println_green "Installing mosquitto broker..."

sudo apt-get install mosquitto mosquitto-clients -y

println_green "Enter your MQTT username:"
read USERNAME

mosquitto_passwd -c /etc/mosquitto/passwd $USERNAME

println_green "Enter your MQTT username for Node-Red:"
read NODEREDUSERNAME
println_green "Enter password for $NODEREDUSERNAME:"
read -s NODEREDPASSWORD
sudo mosquitto_passwd -b /etc/mosquitto/passwd "$NODEREDUSERNAME" "$NODEREDPASSWORD"


ACL_FILE="/etc/mosquitto/acl"

sudo tee "$ACL_FILE" > /dev/null <<EOF
    user $USERNAME
    topic readwrite #

    user $NODEREDUSERNAME
    topic read #
EOF

# Restart Mosquitto service
if sudo systemctl restart mosquitto; then
    println_green "Mosquitto broker installed and configured successfully."
else
    echo "Failed to restart Mosquitto. Please check your configuration."
    exit 1
fi

sudo systemctl restart mosquitto

# install Database
println_green "Installing database..."

sudo apt install sqlite3 -y

DB_DIR="db"
DB_NAME="smartMeter.db"

sudo mkdir -p "$DB_DIR"
sudo chmod 777 -R "$DB_DIR"

DB_PATH="$DB_DIR/$DB_NAME"

sqlite3 "$DB_PATH" <<EOF
CREATE TABLE smartmeter(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(255),
    value REAL,
    unit VARCHAR(100),
    timestamp DATETIME
);

CREATE TABLE smartmetergeneral(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(255),
    value REAL,
    timestamp DATETIME
);
EOF

sudo chmod 777 $DB_PATH

println_green "SQLite database and tables created successfully."



# install tcpdump
println_green "Installing tcpdump..."

sudo apt-get install tcpdump



# SSH Certificate
println_green "Generating SSH certificate..."

println_green "Enter your Passphrase:"
read PASSPHRASE

ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "$PASSPHRASE"

mkdir -p ~/.ssh
chmod 700 ~/.ssh

cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

println_green "SSH certificate Generated successfully."



# Installing mbpoll
println_green "Installing mbpoll..."

wget -O- http://www.piduino.org/piduino-key.asc | sudo apt-key add -echo 'deb http://raspbian.piduino.org stretch piduino' | sudo tee /etc/apt/

sudo apt update

sudo apt install mbpoll -y



# configuring ntp server
println_green "Configuring ntp server..."

sudo apt install ntp -y

CONFIG_FILE="/etc/ntpsec/ntp.conf"
NTP_SERVER="194.154.216.81"

# Backup the original configuration file
sudo cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

# Check if the configuration file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Configuration file not found at $CONFIG_FILE. Exiting."
    exit 1
fi

# Update the NTP configuration
sudo sed -i -e 's/^\(pool \|server \)/#&/g' "$CONFIG_FILE"

# Add the new NTP server line
sudo sed -i '/^# Specify one or more NTP servers\./a server '"$NTP_SERVER"' iburst' "$CONFIG_FILE"

# Restart the NTP service
if sudo systemctl restart ntpsec; then
    echo "NTP server updated to $NTP_SERVER and service restarted successfully."
else
    echo "Failed to restart the NTP service. Please check the configuration."
    exit 1
fi

# Configure IP Tables
println_green "Configuring IP tables..."

sudo apt install iptables

iptables -A FORWARD -i $INTERFACE -o eth0 -j DROP



# Andino setup
println_green "Andino setup started..."

wget 'https://raw.githubusercontent.com/andino-systems/andinopy/main/install_scripts/setup.sh'

chmod +x setup.sh

sudo ./setup.sh -m IO -n -s -o

println_green "Installing sample & configuration flows..."

#wget "https://raw.githubusercontent.com/andino-systems/Andino/master/Andino-Common/src/NodeRed/Flows/flows.json"
#sudo cp flows.json /root/.node-red/flows.json
#sudo rm flows.json



println_green "!!! Installation completed !!!"
println_green "Please copy the content of the file ~/.ssh to your the device."
println_green "Run 'sudo reboot' to restart the system"