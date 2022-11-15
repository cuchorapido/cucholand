#!/bin/bash
#
# Install, configure and start a new Minecraft server
# This supports Ubuntu and Amazon Linux 2 flavors of Linux (maybe/probably others but not tested).

#exec > >(tee /var/log/tf-user-data.log|logger -t user-data) 2>&1
set -x

readonly JAVA_MX_MEM=${tpl_java_mx_mem}
readonly JAVA_MS_MEM=${tpl_java_ms_mem}
readonly REGION=${tpl_region}
readonly STATIC_IP=${tpl_eip}
readonly STATIC_IP_ID=${tpl_eip_id}
readonly VOLUME_ID=${tpl_volume_id}

# Determine linux distro
if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID

elif type lsb_release >/dev/null 2>&1; then
    # linuxbase.org
    OS=$(lsb_release -si)
    VER=$(lsb_release -sr)

elif [ -f /etc/lsb-release ]; then
    # For some versions of Debian/Ubuntu without lsb_release command
    . /etc/lsb-release
    OS=$DISTRIB_ID
    VER=$DISTRIB_RELEASE

elif [ -f /etc/debian_version ]; then
    # Older Debian/Ubuntu/etc.
    OS=Debian
    VER=$(cat /etc/debian_version)
elif [ -f /etc/SuSe-release ]; then
    # Older SuSE/etc.
    ...
elif [ -f /etc/redhat-release ]; then
    # Older Red Hat, CentOS, etc.
    ...
else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    OS=$(uname -s)
    VER=$(uname -r)
fi

# Update OS and install start script
ubuntu_linux_setup() {
  export SSH_USER="ubuntu"
  export DEBIAN_FRONTEND=noninteractive
  /usr/bin/apt-get update
  /usr/bin/apt-get -yq install -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" openjdk-18-jre wget awscli jq curl git glances unzip tree docker.io docker-compose acl
  sudo setfacl -m user:ubuntu:rw /var/run/docker.sock
  sudo chmod a+rwx /var/run/docker.sock
  sudo usermod -aG docker ubuntu
  sudo newgrp docker
  /bin/cat <<"__UPG__" > /etc/apt/apt.conf.d/10periodic
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
__UPG__


}

ubuntu_linux_setup

# remove last sshd login
sudo sed -i 's;#PrintLastLog yes;PrintLastLog no;g' /etc/ssh/sshd_config

HOME=/home/ubuntu

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

if [[ $STATIC_IP_ID == "" ]]; then
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
else
    aws ec2 wait instance-running --instance-id=$INSTANCE_ID --region "$REGION"
    aws ec2 associate-address --instance-id=$INSTANCE_ID --allocation-id=$STATIC_IP_ID --allow-reassociation --region "$REGION" 
    PUBLIC_IP=$STATIC_IP
fi


echo "Waiting for $${VOLUME_ID} to become avaialble..."
aws ec2 wait volume-available --volume-ids $VOLUME_ID --region $REGION
echo "$${VOLUME_ID} is now avaialble, mounting it now..."

if ! aws ec2 attach-volume --volume-id $VOLUME_ID --instance-id $INSTANCE_ID --device /dev/sdf --region $REGION && sleep 5; then
    echo $?
fi


# partition 
#if 
sudo mkfs -t -f xfs /dev/xvdf
sudo mkdir -p /data
sudo mount /dev/xvdf /data
mkdir -p /data/database
sudo chown -R ubuntu:ubuntu /data

mkdir -p /data/database/luckyperms
mkdir -p /data/database/fastlogin

sudo chmod -R 777 /data/database

# driver: 'com.mysql.jdbc.Driver'
# host: '199.127.60.66'
# port: 3306
# database: 's4932_fastlogin'
# username: 'u4932_bGHQCMzOJW'
# password: 'enA44Rw^75gx8og.+ncrpXx='

# PASSPHRASE=

                #  -e MYSQL_DATABASE=s4932_fastlogin \
                #  -e MYSQL_USER=u4932_bGHQCMzOJW \
                #  -e MYSQL_PASSWORD=enA44Rw^75gx8og.+ncrpXx= \
#run mysql luckyperms
docker pull -q mysql:latest 


docker run -d -t -p 0.0.0.0:3306:3306 --name luckperms \
                 -v /data/database/luckyperms:/var/lib/mysql \
                 -e MYSQL_DATABASE=s4932_luckperms \
                 -e MYSQL_ROOT_PASSWORD=rootpass mysql:latest

# docker run -d -t -p 0.0.0.0:3306:3306 --name luckperms \
#                  -v /data/database/luckperms:/var/lib/mysql \
#                  -e MYSQL_DATABASE=s4932_luckperms \
#                  -e MYSQL_USER=u4932_7pLx2eC2SR \
#                  -e MYSQL_PASSWORD=enA44Rw^75gx8og.+ncrpXx= \
#                  -e MYSQL_ROOT_PASSWORD=rootpass mysql:latest

