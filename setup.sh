#!/bin/sh

PALWORLD_HOME_PATH=/home/ubuntu/.steam/SteamApps/common/PalServer
PALWORLD_SCRPIT_PATH=$PALWORLD_HOME_PATH/PalServer.sh
PALWORLD_CONFIG_FILE=$PALWORLD_HOME_PATH/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini
RCON_PORT=25575
PASSWORD=""
PALWORLD_USER=$(whoami)

install_rcon() {
    sudo cp rcon /usr/bin/
    sudo chmod +x /usr/bin/rcon
}

install_cron_file() {
    MEM_CHECK_CRON_NAME=memcheck
    CURRENT_DIR=$(pwd)
    cat <<EOF > $MEM_CHECK_CRON_NAME
*/2 * * * * root $CURRENT_DIR/memcheck.sh >> /var/memcheck.log 2>&1
EOF
    sudo cp $MEM_CHECK_CRON_NAME /etc/cron.d/
}

generate_job_file() {
    echo '[*] generate job file'
    cat <<EOF > job.sh
#!/bin/sh
RCON_PORT=$RCON_PORT
PASSWORD=$PASSWORD
PALWORLD_HOME_PATH=$PALWORLD_HOME_PATH
PALWORLD_SCRPIT_PATH=$PALWORLD_SCRPIT_PATH
IP=127.0.0.1
EOF
echo '
echo "[+] palworld save data\n"
# save
rcon -m -H $IP -p $RCON_PORT -P $PASSWORD save
sleep 2


# backup
echo "[+] palworld backup data\n"
DDATE=`date "+%F-%T"`
mkdir $DDATE
cp -r $PALWORLD_HOME_PATH/Pal/Saved/SaveGames $DDATE/


#shutdown
echo "[+] palworld stop service\n"
rcon -m -H $IP -p $RCON_PORT -P $PASSWORD Shutdown
sleep 35
echo "[+] palworld stop service complete"

#restart
#$PALWORLD_SCRPIT_PATH &
' >> job.sh
}

generate_memcheck_file() {
    echo '[*] generate memcheck file'
    CURRENT_DIR=$(pwd)
    echo '#!/bin/bash

THRESHOLD=90

MEMORY_USAGE=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
DDATE=`date "+%F-%T"`
if (( $(echo "$MEMORY_USAGE > $THRESHOLD" | bc -l) )); then
    echo $DDATE
    echo "Memory usage is above $THRESHOLD%. Running clean command."
    ' > memcheck.sh

    cat <<EOF >> memcheck.sh
    $CURRENT_DIR/job.sh
EOF
    echo '
else
    echo "Memory usage is below $THRESHOLD%. No action required."
fi ' >> memcheck.sh
}

generate_default_palworld_config(){
    echo '[/Script/Pal.PalGameWorldSettings]
OptionSettings=(Difficulty=None,DayTimeSpeedRate=1.000000,NightTimeSpeedRate=1.000000,ExpRate=1.000000,PalCaptureRate=1.000000,PalSpawnNumRate=1.000000,PalDamageRateAttack=1.000000,PalDamageRateDefense=1.000000,PlayerDamageRateAttack=1.000000,PlayerDamageRateDefense=1.000000,PlayerStomachDecreaceRate=1.000000,PlayerStaminaDecreaceRate=1.000000,PlayerAutoHPRegeneRate=1.000000,PlayerAutoHpRegeneRateInSleep=1.000000,PalStomachDecreaceRate=1.000000,PalStaminaDecreaceRate=1.000000,PalAutoHPRegeneRate=1.000000,PalAutoHpRegeneRateInSleep=1.000000,BuildObjectDamageRate=1.000000,BuildObjectDeteriorationDamageRate=1.000000,CollectionDropRate=1.000000,CollectionObjectHpRate=1.000000,CollectionObjectRespawnSpeedRate=1.000000,EnemyDropItemRate=1.000000,DeathPenalty=All,bEnablePlayerToPlayerDamage=False,bEnableFriendlyFire=False,bEnableInvaderEnemy=True,bActiveUNKO=False,bEnableAimAssistPad=True,bEnableAimAssistKeyboard=False,DropItemMaxNum=3000,DropItemMaxNum_UNKO=100,BaseCampMaxNum=128,BaseCampWorkerMaxNum=15,DropItemAliveMaxHours=1.000000,bAutoResetGuildNoOnlinePlayers=False,AutoResetGuildTimeNoOnlinePlayers=72.000000,GuildPlayerMaxNum=20,PalEggDefaultHatchingTime=72.000000,WorkSpeedRate=1.000000,bIsMultiplay=False,bIsPvP=False,bCanPickupOtherGuildDeathPenaltyDrop=False,bEnableNonLoginPenalty=True,bEnableFastTravel=True,bIsStartLocationSelectByMap=True,bExistPlayerAfterLogout=False,bEnableDefenseOtherGuildPlayer=False,CoopPlayerMaxNum=32,ServerPlayerMaxNum=32,ServerName="default server",ServerDescription="",AdminPassword="huahuaisadog",ServerPassword="",PublicPort=8211,PublicIP="",RCONEnabled=True,RCONPort=25575,Region="",bUseAuth=True,BanListURL="https://api.palworldgame.com/api/banlist.txt")' > PalWorldSettings.ini
}

generate_systemd_control_file() {
    cat <<EOF > palserver.service
[Unit]
Description=Palworld Server
After=network.target

[Service]
Type=simple
User=$PALWORLD_USER
ExecStart=$PALWORLD_SCRPIT_PATH -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
echo "[+] generate palserver.service success"
}


