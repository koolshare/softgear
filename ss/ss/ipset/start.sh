#!/bin/sh

eval `dbus export ss`
source /koolshare/scripts/base.sh

ISP_DNS=$(nvram get wan_dns|sed 's/ /\n/g'|grep -v 0.0.0.0|grep -v 127.0.0.1|sed -n 1p)
lan_ipaddr=$(nvram get lan_ipaddr)
server_ip=`resolvip $ss_basic_server|sed -n 1p`
wanwhitedomain=$(echo $ss_ipset_white_domain_web | sed 's/,/\n/g')

#--------------------------------------------------------------------------------------
echo $(date): ----------------- Shadowsock gfwlist mode Starting-----------------------

if [ "$server_ip" == "" ]; then
server_ip=$ss_basic_server
fi

# create shadowsocks config file...
echo $(date): create shadowsocks config file...
if [ "$ss_basic_use_rss" == "0" ];then
cat > /koolshare/ss/ipset/ss.json <<EOF
{
    "server":"$server_ip",
    "server_port":$ss_basic_port,
    "local_port":3333,
    "password":"$ss_basic_password",
    "timeout":600,
    "method":"$ss_basic_method"
}

EOF
elif [ "$ss_basic_use_rss" == "1" ];then
cat > /koolshare/ss/ipset/ss.json <<EOF
{
    "server":"$ss_basic_server",
    "server_port":$ss_basic_port,
    "local_port":3333,
    "password":"$ss_basic_password",
    "timeout":600,
    "protocol":"$ss_basic_rss_protocol",
    "obfs":"$ss_basic_rss_obfs",
    "method":"$ss_basic_method"
}

EOF
fi

dns="$ISP_DNS"
[ "$ss_ipset_cdn_dns" == "1" ] && [ ! -z "$ISP_DNS" ] && dns="$ISP_DNS"
[ "$ss_ipset_cdn_dns" == "1" ] && [ -z "$ISP_DNS" ] && dns="114.114.114.114"
[ "$ss_ipset_cdn_dns" == "2" ] && dns="223.5.5.5"
[ "$ss_ipset_cdn_dns" == "3" ] && dns="223.6.6.6"
[ "$ss_ipset_cdn_dns" == "4" ] && dns="114.114.114.114"
[ "$ss_ipset_cdn_dns" == "5" ] && dns="$ss_ipset_cdn_dns_user"
[ "$ss_ipset_cdn_dns" == "6" ] && dns="180.76.76.76"
[ "$ss_ipset_cdn_dns" == "7" ] && dns="1.2.4.8"
[ "$ss_ipset_cdn_dns" == "8" ] && dns="119.29.29.29"

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
server=$dns

EOF

# append domain white list
if [ ! -z $ss_ipset_white_domain_web ];then
	echo $(date): append white_domain
	echo "#for white_domain" >> /koolshare/configs/dnsmasq.conf
	for wan_white_domain in $wanwhitedomain
	do
		echo "$wan_white_domain" | sed "s/,/\n/g" | sed "s/^/server=&\/./g" | sed "s/$/\/127.0.0.1#1053/g" >> /koolsahre/configs/dnsmasq.conf
		echo "$wan_white_domain" | sed "s/,/\n/g" | sed "s/^/ipset=&\/./g" | sed "s/$/\/white_domain/g" >> /koolshare/configs/dnsmasq.conf
	done
	echo $(date): done
	echo $(date):
fi


# append gfwlist
if [ ! -f /koolshare/configs/dnsmasq.d/gfwlist.conf ];then
	echo $(date): creat gfwlist conf to dnsmasq.conf
	ln -sf /koolshare/ss/ipset/gfwlist.conf /koolshare/configs/dnsmasq.d/gfwlist.conf
	echo $(date): done
	echo $(date):
fi

# append custom input domain
if [ ! -z "$ss_ipset_black_domain_web" ];then
	echo $(date): append custom black domain into dnsmasq.conf
	echo "$ss_ipset_black_domain_web" | sed "s/,/\n/g" | sed "s/^/server=&\/./g" | sed "s/$/\/127.0.0.1#1053/g" >> /tmp/custom.conf
	echo "$ss_ipset_black_domain_web" | sed "s/,/\n/g" | sed "s/^/ipset=&\/./g" | sed "s/$/\/gfwlist/g" >> /tmp/custom.conf
	echo $(date): done
	echo $(date):
fi

# append custom host
if [ ! -z "$ss_ipset_dnsmasq" ];then
	echo $(date): append custom host into dnsmasq.conf
	echo "$ss_ipset_dnsmasq" | sed "s/,/\n/g" | sort -u >> /tmp/custom.conf
	echo $(date): done
	echo $(date):
fi

