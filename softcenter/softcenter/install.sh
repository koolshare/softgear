#!/bin/sh

softcenter_install() {
	if [ -d "/tmp/softcenter" ]; then
		cp -rf /tmp/softcenter/webs/* /koolshare/webs
		mkdir -p /koolshare/webs/res
		cp -rf /tmp/softcenter/res/* /koolshare/webs/res/
		cp -rf /tmp/softcenter/scripts /koolshare/
		rm -rf /tmp/softcenter
		if [ ! -f "/koolshare/init.d/S10Softcenter.sh" ]; then
		ln -sf /koolshare/scripts/ks_app_install.sh /koolshare/init.d/S10Softcenter.sh
		fi
		if [ ! -f "/koolshare/init.d/S10Softcenter.sh" ]; then
		ln -sf /koolshare/scripts/ks_app_install.sh /koolshare/scripts/ks_app_remove.sh
		fi
	fi
}

softcenter_install
