#!/bin/sh

source /koolshare/scripts/base.sh
ss_basic_mode=`dbus get ss_basic_mode`
LOG=/tmp/info/ss.log

/koolshare/ss/stop.sh > $LOG
if [ "$ss_basic_mode" = "1" ]; then 
/koolshare/ss/ipset/start.sh >> $LOG
elif [ "$ss_basic_mode" = "2" ]; then
/koolshare/ss/redchn/start.sh >> $LOG
elif [ "$ss_basic_mode" = "3" ]; then
/koolshare/ss/game/start.sh >> $LOG
fi

http_response "postend"
