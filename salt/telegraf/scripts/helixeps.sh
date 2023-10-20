#!/bin/bash
#


# if this script isn't already running
if [[ ! "`pidof -x $(basename $0) -o %PPID`" ]]; then

  PREVCOUNTFILE='/tmp/helixevents.txt'
  EVENTCOUNTCURRENT="$(curl -s localhost:9600/_node/stats | jq '.pipelines.helix.events.out')"

  if [ ! -z "$EVENTCOUNTCURRENT" ]; then

    if [ -f "$PREVCOUNTFILE" ]; then
      EVENTCOUNTPREVIOUS=`cat $PREVCOUNTFILE`
    else
      echo "${EVENTCOUNTCURRENT}" > $PREVCOUNTFILE
      exit 0
    fi

    echo "${EVENTCOUNTCURRENT}" > $PREVCOUNTFILE
    EVENTS=$(((EVENTCOUNTCURRENT - EVENTCOUNTPREVIOUS)/30))
    if [ "$EVENTS" -lt 0 ]; then
      EVENTS=0
    fi

    echo "helixeps eps=${EVENTS%%.*}"
  fi

fi

exit 0