sleep 15



docker run -d -t -p 0.0.0.0:3307:3306 --name fastlogin \
                 -v /data/database/fastlogin:/var/lib/mysql \
                 -e MYSQL_DATABASE=s4932_fastlogin \
                 -e MYSQL_ROOT_PASSWORD=rootpass mysql:latest    

sleep 15



# upload command
# aws s3 cp c:\usuarios\sanba\AelCraft.zip s3://cuchorapido/minecraft/AelCraft.zip

# ls c:\usuarios\sanba\AelCraft.zip

# download command
AELCRAFT_HOME=/data/AelCraft
cd /data/
mkdir -p $AELCRAFT_HOME
cd $AELCRAFT_HOME

if [ -d $AELCRAFT_HOME/Bungecord ]; then

  echo "Ya existe bungecord!!!! LOL"

else
  # 45MB
  aws s3 cp s3://cuchorapido/minecraft/Bungecord.zip Bungecord.zip
  unzip Bungecord.zip
  rm -rf Bungecord.zip
  sudo chown -R ubuntu:ubuntu Bungecord
fi

tree /data

# replace mysql configs for bungecord

# replace FastLogin
sed -i 's;199.127.60.66;127.0.0.1;g' /data/AelCraft/Bungecord/plugins/FastLogin/config.yml
sed -i 's;port: 3306;port: 3307;g' /data/AelCraft/Bungecord/plugins/FastLogin/config.yml
sed -i 's;u4932_bGHQCMzOJW;root;g' /data/AelCraft/Bungecord/plugins/FastLogin/config.yml
sed -i 's;enA44Rw^75gx8og.+ncrpXx=;rootpass;g' /data/AelCraft/Bungecord/plugins/FastLogin/config.yml
sed -i 's~#allowPublicKeyRetrieval=~allowPublicKeyRetrieval:~g' /data/AelCraft/Bungecord/plugins/FastLogin/config.yml

# replace LuckPerms
sed -i 's;199.127.60.66;127.0.0.1;g' /data/AelCraft/Bungecord/plugins/LuckPerms/config.yml
sed -i 's;u4932_7pLx2eC2SR;root;g' /data/AelCraft/Bungecord/plugins/LuckPerms/config.yml
sed -i 's;enA44Rw^75gx8og.+ncrpXx=;rootpass;g' /data/AelCraft/Bungecord/plugins/LuckPerms/config.yml

#  #useSSL: false
#       #verifyServerCertificate: false

#       useSSL: false
#       verifyServerCertificate: true

# bungecord setup
echo '
#!/bin/bash

cd '$AELCRAFT_HOME'/Bungecord/
java -Xmx'$${JAVA_MX_MEM}' -Xms'$${JAVA_MS_MEM}' -jar proxy.jar nogui
' > $HOME/start-bungecord.sh

sudo chmod a+x $HOME/start-bungecord.sh
sudo chown ubuntu:ubuntu $HOME/start-bungecord.sh

echo '[Unit]
Description=Minecraft - bungecord
After=network.target

[Service]
WorkingDirectory='$HOME'
ExecStart=/bin/bash '$HOME'/start-bungecord.sh
Restart=on-failure
Type=simple
User=ubuntu

[Install]
WantedBy=multi-user.target' | sudo tee /etc/systemd/system/bungecord.service

sudo systemctl enable bungecord

sudo service bungecord start 

sudo chown -R ubuntu:ubuntu /data




# # lobby setup
# echo '
# #!/bin/bash

# cd '$AELCRAFT_HOME'/Lobby/
# java -Xmx2048 -Xms2048 -jar server.jar nogui

# ' > $HOME/start-lobby.sh

# chmod a+x $HOME/start-lobby.sh

# echo '[Unit]
# Description=Minecraft - Lobby
# After=network.target

# [Service]
# WorkingDirectory='$HOME'
# ExecStart=/bin/bash '$HOME'/start-lobby.sh
# Restart=on-failure
# Type=simple
# User=ubuntu

# [Install]
# WantedBy=multi-user.target' | sudo tee /etc/systemd/system/lobby.service

# sudo systemctl lobby disable

# sudo service lobby stop 


# TODO: 
# automaticamente cuadrar el online-mode a false en los server.properties en /home/mc
# hacer que arranque automaticamente el servicio de mc en vez de hacerlo manual
# poner una ip estatica del server
# agregale un hostname al ip del server ex. cucholand.lxhxr.com
# allow-flight=true en el server.properties
# difficulty=hard (de easy) en el server.properties
# poner whitelist para los activetes


exit 0
