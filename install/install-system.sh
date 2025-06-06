#!/bin/bash

set -x 

date

export WODTYPE=$1
if [ -z "$WODTYPE" ]; then
    echo "Syntax: install-system.sh api-db|backend|frontend|appliance"
    exit -1
fi

if [ ! -f $HOME/.gitconfig ]; then
    cat > $HOME/.gitconfig << EOF
# This is Git's per-user configuration file.
[user]
# Please adapt and uncomment the following lines:
name = $WODUSER
email = $WODUSER@nowhere.org
EOF
fi
#
# WODINSDIR points to a subdir of wod-install
PWODINSDIR=`dirname $WODINSDIR`
WODROOTDIR=`dirname $PWODINSDIR`
WODINSANSDIR="$PWODINSDIR/ansible"
WODINSSCRIPTDIR="$PWODINSDIR/scripts"
WODINSSYSDIR="$PWODINSDIR/sys"
# valid on the node being installed
WODANSIBLEDIR=$WODROOTDIR/wod-$WODTYPE/ansible
WODGROUP=$WODGROUP

cat > /etc/wod.sh << EOF
# This is the wod.sh script, generated at install
#
# Name of the admin user
export WODUSER=$WODUSER

# Name of the wod machine type (backend, api-db, frontend, appliance)
export WODTYPE=$WODTYPE

# Name of the api-db server
export WODAPIDBFQDN="$WODAPIDBFQDN"
# Port of the api-db server
export WODAPIDBPORT="$WODAPIDBPORT"
# Name of the external api-db server
export WODAPIDBEXTFQDN="$WODAPIDBEXTFQDN"
# Port of the external api-db server
export WODAPIDBEXTPORT="$WODAPIDBEXTPORT"
# Combined URL for API access
export WODAPIDBURL=http://$WODAPIDBFQDN:$WODAPIDBPORT/api
# Combined URL for external API access
export WODAPIDBEXTURL=http://$WODAPIDBEXTFQDN:$WODAPIDBEXTPORT/api
#
# Places where repos have been exported for WODUSER
export WODROOTDIR=$WODROOTDIR
#
# INSTALL PART
# The install dir has some fixed subdirs  for shared content
# wod-install (WODINSDIR)
#    |---------- ansible (WODINSANSDIR)
#    |---------- scripts (WODINSSCRIPTDIR)
#    |---------- skel
#    |---------- sys (WODINSSYSDIR)
#
export WODINSDIR=$WODINSDIR
export WODINSANSDIR=$WODINSANSDIR
export WODINSSYSDIR=$WODINSSYSDIR
export WODINSSCRIPTDIR=$WODINSSCRIPTDIR
export WODANSIBLEDIR=$WODANSIBLEDIR
#
export WODGROUP=$WODGROUP
EOF

cat >> /etc/wod.sh << 'EOF'
#
# BACKEND PART
# The backend dir has some fixed subdirs 
# wod-backend (WODBEDIR)
#    |---------- ansible (WODANSIBLEDIR)
#    |---------- conf
#    |---------- scripts (WODSCRIPTDIR)
#    |---------- skel
#    |---------- sys (WODSYSDIR)
#
# Location of the backend directory
#
export WODBEDIR=$WODROOTDIR/wod-backend

# PRIVATE PART
# These 3 dirs have fixed names by default that you can change in this file
# they are placed as sister dirs wrt WODBEDIR
# This is the predefined structure for a private repo
# wod-private (WODPRIVDIR)
#    |---------- ansible (WODANSIBLEPRIVDIR)
#    |---------- notebooks (WODPRIVNOBO)
#    |---------- scripts (WODSCRIPTPRIVDIR)
#
export WODPRIVDIR=$WODROOTDIR/wod-private
export WODANSIBLEPRIVDIR=$WODPRIVDIR/ansible
export WODSCRIPTPRIVDIR=$WODPRIVDIR/scripts
export WODSYSPRIVDIR=$WODPRIVDIR/sys
export WODPRIVNOBO=$WODPRIVDIR/notebooks
WODPRIVINV=""
# Manages private inventory if any
if [ -f $WODPRIVDIR/ansible/inventory ]; then
    WODPRIVINV="-i $WODPRIVDIR/ansible/inventory"
