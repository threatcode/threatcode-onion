#!/bin/bash
#


# if this script isn't already running
if [[ ! "`pidof -x $(basename $0) -o %PPID`" ]]; then

    SOSTATUSLOG=/var/log/tcstatus/status.log
    SOSTATUSSTATUS=$(cat /var/log/tcstatus/status.log)

    if [ -f "$SOSTATUSLOG" ]; then
        echo "tcstatus status=$SOSTATUSSTATUS"
    else
        exit 0
    fi

fi

exit 0
