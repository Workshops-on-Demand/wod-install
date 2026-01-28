#!/bin/bash

set -e
set -u
set -o pipefail

# Script to customize an Ubuntu distribution so it's ready for a WoD usage
# This first part is distribution specific and should be adapted based on its nature

PKGLIST="perl ansible openssh-server"
if [ $WODTYPE != "appliance" ]; then
	PKGLIST="$PKGLIST git jq"
fi

# Kill potentially stuck apt commands
killall apt

# Base packages required
apt update
apt install -y $PKGLIST
