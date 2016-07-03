#!/bin/sh
#--------------------------------------------------------------------------------------
# Variable definitions
eval `dbus export ss`
source /koolshare/scripts/base.sh
ISP_DNS=$(nvram get wan_dns|sed 's/ /\n/g'|grep -v 0.0.0.0|grep -v 127.0.0.1|sed -n 1p)
lan_ipaddr=$(nvram get lan_ipaddr)
server_ip=`resolvip $ss_basic_server`
wanwhitedomain=$(echo $ss_redchn_wan_white_domain | sed 's/,/\n/g')
wanblackdomain=$(echo $ss_redchn_wan_black_domain | sed "s/,/\n/g")
custom_dnsmasq=$(echo $ss_redchn_dnsmasq | sed "s/,/\n/g")

#--------------------------------------------------------------------------------------
echo $(date): ------------------- Shadowsock CHN mode Starting-------------------------

if [ "$server_ip" == "" ]; then
server_ip=$ss_basic_server
fi

# create shadowsocks config file...
echo $(date): create shadowsocks config file...
if [ "$ss_basic_use_rss" == "0" ];then
cat > /koolshare/ss/redchn/ss.json <<EOF
{
    "server":"$server_ip",
    "server_port":$ss_basic_port,
    "local_port":1089,
    "password":"$ss_basic_password",
    "timeout":600,
    "method":"$ss_basic_method"
}

EOF
elif [ "$ss_basic_use_rss" == "1" ];then
cat > /koolshare/ss/redchn/ss.json <<EOF
{
    "server":"$server_ip",
    "server_port":$ss_basic_port,
    "local_port":1089,
    "password":"$ss_basic_password",
    "timeout":600,
    "protocol":"$ss_basic_rss_protocol",
    "obfs":"$ss_basic_rss_obfs",
    "method":"$ss_basic_method"
}

EOF
fi
echo $(date): done
echo $(date):

CDN="$ISP_DNS"
[ "$ss_redchn_dns_china" == "1" ] && [ ! -z "$ISP_DNS" ] && CDN="$ISP_DNS"
[ "$ss_redchn_dns_china" == "1" ] && [ -z "$ISP_DNS" ] && CDN="114.114.114.114"
[ "$ss_redchn_dns_china" == "2" ] && CDN="223.5.5.5"
[ "$ss_redchn_dns_china" == "3" ] && CDN="223.6.6.6"
[ "$ss_redchn_dns_china" == "4" ] && CDN="114.114.114.114"
[ "$ss_redchn_dns_china" == "5" ] && CDN="$ss_redchn_dns_china_user"
[ "$ss_redchn_dns_china" == "6" ] && CDN="180.76.76.76"
[ "$ss_redchn_dns_china" == "7" ] && CDN="1.2.4.8"
[ "$ss_redchn_dns_china" == "8" ] && CDN="119.29.29.29"

cat > /koolshare/configs/dnsmasq.conf <<EOF
pid-file=/var/run/dnsmasq.pid
listen-address=0.0.0.0
bind-dynamic
no-poll
no-negcache
cache-size=9999
min-port=4096
bogus-priv
conf-dir=/koolshare/configs/dnsmasq.d
no-resolv
server=127.0.0.1#1053

EOF

# append domain white list
if [ ! -z $ss_redchn_wan_white_domain ];then
	echo $(date): append white_domain
	echo "#for white_domain" >> /koolshare/configs/dnsmasq.conf
	for wan_white_domain in $wanwhitedomain
	do 
		echo "$wan_white_domain" | sed "s/,/\n/g" | sed "s/^/server=&\/./g" | sed "s/$/\/127.0.0.1#1053/g" >> /koolshare/configs/dnsmasq.conf
		echo "$wan_white_domain" | sed "s/,/\n/g" | sed "s/^/ipset=&\/./g" | sed "s/$/\/white_domain/g" >> /koolshare/configs/dnsmasq.conf
	done
	echo $(date): done
	echo $(date):
fi

