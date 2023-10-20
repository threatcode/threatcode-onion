#!/bin/bash
#


# if this script isn't already running
if [[ ! "`pidof -x $(basename $0) -o %PPID`" ]]; then

    CHECKIT=$(grep "Thread 0" /var/log/stenographer/stenographer.log |tac |head -2|wc -l)
    STENOGREP=$(grep "Thread 0" /var/log/stenographer/stenographer.log |tac |head -2)

    declare RESULT=($STENOGREP)

    CURRENT_PACKETS=$(echo ${RESULT[9]} | awk -F'=' '{print $2 }')
    CURRENT_DROPS=$(echo ${RESULT[12]} | awk -F'=' '{print $2 }')
    PREVIOUS_PACKETS=$(echo ${RESULT[23]} | awk -F'=' '{print $2 }')
    PREVIOUS_DROPS=$(echo ${RESULT[26]} | awk -F'=' '{print $2 }')

    DROPPED=$((CURRENT_DROPS - PREVIOUS_DROPS))
    TOTAL_CURRENT=$((CURRENT_PACKETS + CURRENT_DROPS))
    TOTAL_PAST=$((PREVIOUS_PACKETS + PREVIOUS_DROPS))
    TOTAL=$((TOTAL_CURRENT - TOTAL_PAST))

    if [ $CHECKIT == 2 ]; then
      if [ $DROPPED == 0 ]; then
        echo "stenodrop drop=$DROPPED"
      else
        LOSS=$(echo "4 k $DROPPED $TOTAL / 100 * p" | dc)
        echo "stenodrop drop=$LOSS"
      fi
    fi

fi

exit 0