# append dnsmasq.conf
if [ -f /tmp/custom.conf ];then
	echo $(date): append dnsmasq.conf.add..
	mv /tmp/custom.conf  /koolshare/configs/dnsmasq.d
	echo $(date): done
	echo $(date):
fi

# TODO natstat/wanstart


[ "$ss_ipset_tunnel" == "1" ] && it="208.67.220.220:53"
[ "$ss_ipset_tunnel" == "2" ] && it="8.8.8.8:53"
[ "$ss_ipset_tunnel" == "3" ] && it="8.8.4.4:53"
[ "$ss_ipset_tunnel" == "4" ] && it="$ss_ipset_tunnel_user"

if [ "$ss_ipset_foreign_dns" == "1" ]; then
	echo $(date): Starting ss-tunnel...
	if [ "$ss_basic_use_rss" == "1" ];then
		rss-tunnel -b 0.0.0.0 -c /koolshare/ss/ipset/ss.json -l 1053 -L "$it" -u -f /var/run/sstunnel.pid >/dev/null 2>&1
	elif  [ "$ss_basic_use_rss" == "0" ];then
		if [ "$ss_basic_onetime_auth" == "1" ];then
			ss-tunnel -b 0.0.0.0 -c /koolshare/ss/ipset/ss.json -l 1053 -L "$it" -u -A -f /var/run/sstunnel.pid
		elif [ "$ss_basic_onetime_auth" == "0" ];then
			ss-tunnel -b 0.0.0.0 -c /koolshare/ss/ipset/ss.json -l 1053 -L "$it" -u -f /var/run/sstunnel.pid
		fi
	fi
	echo $(date): done
	echo $(date):
fi

# Start DNS2SOCKS
if [ "$ss_ipset_foreign_dns" == "2" ]; then
	echo $(date): Socks5 enable on port 23456 \for DNS2SOCKS..
	if [ "$ss_basic_use_rss" == "1" ];then
		rss-local -b 0.0.0.0 -l 23456 -c /koolshare/ss/ipset/ss.json -u -f /var/run/sslocal1.pid >/dev/null 2>&1
	elif  [ "$ss_basic_use_rss" == "0" ];then
		if [ "$ss_basic_onetime_auth" == "1" ];then
			ss-local -b 0.0.0.0 -l 23456 -A -c /koolshare/ss/ipset/ss.json -u -f /var/run/sslocal1.pid
		elif [ "$ss_basic_onetime_auth" == "0" ];then
			ss-local -b 0.0.0.0 -l 23456 -c /koolshare/ss/ipset/ss.json -u -f /var/run/sslocal1.pid
		fi
	fi
		dns2socks 127.0.0.1:23456 "$ss_ipset_dns2socks_user" 127.0.0.1:1053 > /dev/null 2>&1 &
	echo $(date): done
	echo $(date):
fi


# Start Pcap_DNSProxy
if [ "$ss_ipset_foreign_dns" == "3" ]; then
	if pidof pcapdns > /dev/null; then
		kill -9 `pidof pcapdns`
	fi
	echo $(date): Start Pcap_DNSProxy..
	sed -i '/^Listen Port/c Listen Port = 1053' /koolshare/ss/dns/Config.conf
	sed -i '/^Local Main/c Local Main = 0' /koolshare/ss/dns/Config.conf
	perpctl A pcapdns
	echo $(date): done
	echo $(date):
fi


# Start ss-redir
echo $(date): Starting ss-redir...
if [ "$ss_basic_use_rss" == "1" ];then
	rss-redir -b 0.0.0.0 -c /koolshare/ss/ipset/ss.json -f /var/run/shadowsocks.pid >/dev/null 2>&1
elif  [ "$ss_basic_use_rss" == "0" ];then
	if [ "$ss_basic_onetime_auth" == "1" ];then
		ss-redir -b 0.0.0.0 -A -c /koolshare/ss/ipset/ss.json -f /var/run/shadowsocks.pid
	elif [ "$ss_basic_onetime_auth" == "0" ];then
		ss-redir -b 0.0.0.0 -c /koolshare/ss/ipset/ss.json -f /var/run/shadowsocks.pid
	fi
fi
echo $(date): done
echo $(date):

echo $(date): "Apply nat rules!"
sh /koolshare/ss/ipset/nat-start
echo $(date): done
echo $(date):


# Restart dnsmasq
kill `pidof dnsmasq` || true
sleep 1

echo $(date): Bring up dnsmasq service
dnsmasq -h -n -c 0 -N -i br0
echo $(date): done
echo $(date):

#Auto start
if [ ! -f "/koolshare/init.d/S50ss.sh" ]; then
cd /koolshare/init.d && ln -sf /koolshare/ss/ss_start.sh S50ss.sh
fi

echo $(date): ------------------ Shadowsock gfwlist mode Started-----------------------
