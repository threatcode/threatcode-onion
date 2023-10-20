#!/bin/bash
#


# if this script isn't already running
if [[ ! "`pidof -x $(basename $0) -o %PPID`" ]]; then

    # Get the data
    OLDPCAP=$(find /host/nsm/pcap -type f -exec stat -c'%n %Z' {} + | sort | grep -v "\." | head -n 1 | awk {'print $2'})
    DATE=$(date +%s)
    AGE=$(($DATE - $OLDPCAP))

    echo "pcapage seconds=$AGE"

fi

exit 0