fi
export WODPRIVINV

# AIP-DB PART
#    |---------- ansible (WODANSIBLEDIR)
#    |---------- conf
#    |---------- scripts (WODSCRIPTDIR)
#    |---------- sys (WODSYSDIR)
#
export WODAPIDBDIR=$WODROOTDIR/wod-api-db

# FRONTEND PART
#    |---------- ansible (WODANSIBLEDIR)
#    |---------- conf
#    |---------- scripts (WODSCRIPTDIR)
#    |---------- sys (WODSYSDIR)
#
export WODFEDIR=$WODROOTDIR/wod-frontend
export WODNOBO=$WODROOTDIR/wod-notebooks
#
# DERIVED DIRS valid on the node being installed
export WODSYSDIR=$WODROOTDIR/wod-$WODTYPE/sys
export WODSCRIPTDIR=$WODROOTDIR/wod-$WODTYPE/scripts
EOF
if [ $WODTYPE = "backend" ]; then
    cat >> /etc/wod.sh << 'EOF'

# These dirs are also fixed by default and can be changed as needed
export WODSTUDDIR=/student
#
EOF
fi

chmod 755 /etc/wod.sh
source /etc/wod.sh

cd $WODANSIBLEDIR

# Declares shell variables as ansible variables as well
# then they can be used in playbooks
WODANSPLAYOPT="-e WODGROUP=$WODGROUP -e WODUSER=$WODUSER -e WODBEDIR=$WODBEDIR -e WODNOBO=$WODNOBO -e WODPRIVNOBO=$WODPRIVNOBO -e WODPRIVDIR=$WODPRIVDIR -e WODAPIDBDIR=$WODAPIDBDIR -e WODFEDIR=$WODFEDIR -e WODSTUDDIR=$WODSTUDDIR -e WODANSIBLEDIR=$WODANSIBLEDIR -e WODANSIBLEPRIVDIR=$WODANSIBLEPRIVDIR -e WODSCRIPTDIR=$WODSCRIPTDIR -e WODSCRIPTPRIVDIR=$WODSCRIPTPRIVDIR -e WODSYSDIR=$WODSYSDIR -e WODSYSPRIVDIR=$WODSYSPRIVDIR -e WODINSDIR=$WODINSDIR -e WODINSSCRIPTDIR=$WODINSSCRIPTDIR -e WODINSANSDIR=$WODINSANSDIR -e WODINSSYSDIR=$WODINSSYSDIR -e @$WODINSANSDIR/group_vars/all.yml"

if ! command -v ansible-galaxy &> /dev/null
then
    echo "ansible-galaxy could not be found, please install ansible"
    exit -1
fi
if [ $WODDISTRIB = "centos-7" ] || [ $WODDISTRIB = "ubuntu-20.04" ] || [ $WODDISTRIB = "ubuntu-22.04" ]; then
    # Older distributions require an older version of the collection to work.
    # See https://github.com/ansible-collections/community.general
    ansible-galaxy collection install --force-with-deps community.general:4.8.5
else
    ansible-galaxy collection install community.general
fi
ansible-galaxy collection install ansible.posix

# Execute private script if any
SCRIPT=`realpath $0`
SCRIPTREL=`echo $SCRIPT | perl -p -e "s|$WODINSDIR||"`
if [ -x $WODPRIVDIR/$SCRIPTREL ];
then
    echo "Executing additional private script $WODPRIVDIR/$SCRIPTREL"
    $WODPRIVDIR/$SCRIPTREL
fi

WODANSPRIVOPT=""
if [ -f "$WODANSIBLEPRIVDIR/group_vars/all.yml" ]; then
    WODANSPRIVOPT="$WODANSPRIVOPT -e @$WODANSIBLEPRIVDIR/group_vars/all.yml"