# append domain black list
if [ ! -z $ss_redchn_wan_black_domain ];then
	echo $(date): append black_domain
	echo "#for black_domain" >> /koolshare/configs/dnsmasq.conf
	for wan_black_domain in $wanblackdomain
	do 
		echo "$wan_black_domain" | sed "s/,/\n/g" | sed "s/^/server=&\/./g" | sed "s/$/\/127.0.0.1#1053/g" >> /koolshare/configs/dnsmasq.conf
		echo "$wan_black_domain" | sed "s/,/\n/g" | sed "s/^/ipset=&\/./g" | sed "s/$/\/black_domain/g" >> /koolshare/configs/dnsmasq.conf
	done
	echo $(date): done
	echo $(date):
fi

# append coustom dnsmasq settings
if [ ! -z $ss_redchn_dnsmasq ];then
	echo $(date): append coustom dnsmasq settings
	echo "#for coustom dnsmasq settings" >> /koolshare/configs/dnsmasq.conf
	for line in $custom_dnsmasq
	do 
		echo "$line" >> /koolshare/configs/dnsmasq.conf
	done
	echo $(date): done
	echo $(date):
fi

# append china site
echo $(date): append CDN list into dnsmasq conf \file
echo "#for china site CDN acclerate" >> /koolshare/configs/dnsmasq.conf
cat /koolshare/ss/redchn/cdn.txt | sed "s/^/server=&\/./g" | sed "s/$/\/&$CDN/g" | sort | awk '{if ($0!=line) print;line=$0}' >> /koolshare/configs/dnsmasq.conf
echo $(date): done
echo $(date):

# append user defined china site
if [ ! -z "$ss_redchn_isp_website_web" ];then
	echo $(date): append user defined domian
	echo "#for user defined china site CDN acclerate" >> /koolshare/configs/dnsmasq.conf
	echo "$ss_redchn_isp_website_web" | sed "s/,/\n/g" | sed "s/^/server=&\/./g" | sed "s/$/\/&$CDN/g" >> /koolshare/configs/dnsmasq.conf
	echo $(date): done
	echo $(date):
fi

#=======================================================================================
# start setvice

# start ss-local on port 23456
echo $(date): Socks5 enable on port 23456 \for DNS2SOCKS..
if [ "$ss_basic_use_rss" == "1" ];then
	rss-local -b 0.0.0.0 -l 23456 -c /koolshare/ss/redchn/ss.json -u -f /var/run/sslocal1.pid >/dev/null 2>&1
elif  [ "$ss_basic_use_rss" == "0" ];then
	if [ "$ss_basic_onetime_auth" == "1" ];then
		ss-local -b 0.0.0.0 -l 23456 -A -c /koolshare/ss/redchn/ss.json -u -f /var/run/sslocal1.pid
	elif [ "$ss_basic_onetime_auth" == "0" ];then
		ss-local -b 0.0.0.0 -l 23456 -c /koolshare/ss/redchn/ss.json -u -f /var/run/sslocal1.pid
	fi
fi
echo $(date): done
echo $(date):

[ "$ss_redchn_sstunnel" == "1" ] && gs="208.67.220.220:53"
[ "$ss_redchn_sstunnel" == "2" ] && gs="8.8.8.8:53"
[ "$ss_redchn_sstunnel" == "3" ] && gs="8.8.4.4:53"
[ "$ss_redchn_sstunnel" == "4" ] && gs="$ss_redchn_sstunnel_user"


if [ "2" == "$ss_redchn_dns_foreign" ];then
	echo $(date): Starting ss-tunnel...
	if [ "$ss_basic_use_rss" == "1" ];then
		rss-tunnel -b 0.0.0.0 -c /koolshare/ss/redchn/ss.json -l 1053 -L "$gs" -u -f /var/run/sstunnel.pid
	elif  [ "$ss_basic_use_rss" == "0" ];then
		if [ "$ss_basic_onetime_auth" == "1" ];then
			ss-tunnel -b 0.0.0.0 -c /koolshare/ss/redchn/ss.json -l 1053 -L "$gs" -u -A -f /var/run/sstunnel.pid
		elif [ "$ss_basic_onetime_auth" == "0" ];then
			ss-tunnel -b 0.0.0.0 -c /koolshare/ss/redchn/ss.json -l 1053 -L "$gs" -u -f /var/run/sstunnel.pid
		fi
	fi
	echo $(date): done
	echo $(date):
fi

