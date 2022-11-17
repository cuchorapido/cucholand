#!/bin/bash -vx
#
# Install, configure and start a new Minecraft server
# This supports Ubuntu and Amazon Linux 2 flavors of Linux (maybe/probably others but not tested).

#exec > >(tee /var/log/tf-user-data.log|logger -t user-data) 2>&1
set -x

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
  /usr/bin/apt-get -yq install -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" openjdk-18-jre wget awscli jq curl git glances
  /bin/cat <<"__UPG__" > /etc/apt/apt.conf.d/10periodic
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
__UPG__

  # Init script for starting, stopping
echo '
#!/bin/bash
# Short-Description: Minecraft server

start() {
  echo "comenzar el servidor de minecraft /home/mc..."
  start-stop-daemon --start --quiet  --pidfile ${mc_root}/minecraft.pid -m -b -c $SSH_USER -d ${mc_root} --exec /usr/bin/java -- -Xmx${java_mx_mem} -Xms${java_ms_mem} -jar $MINECRAFT_JAR nogui
}

stop() {
  echo "Parar servidor de minecraft..."
  start-stop-daemon --stop --pidfile ${mc_root}/minecraft.pid
}

case \$1 in
  start)
    start
    ;;
  stop)
    stop
    ;;
  restart)
    stop
    sleep 5
    start
    ;;
esac
exit 0
' | tee -a /etc/init.d/minecraft

  # Start up on reboot
  /bin/chmod +x /etc/init.d/minecraft
  /usr/sbin/update-rc.d minecraft defaults

}

# 

### Thanks to https://github.com/kenoir for pointing out that as of v15 (?) we have to
### use the Mojang version_manifest.json to find java download location
### See https://minecraft.gamepedia.com/Version_manifest.json
download_minecraft_server() {

  WGET=$(which wget)

  # version_manifest.json lists available MC versions
  $WGET -O ${mc_root}/version_manifest.json https://launchermeta.mojang.com/mc/game/version_manifest.json

  # Find latest version number if user wants that version (the default)
  if [[ "${mc_version}" == "latest" ]]; then
    MC_VERS=$(jq -r '.["latest"]["'"${mc_type}"'"]' ${mc_root}/version_manifest.json)
  fi

  # Index version_manifest.json by the version number and extract URL for the specific version manifest
  VERSIONS_URL=$(jq -r '.["versions"][] | select(.id == "'"$MC_VERS"'") | .url' ${mc_root}/version_manifest.json)
  # From specific version manifest extract the server JAR URL
  SERVER_URL=https://launcher.mojang.com/v1/objects/c8f83c5655308435b3dcf03c06d9fe8740a77469/server.jar
  #https://launchermeta.mojang.com/v1/packages/f1cf44b0fb6fe11910bac139617b72bf3ef330b9/1.18.2.json
  #$(curl -s $VERSIONS_URL | jq -r '.downloads | .server | .url')
  # And finally download it to our local MC dir
  $WGET -O ${mc_root}/$MINECRAFT_JAR $SERVER_URL
  
  #mc_root=/home/mc
  
}

MINECRAFT_JAR="minecraft_server.jar"
case $OS in
  Ubuntu*)
    ubuntu_linux_setup
    ;;
  Amazon*)
    amazon_linux_setup
    ;;
  *)
    echo "$PROG: unsupported OS $OS"
    exit 1
esac

# Create mc dir, sync S3 to it and download mc if not already there (from S3)
/bin/mkdir -p ${mc_root}
/usr/bin/aws s3 sync s3://${mc_bucket} ${mc_root}

# Download server if it doesn't exist on S3 already (existing from previous install)
# To force a new server version, remove the server JAR from S3 bucket
if [[ ! -e "${mc_root}/$MINECRAFT_JAR" ]]; then
  echo [INFO] A punto de descargar minecraft....
  download_minecraft_server
  echo [INFO] Listo, ya termino esta chimbada...
fi

# Cron job to sync data to S3 every ten mins
/bin/cat <<CRON > /etc/cron.d/minecraft
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:${mc_root}
*/${mc_backup_freq} * * * *  $SSH_USER  /usr/bin/aws s3 sync ${mc_root}  s3://${mc_bucket}
CRON

# Update minecraft EULA
/bin/cat >${mc_root}/eula.txt<<EULA
#By changing the setting below to TRUE you are indicating your agreement to our EULA (https://account.mojang.com/documents/minecraft_eula).
#Tue Jan 27 21:40:00 UTC 2015
eula=true
EULA

# Not root
/bin/chown -R $SSH_USER ${mc_root}

# Start the server
case $OS in
  Ubuntu*)
    /etc/init.d/minecraft start
    ;;
  Amazon*)
    /usr/bin/systemctl start minecraft
    ;;
esac

exit 0




# TODO: 
# automaticamente cuadrar el online-mode a false en los server.properties en /home/mc
# hacer que arranque automaticamente el servicio de mc en vez de hacerlo manual
# poner una ip estatica del server
# agregale un hostname al ip del server ex. cucholand.lxhxr.com
# allow-flight=true en el server.properties
# difficulty=hard (de easy) en el server.properties
# poner whitelist para los activetes
