#!/usr/bin/env bash

##########################################
# Created by Afiniel for Yiimpool use
# 
# This script compiles and sets up the 
# Stratum server for a YiiMP cryptocurrency 
# mining pool. It builds necessary components 
# such as blocknotify, iniparser, and stratum, 
# sets up the file structure, and updates 
# configuration files with appropriate 
# database and server information.
# 
# Author: Afiniel
# Date: 2024-07-15
##########################################

# Load configuration files
source /etc/functions.sh
source /etc/yiimpool.conf
source $STORAGE_ROOT/yiimp/.yiimp.conf
source $HOME/Yiimpoolv1/yiimp_single/.wireguard.install.cnf

# Display terminal art and initial messages
echo
term_art
echo
echo -e "$YELLOW Building Stratum...$NC"
echo

# Navigate to the setup directory
cd /home/crypto-data/yiimp/yiimp_setup

#Install dependencies
echo
echo -e "$MAGENTA => Installing Package to compile cryptocurrency... <= $COL_RESET"
hide_output sudo apt-get update
hide_output sudo apt-get -y upgrade
hide_output sudo apt-get -y install p7zip-full
apt_install build-essential libzmq5 libtool autotools-dev automake pkg-config libssl-dev libevent-dev bsdmainutils cmake libboost-all-dev zlib1g-dev \
libseccomp-dev libcap-dev libminiupnpc-dev gettext libcanberra-gtk-module libqrencode-dev libzmq3-dev \
libqt5gui5 libqt5core5a libqt5webkit5-dev libqt5dbus5 qttools5-dev qttools5-dev-tools libprotobuf-dev protobuf-compiler

# Informing the user about the build process
echo
echo -e "$MAGENTA => Building$GREEN blocknotify$MAGENTA, $GREEN iniparser$MAGENTA ... <= $NC"

# Generate a random password for blocknotify
blckntifypass=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

# Compile blocknotify
cd /home/crypto-data/yiimp/yiimp_setup/yiimp/blocknotify
sudo sed -i "s/tu8tu5/$blckntifypass/" blocknotify.cpp
hide_output sudo make -j$(nproc)

# Compile stratum
cd /home/crypto-data/yiimp/yiimp_setup/yiimp/stratum
hide_output sudo git submodule init
hide_output sudo git submodule update
hide_output sudo make -C algos
hide_output sudo make -C sha3
hide_output sudo make -C iniparser
cd secp256k1 && sudo chmod +x autogen.sh && hide_output sudo ./autogen.sh && hide_output sudo ./configure --enable-experimental --enable-module-ecdh --with-bignum=no --enable-endomorphism && hide_output sudo make -j$((`nproc`+1))

# Update Makefile if AutoExchange is enabled
if [[ "$AutoExchange" =~ ^[Yy][Ee]?[Ss]?$ ]]; then
  sudo sed -i 's/CFLAGS += -DNO_EXCHANGE/#CFLAGS += -DNO_EXCHANGE/' Makefile
fi

if [[ "$DISTRO" == "22" || "$DISTRO" == "23" || "$DISTRO" == "24" ]]; then
    # Use newer compiler flags for Ubuntu 22.04, 23.04 and 24.04
    hide_output sudo make CFLAGS="-march=native -O3" CXXFLAGS="-march=native -O3"
else
    # Existing compilation command for other versions
    hide_output sudo make -j$(nproc)
fi

# Setting up the stratum folder structure and copying files
echo -e "$CYAN => Building stratum folder structure and copying files... <= $NC"
cd $STORAGE_ROOT/yiimp/yiimp_setup/yiimp/stratum
sudo cp -a config.sample/. $STORAGE_ROOT/yiimp/site/stratum/config
sudo cp -r stratum run.sh $STORAGE_ROOT/yiimp/site/stratum

# Copy blocknotify to the appropriate directories
cd $STORAGE_ROOT/yiimp/yiimp_setup/yiimp
sudo cp blocknotify/blocknotify $STORAGE_ROOT/yiimp/site/stratum
sudo cp blocknotify/blocknotify /usr/bin

# Create run.sh for stratum config
sudo tee $STORAGE_ROOT/yiimp/site/stratum/config/run.sh > /dev/null <<'EOF'
#!/usr/bin/env bash
source /etc/yiimpool.conf
source $STORAGE_ROOT/yiimp/.yiimp.conf
ulimit -n 10240
ulimit -u 10240
cd "$STORAGE_ROOT/yiimp/site/stratum"
while true; do
  ./stratum config/$1
  sleep 2
done
exec bash
EOF

sudo chmod +x $STORAGE_ROOT/yiimp/site/stratum/config/run.sh

# Create main run.sh for stratum
sudo tee $STORAGE_ROOT/yiimp/site/stratum/run.sh > /dev/null <<'EOF'
#!/usr/bin/env bash
source /etc/yiimpool.conf
source $STORAGE_ROOT/yiimp/.yiimp.conf
cd "$STORAGE_ROOT/yiimp/site/stratum/config/" && ./run.sh $*
EOF

sudo chmod +x $STORAGE_ROOT/yiimp/site/stratum/run.sh

# Update stratum config files with database connection info
echo -e "$YELLOW => Updating stratum config files with database$GREEN connection$YELLOW info <= $NC"
cd $STORAGE_ROOT/yiimp/site/stratum/config

sudo sed -i "s/password = tu8tu5/password = $blckntifypass/g" *.conf
sudo sed -i "s/server = yaamp.com/server = $StratumURL/g" *.conf
if [[ ("$wireguard" == "true") ]]; then
  sudo sed -i "s/host = yaampdb/host = $DBInternalIP/g" *.conf
else
  sudo sed -i "s/host = yaampdb/host = localhost/g" *.conf
fi
sudo sed -i "s/database = yaamp/database = $YiiMPDBName/g" *.conf
sudo sed -i "s/username = root/username = $StratumDBUser/g" *.conf
sudo sed -i "s/password = patofpaq/password = $StratumUserDBPassword/g" *.conf

# Set permissions
sudo setfacl -m u:$USER:rwx $STORAGE_ROOT/yiimp/site/stratum/
sudo setfacl -m u:$USER:rwx $STORAGE_ROOT/yiimp/site/stratum/config

sleep 1.5
term_art
echo -e "$GREEN => Stratum build complete $NC"

cd $HOME/Yiimpoolv1/yiimp_single