[ "$ss_redchn_chinadns_china" == "1" ] && rcc="223.5.5.5"
[ "$ss_redchn_chinadns_china" == "2" ] && rcc="223.6.6.6"
[ "$ss_redchn_chinadns_china" == "3" ] && rcc="114.114.114.114"
[ "$ss_redchn_chinadns_china" == "4" ] && rcc="$ss_redchn_chinadns_china_user"
[ "$ss_redchn_chinadns_foreign" == "1" ] && rdf="208.67.220.220:53"
[ "$ss_redchn_chinadns_foreign" == "2" ] && rdf="8.8.8.8:53"
[ "$ss_redchn_chinadns_foreign" == "3" ] && rdf="8.8.4.4:53"
[ "$ss_redchn_chinadns_foreign" == "4" ] && rdf="$ss_redchn_chinadns_foreign_user"

if [ "3" == "$ss_redchn_dns_foreign" ];then
	echo $(date): Starting chinadns
	if [ "$ss_basic_use_rss" == "1" ];then
		rss-tunnel -b 127.0.0.1 -c /koolshare/ss/redchn/ss.json -l 1055 -L "$rdf" -u -f /var/run/sstunnel.pid
	elif  [ "$ss_basic_use_rss" == "0" ];then
		if [ "$ss_basic_onetime_auth" == "1" ];then
			ss-tunnel -b 127.0.0.1 -c /koolshare/ss/redchn/ss.json -l 1055 -L "$rdf" -u -A -f /var/run/sstunnel.pid
		elif [ "$ss_basic_onetime_auth" == "0" ];then
			ss-tunnel -b 127.0.0.1 -c /koolshare/ss/redchn/ss.json -l 1055 -L "$rdf" -u -f /var/run/sstunnel.pid
		fi
	fi
	chinadns -p 1053 -s "$rcc",127.0.0.1:1055 -m -d -c /koolshare/ss/redchn/chnroute.txt  >/dev/null 2>&1 &
	echo $(date): done
	echo $(date):
fi

if [ "4" == "$ss_redchn_dns_foreign" ]; then
	echo $(date): Starting DNS2SOCKS..
	dns2socks 127.0.0.1:23456 "$ss_redchn_dns2socks_user" 127.0.0.1:1053 > /dev/null 2>&1 &
	echo $(date): done
	echo $(date):
fi

# Start Pcap_DNSProxy
if [ "5" == "$ss_redchn_dns_foreign"  ]; then
	if pidof pcapdns > /dev/null; then
		kill -9 `pidof pcapdns`
	fi

	echo $(date): Start Pcap_DNSProxy..
	sed -i '/^Listen Port/c Listen Port = 1053' /koolshare/ss/dns/Config.conf
	sed -i '/^Local Main/c Local Main = 0' /koolshare/ss/dns/Config.conf
	perp-restart pcapdns
	echo $(date): done
	echo $(date):
fi

# Start ss-redir
echo $(date): Starting ss-redir...
if [ "$ss_basic_use_rss" == "1" ];then
	rss-redir -b 0.0.0.0 -c /koolshare/ss/redchn/ss.json -f /var/run/shadowsocks.pid >/dev/null 2>&1
elif  [ "$ss_basic_use_rss" == "0" ];then
	if [ "$ss_basic_onetime_auth" == "1" ];then
		ss-redir -b 0.0.0.0 -A -c /koolshare/ss/redchn/ss.json -f /var/run/shadowsocks.pid
	elif [ "$ss_basic_onetime_auth" == "0" ];then
		ss-redir -b 0.0.0.0 -c /koolshare/ss/redchn/ss.json -f /var/run/shadowsocks.pid
	fi
fi
echo $(date): done
echo $(date):

echo $(date): "Apply nat rules!"
sh /koolshare/ss/game/nat-start
echo $(date): done
echo $(date):


# Restart dnsmasq
kill `pidof dnsmasq` || true
sleep 1

echo $(date): Bring up dnsmasq service
dnsmasq -h -n -c 0 -N -i br0 -C /koolshare/configs/dnsmasq.conf
echo $(date): done
echo $(date):

#Auto start
#Auto start
if [ ! -f "/koolshare/init.d/S50ss.sh" ]; then
cd /koolshare/init.d && ln -sf /koolshare/ss/ss_start.sh S50ss.sh
fi

echo $(date): -------------------- Shadowsock GAME mode Started-------------------------