fi
# Built later on
WODANSPRIVOPT="$WODANSPRIVOPT -e @$WODANSIBLEPRIVDIR/generated/$WODGROUP"
if [ -f "$WODANSIBLEPRIVDIR/group_vars/$WODGROUP" ]; then
    WODANSPRIVOPT="$WODANSPRIVOPT -e @$WODANSIBLEPRIVDIR/group_vars/$WODGROUP"
fi
export WODANSPRIVOPT

if [ $WODTYPE = "backend" ]; then
    WODANSPLAYOPT="$WODANSPLAYOPT -e WODLDAPSETUP=0 -e WODAPPMIN=0 -e WODAPPMAX=0"
elif [ $WODTYPE = "api-db" ] || [ $WODTYPE = "frontend" ]; then
    WODANSPLAYOPT="$WODANSPLAYOPT -e WODLDAPSETUP=0"
fi
export WODANSPLAYOPT
#
# For future wod.sh usage by other scripts
cat >> /etc/wod.sh << EOF
export WODANSPRIVOPT="$WODANSPRIVOPT"
export WODANSPLAYOPT="$WODANSPLAYOPT"
EOF


# Inventory based on the installed system
if [ $WODTYPE = "backend" ]; then
    # In this case WODBEFQDN represents a single system
    cat > $WODANSIBLEDIR/inventory << EOF
[$WODGROUP]
$WODBEFQDN ansible_connection=local
EOF
elif [ $WODTYPE = "api-db" ]; then
    cat > $WODANSIBLEDIR/inventory << EOF
[$WODGROUP]
$WODAPIDBFQDN ansible_connection=local
EOF
elif [ $WODTYPE = "frontend" ]; then
    cat > $WODANSIBLEDIR/inventory << EOF
[$WODGROUP]
$WODFEFQDN ansible_connection=local
EOF
fi

if [ $WODTYPE != "appliance" ]; then
    # Setup this using the group for WoD
    mkdir -p  $WODANSIBLEPRIVDIR/generated
    cat > $WODANSIBLEPRIVDIR/generated/$WODGROUP << EOF
WODGROUP: $WODGROUP
# 
# Installation specific values
# Modify afterwards or re-run the installer to update
#
# WODBEFQDN may represents multiple systems
WODBEFQDN: $WODBEFQDN
WODBEEXTFQDN: $WODBEEXTFQDN
WODBEIP: $WODBEIP
WODFEFQDN: $WODFEFQDN
WODFEEXTFQDN: $WODFEEXTFQDN
WODAPIDBFQDN: $WODAPIDBFQDN
WODAPIDBEXTFQDN: $WODAPIDBEXTFQDN
WODDISTRIB: $WODDISTRIB
WODBEPORT: $WODBEPORT
WODBEEXTPORT: $WODBEEXTPORT
WODFEPORT: $WODFEPORT
WODFEEXTPORT: $WODFEEXTPORT
WODAPIDBPORT: $WODAPIDBPORT
WODAPIDBEXTPORT: $WODAPIDBEXTPORT
WODPOSTPORT: $WODPOSTPORT
EOF

    if [ -f $WODANSIBLEDIR/group_vars/all.yml ]; then
		# Given as an example in the generated file so admin can adapt
        perl -p -e 's|^|#|' $WODANSIBLEDIR/group_vars/all.yml >> $WODANSIBLEPRIVDIR/generated/$WODGROUP
    fi
fi

# Import the USERMAX value here as needed for both backend and api-db
export USERMAX=`ansible-inventory -i $WODANSIBLEDIR/inventory $WODPRIVINV --host $WODGROUP --playbook-dir $WODANSIBLEDIR --playbook-dir $WODINSANSDIR --playbook-dir $WODANSIBLEPRIVDIR $WODANSPLAYOPT $WODANSPRIVOPT | jq ".USERMAX"`
cat >> /etc/wod.sh << EOF
export USERMAX=$USERMAX
EOF

