#!/bin/bash
#


# if this script isn't already running
if [[ ! "`pidof -x $(basename $0) -o %PPID`" ]]; then

    UNPARSED=$(redis-cli llen logstash:unparsed | awk '{print $1}')
    PARSED=$(redis-cli llen logstash:parsed | awk '{print $1}')

    echo "redisqueue unparsed=$UNPARSED,parsed=$PARSED"

fi

exit 0
