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

# create shadowsocks config file...
echo $(date): create kcptun config file...
cat > /koolshare/ss/kcptun/ss.json <<EOF
{
    "server":"$server_ip",
    "server_port":$ss_basic_port,
    "redir_port": 1089,
    "socks5_port":23456,
    "password":"$ss_basic_password",
    "mode":"fast2",
    "sndwnd":$ss_basic_sndwnd,
    "rcvwnd":$ss_basic_rcvwnd,
    "mtu":$ss_basic_mtu,
    "_comment": {
	"redir_port": "Transparent proxy port for router"
    }
}

EOF

kill kcp_router || true
sleep 1
start-stop-daemon -m -p /var/run/kcp_client.pid -S  -x /koolshare/bin/kcp_router -b -- -c /koolshare/ss/kcptun/ss.json

echo $(date): Starting DNS2SOCKS..
dns2socks 127.0.0.1:23456 "$ss_redchn_dns2socks_user" 127.0.0.1:1053 > /dev/null 2>&1 &
echo $(date): done
echo $(date):

echo $(date): done
echo $(date):

echo $(date): "Apply nat rules!"
sh /koolshare/ss/redchn/nat-start
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
if [ ! -f "/koolshare/init.d/S50ss.sh" ]; then
cd /koolshare/init.d && ln -sf /koolshare/ss/ss_start.sh S50ss.sh
fi

echo $(date): -------------------- Shadowsock CHN mode Started-------------------------

