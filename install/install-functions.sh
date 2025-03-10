#!/bin/bash
#
# Functions called from other install scripts
#
# (c) Bruno Cornec <bruno.cornec@hpe.com>, Hewlett Packard Development
# Released under the GPLv2 License
#
set -e
#set -x

# This function fetches the DB user/passwd
get_wodapidb_userpwd() {
WODAPIDBUSER=`ansible-inventory -i $WODANSIBLEDIR/inventory $WODPRIVINV --host $WODGROUP --playbook-dir $WODANSIBLEDIR --playbook-dir $WODINSANSDIR --playbook-dir $WODANSIBLEPRIVDIR $WODANSPLAYOPT $WODANSPRIVOPT | yq '.WODAPIDBUSER' | sed 's/"//g'`
WODAPIDBADMIN=`ansible-inventory -i $WODANSIBLEDIR/inventory $WODPRIVINV --host $WODGROUP --playbook-dir $WODANSIBLEDIR --playbook-dir $WODINSANSDIR --playbook-dir $WODANSIBLEPRIVDIR $WODANSPLAYOPT $WODANSPRIVOPT | yq '.WODAPIDBADMIN' | sed 's/"//g'`
WODAPIDBUSERPWD=`ansible-inventory -i $WODANSIBLEDIR/inventory $WODPRIVINV --host $WODGROUP --playbook-dir $WODANSIBLEDIR --playbook-dir $WODINSANSDIR --playbook-dir $WODANSIBLEPRIVDIR $WODANSPLAYOPT $WODANSPRIVOPT | yq '.WODAPIDBUSERPWD' | sed 's/"//g'`
WODAPIDBADMINPWD=`cat ansible-inventory -i $WODANSIBLEDIR/inventory $WODPRIVINV --host $WODGROUP --playbook-dir $WODANSIBLEDIR --playbook-dir $WODINSANSDIR --playbook-dir $WODANSIBLEPRIVDIR $WODANSPLAYOPT $WODANSPRIVOPT | yq '.WODAPIDBADMINPWD' | sed 's/"//g'`

export WODAPIDBUSER
export WODAPIDBUSERPWD
export WODAPIDBADMIN
export WODAPIDBADMINPWD
}

# This functions install pm2 and set it up
install_pm2 () {
	DIR=$1
	echo "Install pm2"
    npm install pm2@latest
    export PATH=$PATH:$DIR/node_modules/pm2/bin
    cat >> $HOME/.bash_profile << EOF
export PATH=$PATH:$DIR/node_modules/pm2/bin
EOF
}

# This function launch or relaunch an npm app (api server of frontend server)
relaunch_with_pm2() {
    APP=$1
    # Needed at install as we do not re-log
    source $HOME/.bash_profile
    shift
    # Allow error to occur
    set +e
    pm2 show $APP 2>&1 > /dev/null
    if [ $? -eq 0 ]; then
        echo "Stop a previous server for $APP"
        pm2 del $APP
    fi
    set -e
    echo "Start the $APP server"
    pm2 start --name=$APP npm -- start
}
