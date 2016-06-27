#!/bin/sh

source /koolshare/scripts/base.sh
eval `dbus export ss`
ssredir=`pidof ss-redir`
sstunnel=`pidof ss-tunnel`
sslocal=`pidof ss-local`
rssredir=`pidof rss-redir`
rsstunnel=`pidof rss-tunnel`
rsslocal=`pidof rss-local`
DNS2SOCK=`pidof dns2socks`
pcapdns=`pidof pcapdns`
kcprouter=`pidof kcprouter`
lan_ipaddr=$(nvram get lan_ipaddr)
ip_rule_exist=`ip rule show | grep "fwmark 0x1 lookup 100" | grep -c 100`

case $(uname -m) in
  armv7l)
    MATCH_SET='--match-set'
    ;;
  mips)
    MATCH_SET='--set'
    ;;
esac

echo $(date): ================= Shell by sadoneli, Web by Xiaobao =====================
echo $(date):
echo $(date): --------------------Stopping Shadowsock service--------------------------

#--------------------------------------------------------------------------		
# dectect disable or switching mode
if [ "$ss_basic_mode" == "0" ];then
	echo $(date): Shadowsocks service will be disabled !!
else 
	echo $(date): Stopping last mode !
fi
echo $(date):

echo $(date): flush iptables and destory chain...
ip route del local 0.0.0.0/0 dev lo table 100  >/dev/null 2>&1
iptables -t mangle -D PREROUTING -j SHADOWSOCKS2 >/dev/null 2>&1
iptables -t mangle -D PREROUTING -p udp -j SHADOWSOCKS2 >/dev/null 2>&1
iptables -t mangle -D PREROUTING -p tcp -j SHADOWSOCKS2 >/dev/null 2>&1
iptables -t mangle -F SHADOWSOCKS2 >/dev/null 2>&1
iptables -t mangle -X SHADOWSOCKS2 >/dev/null 2>&1
if [ ! -z "ip_rule_exist" ];then
	until [ "$ip_rule_exist" = 0 ]
	do 
		ip rule del fwmark 0x01 table 100
		ip_rule_exist=`expr $ip_rule_exist - 1`
	done
fi

echo $(date): done
echo $(date):

echo $(date): flush and destory ipset
ipset -F gfwlist >/dev/null 2>&1
ipset -F router >/dev/null 2>&1
ipset -F chnroute >/dev/null 2>&1
ipset -X gfwlist >/dev/null 2>&1
ipset -X router >/dev/null 2>&1
ipset -X chnroute >/dev/null 2>&1
ipset -F white_domain >/dev/null 2>&1
ipset -F black_domain >/dev/null 2>&1
ipset -X white_domain >/dev/null 2>&1
ipset -X black_domain >/dev/null 2>&1
echo $(date): done
echo $(date):


if [ ! -z "$ssredir" ]; then 
	echo $(date): kill ss-redir...
	kill $ssredir || true
	echo $(date): done
	echo $(date):
fi

if [ ! -z "$sslocal" ]; then
	echo $(date): kill ss-local...
	kill $sslocal || true
	echo $(date): done
	echo $(date):
fi

if [ ! -z "$sstunnel" ]; then 
	echo $(date): kill ss-tunnel...
	kill $sstunnel | true
	echo $(date): done
	echo $(date):
fi

if [ ! -z "$rssredir" ]; then 
	echo $(date): kill rss-redir...
	kill $rssredir || true
	echo $(date): done
	echo $(date):
fi

if [ ! -z "$rsslocal" ]; then
	echo $(date): kill rss-local...
	kill $rsslocal || true
	echo $(date): done
	echo $(date):
fi

if [ ! -z "$rsstunnel" ]; then 
	echo $(date): kill rss-tunnel...
	kill $rsstunnel | true
	echo $(date): done
	echo $(date):
fi

if [ ! -z "$DNS2SOCK" ]; then
	echo $(date): kill DNS2SOCK...
	kill $DNS2SOCK || true
	echo $(date): done
	echo $(date):
fi

if [ ! -z "$pcapdns" ]; then 
	echo $(date): kill Pcap_DNSProxy...
	perpctl X pcapdns
	sleep 1
	kill $pcapdns || true
	echo $(date): done
	echo $(date):
fi

if [ ! -z "$kcprouter" ]; then
	echo $(date): kill kcprouter
	kill $kcprouter || true
	echo $(date): done
	echo $(date):
fi

rm -rf /koolshare/configs/dnsmasq.d/gfwlist.conf

if [ "$ss_basic_mode" == "0" -o "$ss_basic_mode" == "" ]; then
rm -f /koolshare/init.d/S50ss.sh

cat > /koolshare/configs/dnsmasq.conf <<EOF
pid-file=/var/run/dnsmasq.pid
bind-dynamic
no-poll
no-negcache
cache-size=9999
min-port=4096
bogus-priv
conf-dir=/koolshare/configs/dnsmasq.d

EOF

#in other state, we restart dnsmasq later
kill `pidof dnsmasq` || true
sleep 1

echo $(date): Bring up dnsmasq service
dnsmasq -h -n -c 0 -N -i br0 -r /tmp/resolv.conf -u r -a 0.0.0.0
echo $(date): done
echo $(date):
fi

dbus remove ss_basic_state_china
dbus remove ss_basic_state_foreign

