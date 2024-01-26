# PalworldServerTools
Tools for palworld dedicated server.

# Features:
1. Check the memory usage of the mechine every 2 miniutes. If memory usage is above 90%, do the memory clean job below:
2. Will use RCON protocol supported by PalWorld to restart the palwolrd server safely with data saving and backup. NO DATA WOULD BE LOST.
3. Will notice players in gaming to logout and restart the palworld server.
4. Make your palworld server controled by systemd. Won't worry the server interruption anymore.
5. Todo: Automating update Palworld server.

## usage
1. Shutdown your palworld server. If you run it with systemd or supervisor, remove it.
2. Just run the setup.sh script
```shell
chmod +x setup.sh
./setup.sh
```

## notice
* This tool would change your PalworldSetting file to set an AdminPassword and enable RCON.
* This tool would write a file to /etc/systemd/system/ to create a server to make Palworld server alive.
* This tool would write a file to /etc/cron.d/ to create a cron job to monitor memory and do the clean job.
* This tool would wirte a file to /usr/bin/ to install a RCON client.
