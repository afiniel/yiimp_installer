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
source $HOME/Yiimpoolv2/yiimp_single/.wireguard.install.cnf

# Display terminal art and initial messages
echo
term_art
echo
echo -e "$MAGENTA     <--$YELLOW Compile Stratum$NC"
echo

# Navigate to the setup directory
cd /home/crypto-data/yiimp/yiimp_setup

# Informing the user about the build process
echo
echo -e "$MAGENTA => Building$GREEN blocknotify$MAGENTA, $GREENiniparser$MAGENTA, $GREENstratum$MAGENTA ... <= $NC"

# Generate a random password for blocknotify
blckntifypass=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

# Compile blocknotify
cd /home/crypto-data/yiimp/yiimp_setup/yiimp/blocknotify
sudo sed -i "s/tu8tu5/$blckntifypass/" blocknotify.cpp
hide_output make -j$(nproc)

# Compile stratum
cd /home/crypto-data/yiimp/yiimp_setup/yiimp/stratum
hide_output git submodule init
hide_output git submodule update
hide_output sudo make -C algos
hide_output sudo make -C sha3
hide_output sudo make -C iniparser
cd secp256k1
chmod +x autogen.sh
hide_output ./autogen.sh
hide_output ./configure --enable-experimental --enable-module-ecdh --with-bignum=no --enable-endomorphism
hide_output make -j$(nproc)
cd ..

# Update Makefile if AutoExchange is enabled
if [[ "$AutoExchange" =~ ^[Yy][Ee]?[Ss]?$ ]]; then
  sudo sed -i 's/CFLAGS += -DNO_EXCHANGE/#CFLAGS += -DNO_EXCHANGE/' Makefile
fi

hide_output make -j$(nproc)

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
if [[ "$wireguard" == "true" ]]; then
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

# Return to the original directory
cd $HOME/Yiimpoolv2/yiimp_single