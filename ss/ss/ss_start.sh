#!/bin/sh

source /koolshare/scripts/base.sh
ss_basic_mode=`dbus get ss_basic_mode`
LOG=/tmp/info/ss.log

case $ACTION in
start)

	if [ "$ss_basic_mode" = "1" ]; then 
		/koolshare/ss/ipset/start.sh >> $LOG
	elif [ "$ss_basic_mode" = "2" ]; then
		/koolshare/ss/redchn/start.sh >> $LOG
	elif [ "$ss_basic_mode" = "3" ]; then
		/koolshare/ss/game/start.sh >> $LOG
	fi

	;;
stop)
	/koolshare/ss/stop.sh > $LOG
	;;
*)
	echo "Usage: $0 (start)"
	exit 1
	;;
esac