if [ $WODTYPE = "backend" ]; then
    # Compute WODBASESTDID based on the number of this backend server multiplied by the number of users wanted
    WODBASESTDID=$(($USERMAX*$WODBENBR))
    cat >> $WODANSIBLEPRIVDIR/generated/$WODGROUP << EOF
#
# WODBASESTDID is the offset used to create users in the DB. It is required that each backend has a different non overlapping value.
# Overlap is defined by adding USERMAX (from all.yml)
# The number of the deployed a backend in a specific location is used to compute the range available here
#
# Example:
# for student 35 in location A having WODBASESTDID to 0 the user is created as id 35
# for student 35 in location B having WODBASESTDID to 2000 the user is created as id 2035
# There is no overlap as long as you do not create more than 2000 users which should be the value of USERMAX in that case.
#
# This is different from the offset UIDBASE used for Linux uid
#
WODBASESTDID: $WODBASESTDID
EOF
fi

if [ $WODTYPE = "backend" ]; then
	JPHUB=`ansible-inventory -i $WODANSIBLEDIR/inventory $WODPRIVINV --host $WODGROUP --playbook-dir $WODANSIBLEDIR --playbook-dir $WODINSANSDIR --playbook-dir $WODANSIBLEPRIVDIR $WODANSPLAYOPT $WODANSPRIVOPT | jq ".JPHUB"`
    # In case of update remove first old jupyterhub version
    if [ _"$JPHUB" = _"" ]; then
        echo "Directory for jupyterhub is empty"
        exit -1
    fi
    if [ _"$JPHUB" = _"/" ]; then
        echo "Directory for jupyterhub is /"
        exit -1
    fi
    if [ _"$JPHUB" = _"$HOME" ]; then
        echo "Directory for jupyterhub is $HOME"
        exit -1
    fi
    sudo rm -rf $JPHUB
fi

if [ $WODTYPE != "appliance" ]; then
    # Automatic Installation script for the system 
    ansible-playbook -i inventory $WODPRIVINV --limit $WODGROUP $WODANSPLAYOPT $WODANSPRIVOPT install_$WODTYPE.yml
    if [ $? -ne 0 ]; then
        echo "Install had errors exiting before launching startup"
        exit -1
    fi
fi

# Functions used by api-db and frontend installation
source $WODINSDIR/install-functions.sh

if [ $WODTYPE = "api-db" ]; then
    # We can now generate the seeders files 
    # for the api-db server using the backend content installed as well

    $WODSCRIPTDIR/wod-build-seeders.sh

    cd $WODAPIDBDIR
    echo "Launching npm install..."
    npm install

    get_wodapidb_userpwd
    export PGPASSWORD="TrèsCompliqué!!##123"
    cat > .env << EOF
