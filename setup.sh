#!/bin/bash
# Andino IO setup script by Daniel Do Canto Batista @ MABU Concepts

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

println_green () {
    printf "${GREEN}%s${NC}\n" "${1}"
}

println_red () {
    printf "${RED}%s${NC}\n" "${1}"
}

println () {
    printf "%s\n" "${1}"
}

# Ensure script is run in a writable directory
if [ ! -w "${PWD}" ]; then
    println_red "Directory is not writable!"
    exit 1
fi

println_red "!!! Installation started !!!"

# Update and upgrade
println_green "Updating & upgrading packages..."
sudo apt-get update && sudo apt-get upgrade -y

# WiFi configuration
println_green "Configuring WiFi..."
println_green "Enter WiFi password:"
read -s PASSWORD
println_green "Enter WiFi interface (e.g., wlan0):"
read INTERFACE
sudo nmcli device wifi Hotspot ssid Sensora password "$PASSWORD" ifname "$INTERFACE"
sudo nmcli connection modify Hotspot connection.autoconnect yes

# Install Mosquitto broker
println_green "Installing Mosquitto broker..."
sudo apt-get install mosquitto mosquitto-clients -y

println_green "Enter your MQTT username:"
read USERNAME
sudo mosquitto_passwd -c /etc/mosquitto/passwd "$USERNAME"

println_green "Enter your MQTT username for Node-Red:"
read NODEREDUSERNAME
println_green "Enter password for $NODEREDUSERNAME:"
read -s NODEREDPASSWORD
sudo mosquitto_passwd -b /etc/mosquitto/passwd "$NODEREDUSERNAME" "$NODEREDPASSWORD"

# Configure ACL file
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
    println_red "Failed to restart Mosquitto. Please check your configuration."
    exit 1
fi

# Install database
println_green "Installing SQLite3 database..."
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

sudo chmod 777 "$DB_PATH"
println_green "SQLite database and tables created successfully."

# Install tcpdump
println_green "Installing tcpdump..."
sudo apt-get install tcpdump -y

# SSH Certificate
println_green "Generating SSH certificate..."
println_green "Enter your Passphrase:"
read PASSPHRASE
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "$PASSPHRASE"
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
println_green "SSH certificate generated successfully."

# Install mbpoll
println_green "Installing mbpoll..."
wget -O- http://www.piduino.org/piduino-key.asc | sudo apt-key add -
echo 'deb http://raspbian.piduino.org stretch piduino' | sudo tee /etc/apt/sources.list.d/piduino.list
sudo apt update
sudo apt install mbpoll -y

# Configure NTP server
println_green "Configuring NTP server..."
sudo apt install ntp -y
CONFIG_FILE="/etc/ntpsec/ntp.conf"
NTP_SERVER="194.154.216.81"

if [[ -f "$CONFIG_FILE" ]]; then
    sudo cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    sudo sed -i -e 's/^\(pool \|server \)/#&/g' "$CONFIG_FILE"
    sudo sed -i '/^# Specify one or more NTP servers\./a server '"$NTP_SERVER"' iburst' "$CONFIG_FILE"
    if sudo systemctl restart ntpsec; then
        println_green "NTP server updated to $NTP_SERVER and service restarted successfully."
    else
        println_red "Failed to restart the NTP service. Please check the configuration."
        exit 1
    fi
else
    println_red "NTP configuration file not found at $CONFIG_FILE."
    exit 1
fi

# Configure IP Tables
println_green "Configuring IP tables..."
sudo apt install iptables -y
sudo iptables -A FORWARD -i "$INTERFACE" -o eth0 -j DROP

# Andino setup
println_green "Andino setup started..."
wget 'https://raw.githubusercontent.com/andino-systems/andinopy/main/install_scripts/setup.sh'
chmod +x setup.sh
sudo ./setup.sh -m IO -n -s -o
println_green "Installing sample & configuration flows..."

println_green "!!! Installation completed !!!"
println_green "Please copy the content of the file ~/.ssh to your the device."
println_green "Run 'sudo reboot' to restart the system."
