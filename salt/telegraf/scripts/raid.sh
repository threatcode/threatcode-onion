#!/bin/bash
#


# if this script isn't already running
if [[ ! "`pidof -x $(basename $0) -o %PPID`" ]]; then

    RAIDLOG=/var/log/raid/status.log
    RAIDSTATUS=$(cat /var/log/raid/status.log)

    if [ -f "$RAIDLOG" ]; then
        echo "raid $RAIDSTATUS"
    else
        exit 0
    fi

fi

exit 0
