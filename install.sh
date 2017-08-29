#!/bin/bash
# ================================================================================
# SSL cert management script for Let's Encrypt - Installer
#
# author: Axel Pardemann (axelitus)
# ================================================================================
declare -r SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r BIN_PATH="/usr/sbin"
declare -r ETC_PATH="/etc/ssl-certs"
declare -r LIB_PATH="/lib/ssl-certs"

run_install()
{
	echo "Allowing execution of ssl-certs script ..."
	chmod a+x "$SCRIPT_PATH/bin/ssl-certs.sh"

	echo "Creating symlink in $BIN_PATH ..."
	[ ! -L "$BIN_PATH/ssl-certs" ] && ln -s "$SCRIPT_PATH/bin/ssl-certs.sh" "$BIN_PATH/ssl-certs"

	echo "Creating config directory in $ETC_PATH ..."
	[ ! -d "$ETC_PATH" ] && mkdir "$ETC_PATH"
	[ ! -d "$ETC_PATH/domains.d" ] && mkdir "$ETC_PATH/domains.d"
	[ ! -d "$ETC_PATH/hooks.d" ] && mkdir "$ETC_PATH/hooks.d"

	echo "Copying main configuration file ..."
	[ ! -f "$ETC_PATH/ssl-certs.ini" ] && cp "$SCRIPT_PATH/etc/ssl-certs/ssl-certs.ini" "$ETC_PATH/ssl-certs.ini"

	echo "Copying example domain configuration file ..."
	cp -f "$SCRIPT_PATH/etc/ssl-certs/domains.d/.example.ini" "$ETC_PATH/domains.d/.example.ini"

	echo "Copying default hooks (if not existent) in folder $ETC_PATH/hooks.d ..."
	[ ! -f "$ETC_PATH/hooks.d/post-domain" ] && cp "$SCRIPT_PATH/etc/ssl-certs/hooks.d/post-domain" "$ETC_PATH/hooks.d/post-domain"
	[ ! -f "$ETC_PATH/hooks.d/pre-domain" ] && cp "$SCRIPT_PATH/etc/ssl-certs/hooks.d/pre-domain" "$ETC_PATH/hooks.d/pre-domain"

	echo "Creating symlink to lib folder $LIB_PATH ..."
	[ ! -L "$LIB_PATH" ] && ln -s "$SCRIPT_PATH/lib/ssl-certs/" "$LIB_PATH"
}

if [ $EUID -ne 0 ]; then
	echo "Requesting root privileges ..."
	sudo "$0" "$@"
	exit $?
fi
run_install