FROM_EMAIL_ADDRESS="$WODSENDER"
DB_PW=$PGPASSWORD
# Target postfix port to send mail to, managed with procmail
POSTFIX_PORT=$WODPOSTPORT
FEEDBACK_WORKSHOP_URL="None"
WODAPIDBPORT=$WODAPIDBPORT
WODBEEXTPORT=$WODBEEXTPORT
WODUID=`id -u`
WODGID=`id -g`
# Sendgrid Key
SENDGRID_API_KEY=$SENDGRID_API_KEY
# Blacklist for input field
WODDENYLIST=$WODDENYLIST
EOF

    echo "Launching docker PostgreSQL stack"
    # Start the PostgreSQL DB stack
	# We can use yq now as installed by ansible before
    PGSQLDIR=`cat $WODAPIDBDIR/docker-compose.yml | yq '.services.db.environment.PGDATA' | sed 's/"//g'`
    # We need to relog with sudo as $WODUSER so it's really in the docker group
    # and be able to communicate with docker
    # and we need to stop it before to be idempotent
    # and we need to remove the data directory not done by the compose down
    sudo su - $WODUSER -c "cd $WODAPIDBDIR ; docker compose down"
    # That dir is owned by lxd, so needs root to remove
    sudo su - -c "rm -rf $PGSQLDIR"
    sudo su - $WODUSER -c "cd $WODAPIDBDIR ; docker compose config ; docker compose up -d"
    POSTGRES_DB=`cat $WODAPIDBDIR/docker-compose.yml | yq '.services.db.environment.POSTGRES_DB' | sed 's/"//g'`
	# Manage locations
    #psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -c 'CREATE TABLE IF NOT EXISTS locations ("createdAt" timestamp DEFAULT current_timestamp, "updatedAt" timestamp DEFAULT current_timestamp, "location" varchar CONSTRAINT no_null NOT NULL, "basestdid" integer CONSTRAINT no_null NOT NULL);'
    echo "Reset DB data"
    npm run reset-data
    echo "Setup user $WODAPIDBUSER"
    psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -c 'CREATE EXTENSION IF NOT EXISTS pgcrypto;'
    psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -c "UPDATE users set password=crypt('$WODAPIDBUSERPWD',gen_salt('bf')) where username='$WODAPIDBUSER';"
    echo "Setup user $WODAPIDBADMIN"
    psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -c "UPDATE users set password=crypt('$WODAPIDBADMINPWD',gen_salt('bf')) where username='$WODAPIDBADMIN';"
    echo "Setup user_roles table not done elsewhere"
    psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -c 'CREATE TABLE IF NOT EXISTS user_roles ("createdAt" timestamp DEFAULT current_timestamp, "updatedAt" timestamp DEFAULT current_timestamp, "roleId" integer CONSTRAINT no_null NOT NULL REFERENCES roles (id), "userId" integer CONSTRAINT no_null NOT NULL REFERENCES users (id));'
    psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -c 'ALTER TABLE user_roles ADD CONSTRAINT "ID_PKEY" PRIMARY KEY ("roleId","userId");'
    # Get info on roles and users already declared
    userroleid=`psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -AXqtc "SELECT id FROM roles WHERE name='user';"`
    moderatorroleid=`psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -AXqtc "SELECT id FROM roles WHERE name='moderator';"`
    adminroleid=`psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -AXqtc "SELECT id FROM roles WHERE name='admin';"`
    nbuser=`psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -AXqtc "SELECT COUNT(id) FROM users;"`
    moderatoruserid=`psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -AXqtc "SELECT id FROM users WHERE username='$WODAPIDBUSER';"`
    adminuserid=`psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -AXqtc "SELECT id FROM users WHERE username='$WODAPIDBADMIN';"`
    # Every user as a role of user so it's probably useless !
    for (( i=$nbuser ; i>=1 ; i--)) do
        psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -c 'INSERT INTO user_roles ("roleId", "userId") VALUES ('$userroleid','$i');'
    done
    # Map the moderator user
    psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -c 'INSERT INTO user_roles ("roleId", "userId") VALUES ('$moderatorroleid','$moderatoruserid');'
    # Map the admin user
    psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -c 'INSERT INTO user_roles ("roleId", "userId") VALUES ('$adminroleid','$adminuserid');'
	# Install pm2
	install_pm2 $WODAPIDBDIR
elif [ $WODTYPE = "frontend" ]; then
    cd $WODFEDIR
    echo "Launching npm install..."
    npm install
    echo "Patching package.json to allow listening on the right host:port"
    perl -pi -e "s|gatsby develop|gatsby develop -H $WODFEFQDN -p $WODFEPORT|" package.json
	# Install pm2
	install_pm2 $WODFEDIR
fi

if [ $WODTYPE != "appliance" ]; then
	# Each node has its own
    cd $WODANSIBLEDIR

    ansible-playbook -i inventory $WODPRIVINV --limit $WODGROUP $WODANSPLAYOPT $WODANSPRIVOPT check_$WODTYPE.yml
fi
date
