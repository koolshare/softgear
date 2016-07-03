#!/bin/sh

source /koolshare/scripts/base.sh
ss_basic_mode=`dbus get ss_basic_mode`
LOG=/tmp/info/ss.log

if [ "$2" == "1" ]; then
#udpate command
cd /tmp/
rm -f ss.tar.gz
wget http://netgear.ngrok.wang:5000/ss/ss.tar.gz >> $LOG
tar -zxf ss.tar.gz
sh /tmp/ss/install.sh
rm -f ss.tar.gz
rm -rf /tmp/ss
ss_install_version=`dbus get ss_install_version`
dbus set ss_version=$ss_install_version
fi

/koolshare/ss/stop.sh > $LOG
if [ "$ss_basic_mode" = "1" ]; then 
/koolshare/ss/ipset/start.sh >> $LOG
elif [ "$ss_basic_mode" = "2" ]; then
/koolshare/ss/redchn/start.sh >> $LOG
elif [ "$ss_basic_mode" = "3" ]; then
/koolshare/ss/game/start.sh >> $LOG
fi

http_response "postend"
