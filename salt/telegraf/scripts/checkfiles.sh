#!/bin/bash
#


# if this script isn't already running
if [[ ! "`pidof -x $(basename $0) -o %PPID`" ]]; then

    FILES=$(ls -1x /host/nsm/strelka/unprocessed | wc -l)
    echo "faffiles files=$FILES"
    
fi

exit 0
