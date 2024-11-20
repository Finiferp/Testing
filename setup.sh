#!/bin/bash
# Andino IO setup for POP script by Daniel Do Canto Batista @ MABU Concepts
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

if [ ! -w "${PWD}" ]; then
    println_red "Directory is not writable!"
    usage
fi

println_green (){
    printf "${GREEN}%s${NC}\n" "${1}"
}

println_red (){
    printf "${RED}%s${NC}\n" "${1}"
}

println (){
    printf "%s\n" "${1}"
}

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



# install mosquitto boker
println_green "Installing mosquitto broker..."

sudo apt-get install mosquitto mosquitto-clients -y

mosquitto_passwd -U /etc/mosquitto/passwd

ACL_FILE="/etc/mosquitto/acl"

# Create or overwrite the file with the required content
sudo sh -c "cat > $ACL_FILE" <<EOF
user Username
topic readwrite #

user MQTTNodeRed
topic read #
EOF

# Restart the Mosquitto service
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

sudo ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "$PASSPHRASE"

sudo cd ~/.ssh

sudo cat id_rsa.pub >> authorized_keys

println_green "SSH certificate Generated successfully."



# Installing mbpoll
println_green "Installing mbpoll..."

wget -O- http://www.piduino.org/piduino-key.asc | sudo apt-key add -echo 'deb http://raspbian.piduino.org stretch piduino' | sudo tee /etc/apt/

sudo apt update

sudo apt install mbpoll



# configuring ntp server
println_green "Configuring ntp server..."

sudo apt install ntp -y

NTP_SERVER="194.154.216.81"
NTP_CONFIG="/etc/ntp.conf"

if [[ -f "$NTP_CONFIG" ]]; then
    println "Updating NTP server configuration..."
    # Comment out existing server lines
    sed -i 's/^server /#server /g' "$NTP_CONFIG"
    # Add the new NTP server
    println_green "server $NTP_SERVER iburst" >> "$NTP_CONFIG"
    println_green "NTP server updated to $NTP_SERVER."
else
    println_green "NTP configuration file not found at $NTP_CONFIG."
    exit 1
fi

if systemctl restart ntp 2>/dev/null; then
    println "NTP service restarted successfully."
elif service ntp restart 2>/dev/null; then
    println "NTP service restarted successfully."
else
    println "Failed to restart the NTP service. Please check your system."
    exit 1
fi

# Configure IP Tables
println_green "Configuring IP tables..."

sudo apt install iptables

iptables -A FORWARD -i wlan0 -o $INTERFACE -j DROP



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