#!/bin/bash
#


# if this script isn't already running
if [[ ! "`pidof -x $(basename $0) -o %PPID`" ]]; then

    INFLUXLOG=/var/log/telegraf/influxdb_size.log
 
    if [ -f "$INFLUXLOG" ]; then
        INFLUXSTATUS=$(cat $INFLUXLOG)
        echo "influxsize kbytes=$INFLUXSTATUS"
    fi
fi

exit 0