search_palworld() {
    SEARCH_DIR="/home"

    FILE_NAME="PalServer.sh"

    TARGET=$(find "$SEARCH_DIR" -type f -name "$FILE_NAME")

    if [ -n "$TARGET" ]; then
        echo "[+] found: $TARGET"
        PALWORLD_SCRPIT_PATH=$TARGET
        return 1
    else
        return 0
    fi
}

setup_palworld_rcon() {
    echo "[!] we will overwrite the palserver config file to support rcon"
    echo "[!] notice: this action will shutdown your Palserver"
    echo "[!] notice: this action will change your current server config. please confirm[y/n]: "
    read CONFIRM
    if [ "$CONFIRM" != "y" ]; then
        exit 1
    fi

    PASSWORD=$(grep -oP '(?<=AdminPassword=").*?(?=",)' $PALWORLD_CONFIG_FILE)
    if [ -z "$PASSWORD" ]; then
        echo "[*] please set the admin password of your Palserver: "
        read USER_PASSWORD

        if [ -z "$USER_PASSWORD" ]; then
            echo "[-] error: admin password is none , exit"
            exit 1
        fi

        PASSWORD=$USER_PASSWORD
    fi


    echo "[+] your Palserver admin password is '$PASSWORD'"

    # shutdown Pal server



    # backup current config file
    PALWORLD_CONFIG_FILE=$PALWORLD_HOME_PATH/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini
    BACKUP_CONFIG_FILE=$PALWORLD_CONFIG_FILE.bk
    cp $PALWORLD_CONFIG_FILE $BACKUP_CONFIG_FILE
    echo "[+] backup palserver config file backup to : '$BACKUP_CONFIG_FILE'"


    # change config file
    echo "[*] change palserver config file"
    sed -i "s/AdminPassword=\"\",/AdminPassword=\"$PASSWORD\",/g" $PALWORLD_CONFIG_FILE

    sed -i "s/RCONEnabled=False,/RCONEnabled=True,/g" $PALWORLD_CONFIG_FILE
    echo "[+] setup palworld rcon success"
}

install_palserver_service(){
    generate_systemd_control_file
    echo "[*] install palserver.service to systemd "
    sudo cp palserver.service /etc/systemd/system/
    echo "[*] start palserver service"
    sudo systemctl start palserver

    echo "[+] start palserver service success, now enjoy your game"
}


check_palworld_rcon() {
    echo "[*] check if palworld rcon enabled"
    PALWORLD_CONFIG_FILE=$PALWORLD_HOME_PATH/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini

    if [ ! -f "$PALWORLD_CONFIG_FILE" ]; then
        echo "[-] file does not exist: $PALWORLD_CONFIG_FILE"
        exit 1
    fi

    if ! grep -q 'RCONEnabled' "$PALWORLD_CONFIG_FILE"; then
        echo "[-] error: current palserver use default PalWorldSettings.ini"
        return 2
    fi

    # search 'RCONEnabled=True'
    if ! grep -q 'RCONEnabled=True' "$PALWORLD_CONFIG_FILE"; then
        echo "[-] error: current palserver does not support rcon control"
        return 0
    else
        echo "[+] current palserver supports rcon control! we will get the AdminPassword and rcon port"
        PASSWORD=$(grep -oP '(?<=AdminPassword=").*?(?=",)' $PALWORLD_CONFIG_FILE)
        RCON_PORT=$(grep -oP '(?<=RCONPort=).*?(?=,)' $PALWORLD_CONFIG_FILE)
        
        if [ -z "$PASSWORD" ]; then
            echo "[-] error: AdminPassword is none "
            return 0
        fi

        echo "[+] get palserver admin password: $PASSWORD"
        echo "[+] get palserver rcon port: $RCON_PORT"
        return 1
    fi
}

enviroment_check(){
    # check if palworld running
    if ps aux | grep -v grep | grep "PalServer.shss" > /dev/null; then
        echo "[-] PalServer is runnig ,please shutdown it and then run this script again!"
        echo "[!] NOTICE: if your palserver is started by systemctl or supervisor, please stop and remove the service, too. "
        exit 1
    else
        echo "[+] Palserver process check success "
    fi


    # check PALWORLD_HOME_PATH
    if [ ! -d "$PALWORLD_HOME_PATH" ]; then
        echo "[-] '$PALWORLD_HOME_PATH' is not exist"
        echo "[*] try to find the path of Palworld server"
        search_palworld
        result=$?
        if [ $result -eq 1 ]; then
            echo "[+] found palserver script: '$PALWORLD_SCRPIT_PATH'"
            PALWORLD_HOME_PATH=$(dirname "$PALWORLD_SCRPIT_PATH")
            echo "[+] palworld home path: '$PALWORLD_HOME_PATH'"
        else
            echo "[-] palserver is not installed in this system, please install it first"
            exit 1
        fi
    fi


    # check if RCON enabled
    check_palworld_rcon
    result=$?
    if [ $result -eq 2 ]; then
        echo "[-] palworld rcon control is not supported : user is using the default config"
        # The user uses default setting, just copy our default one
        echo "[*] copy our default config to the user"
        generate_default_palworld_config
        cp PalWorldSettings.ini $PALWORLD_CONFIG_FILE
        echo "[+] copy our default config file success"
    elif [ $result -eq 0 ]; then
        # rcon disabled or password is none
        echo "[-] palworld rcon control is not supported : user disabled it or admin password has not been set."
        setup_palworld_rcon
    else
        echo "[+] palworld rcon support , continue"
    fi
}


enviroment_check
generate_job_file
generate_memcheck_file
install_cron_file
install_palserver_service
echo "[+] crontab job installed success, PalWorld server would be started in 2 minutes"
echo "[+] Palworld server memory monitor setup success !"
