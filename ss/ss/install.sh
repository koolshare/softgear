#!/bin/sh

chmod 755 /tmp/ss/bin/*
chmod 755 /tmp/ss/scripts/*
chmod 755 /tmp/ss/ipset/*
chmod 755 /tmp/ss/redchn/*
chmod 755 /tmp/ss/game/*

cp /tmp/ss/bin/* /koolshare/bin/
cp /tmp/ss/scripts/* /koolshare/scripts/
cp /tmp/ss/webs/* /koolshare/webs/

mkdir -p /koolshare/ss
cp /tmp/ss/ss_start.sh /koolshare/ss/
cp /tmp/ss/stop.sh /koolshare/ss/
cp -rf /tmp/ss/ipset /koolshare/ss/
cp -rf /tmp/ss/redchn /koolshare/ss/
cp -rf /tmp/ss/game /koolshare/ss/
cp -rf /tmp/ss/dns /koolshare/ss/
cp -rf /tmp/ss/dw /koolshare/ss/

if [ ! -f "/koolshare/init.d/S50ss.sh" ]; then
cd /koolshare/init.d && ln -sf /koolshare/ss/ss_start.sh S50ss.sh
fi

cd /
rm -f ss.tar.gz
rm -rf /tmp/ss

