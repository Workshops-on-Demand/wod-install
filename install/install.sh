#!/bin/bash

set -e
set -u
set -o pipefail

WODPOSTPORT="10025"
#
WODBEPORT=8000
WODBEPROTO="http"
WODBEEXTPORT=$WODBEPORT
WODBEEXTPROTO="$WODBEPROTO"
WODFEPORT=8000
WODFEPROTO="http"
WODFEEXTPORT=$WODFEPORT
WODFEEXTPROTO="$WODFEPROTO"
WODAPIDBPORT=8021
WODAPIDBPROTO="http"
WODAPIDBEXTPORT=$WODAPIDBPORT
WODAPIDBEXTPROTO="$WODAPIDBPROTO"

usage() {
    echo "install.sh [-h][-t type][-i ip][-g groupname][-b backend[:beport:[beproto]][-n number][-j backendext[:beportext[:beprotoext]]][-f frontend[:feport[:feproto]]][-w frontendext[:feportext[:feprotoext]]][-a api-db[:apidbport[:apidbproto]]][-e api-dbext[:apidbportext[:apidbprotoext]]][-u user][-p postport][-k][-c][-s sender]"
    echo " "
    echo "where:"
    echo "-a api-db    is the FQDN of the REST API/DB server"
    echo "             potentially with a port (default $WODAPIDBPORT)"
    echo "             potentially with a proto (default $WODAPIDBPROTO)"
    echo "             example: api.internal.example.org  "
    echo "             if empty using the name of the frontend                "
    echo " "
    echo "-b backend   is the FQDN of the backend JupyterHub server,"
    echo "             potentially with a port (default $WODBEPORT)."
    echo "             potentially with a proto (default $WODBEPROTO)"
    echo "             if empty uses the local name for the backend"
    echo "             If you use multiple backend systems corresponding to "
    echo "             multiple locations, use option -n to give the backend"
    echo "             number currently being installed, starting at 1."
    echo " "
    echo "             When installing the api-db server you have to specify one"
    echo "             or multiple backend servers, using their FQDN separated "
    echo "             with ',' using the same order as given with the -n option"
    echo "             during backend installation."
    echo " "
    echo "-e api-dbext is the FQDN of the REST API server accessible externally"
    echo "             potentially with a port (default $WODAPIDBEXTPORT)"
    echo "             potentially with a proto (default $WODAPIDBEXTPROTO)"
    echo "             example: api.external.example.org  "
    echo "             if empty using the name of the api-db                "
    echo "             useful when the name given with -a doesn't resolve from "
    echo "             the client browser"
    echo " "
    echo "-f frontend  is the FQDN of the frontend Web server"
    echo "             potentially with a port (default $WODFEPORT)."
    echo "             potentially with a proto (default $WODFEPROTO)"
    echo "             example: fe.external.example.org  "
    echo "             if empty using the name of the backend                "
    echo " "
    echo "-g groupname is the ansible group_vars name to be used"
    echo "             example: production, staging, test, ...  "
    echo "             if empty using 'production'                "
    echo " "
    echo "-i ip        IP address of the backend server being used"
    echo "             if empty, try to be autodetected from FQDN"
    echo "             of the backend server"
    echo "             Used in particular when the IP can't be guessed (Vagrant)"
    echo "             or when you want to mask the external IP returned"
    echo "             by an internal one for /etc/hosts creation"
    echo " "
    echo "-j backext   is the FQDN of the backend JupyterHub server accessible externally"
    echo "             potentially with a port (default $WODBEEXTPORT)."
    echo "             potentially with a proto (default $WODBEEXTPROTO)"
    echo "             example: jupyterhub.external.example.org  "
    echo "             if empty using the name of the backend                "
    echo "             useful when the name given with -b doesn't resolve from "
    echo "             the client browser"
    echo " "
    echo "-k           if used, force the re-creation of ssh keys for"
    echo "             the previously created admin user"
    echo "             if not used keep the existing keys in place if any"
    echo "             (backed up and restored)"
    echo "             if the name of the admin user is changed, new keys "
    echo "             systematically re-created"
    echo " "
    echo "-c           if used, force insecured curl communications"
    echo "             this is particularly useful for self-signed certificate"
    echo "             on https services"
    echo "             if not used keep curl verification, preventing self-signed"
    echo "             certificates to work"
    echo " "
    echo "-n           if used, this indicates the number of the backend "
    echo "             currently installed"
    echo "             used for the backend installation only, when multiple"
    echo "             backend systems will be used in the configuration"
    echo "             example (single backend server install on port 9999):"
    echo "              -b be.int.example.org:9999"
    echo "             example (first of the 2 backends installed):"
    echo "              -b be1.int.example.org:8888 -n 1"
    echo "             example 'second of the 2 backends installed):"
    echo "              -b be2.int.example.org:8888 -n 2"
    echo "             example (install of the corresponding api-db server):"
    echo "              -b be.int.example.org:8888,be2.int.example.org:8888"
    echo " "
    echo "-p postport  is the port on which the postfix service is listening"
    echo "             on the backend server"
    echo "             example: -p 10030 "
    echo "             if empty using default ($WODPOSTPORT)"
    echo " "
    echo "-s sender    is the e-mail address used in the WoD frontend to send"
    echo "             API procmail mails to the WoD backend"
    echo "             example: sender@example.org "
    echo "             if empty using wodadmin@localhost"
    echo " "
    echo "-t type      is the installation type"
    echo "             valid values: appliance, backend, frontend or api-db"
    echo "             if empty using 'backend'                "
    echo " "
    echo "-u user      is the name of the admin user for the WoD project"
    echo "             example: mywodadmin "
    echo "             if empty using wodadmin               "
    echo "-w frontext  is the FQDN of the frontend JupyterHub server accessible externally"
    echo "             potentially with a port (default $WODFEEXTPORT)."
    echo "             potentially with a proto (default $WODFEEXTPROTO)"
    echo "             example: frontend.external.example.org  "
    echo "             if empty using the name of the frontend                "
    echo "             useful to solve CORS errors when external and internal names"
    echo "             are different"
    echo " "
    echo " "
    echo "Full installation example of a stack with:"
    echo "- 2 backend servers be1 and be2 using port 8010"
    echo "- 1 api-db server apidb on port 10000 using https"
    echo "- 1 frontend server front on port 8000"
    echo "- all declared on the .local network"
    echo "- internal postfix server running on port 9000"
    echo "- e-mail sender being wodmailer@local"
    echo "- ansible groupname being test"
    echo "- management user being wodmgr"
    echo " "
    echo "On the be1 machine:"
    echo "  ./install.sh -a apidb.local:10000:https -f front.local:8000 \\"
    echo "  -g test -u wodmgr -p 9000 -s wodmailer@local\\"
    echo "  -b be1.local:8010 -n 1 -t backend"
    echo "On the be2 machine:"
    echo "  ./install.sh -a apidb.local:10000:https -f front.local:8000 \\"
    echo "  -g test -u wodmgr -p 9000 -s wodmailer@local\\"
    echo "  -b be2.local:8010 -n 2 -t backend"
    echo "On the apidb machine:"
    echo "  ./install.sh -a apidb.local:10000:https -f front.local:8000 \\"
    echo "  -g test -u wodmgr -p 9000 -s wodmailer@local\\"
    echo "  -b be1.local:8010,be2.local:8010 -t api-db"
    echo "On the frontend machine:"
    echo "  ./install.sh -a apidb.local:10000:https -f front.local:8000 \\"
    echo "  -g test -u wodmgr -p 9000 -s wodmailer@local\\"
    echo "  -t frontend"
}

echo "install.sh called with $*"
# Run as root
t=""
f=""
b=""
a=""
e=""
j=""
g=""
u=""
s=""
k=""
i=""
p=""
n=""
w=""
WODGENKEYS=0
WODINSECURE=0

while getopts "t:f:b:o:n:a:e:j:w:g:i:u:s:p:hkc" option; do
    case "${option}" in
        t)
            t=${OPTARG}
            if [ ${t} !=  "backend" ] && [ ${t} != "frontend" ] && [ ${t} != "api-db" ] && [ ${t} != "appliance" ]; then
                echo "wrong type: ${t}"
                usage
                exit -1
            fi
            ;;
        f)
            f=${OPTARG}
            ;;
        i)
            i=${OPTARG}
            ;;
        b)
            b=${OPTARG}
            ;;
        n)
            n=${OPTARG}
            ;;
        g)
            g=${OPTARG}
            ;;
        j)
            j=${OPTARG}
            ;;
        w)
            w=${OPTARG}
            ;;
        e)
            e=${OPTARG}
            ;;
        a)
            a=${OPTARG}
            ;;
        u)
            u=${OPTARG}
            ;;
        s)
            s=${OPTARG}
            ;;
        p)
            p=${OPTARG}
            ;;
        k)
            WODGENKEYS=1
            ;;
        c)
            WODINSECURE=1
            ;;
        h)
            usage
            exit 0
            ;;
        *)
            usage
            exit -1
            ;;
    esac
done
shift $((OPTIND-1))
#if [ -z "${v}" ] || [ -z "${g}" ]; then
    #usage
#fi
if [ ! -z "${t}" ]; then
    WODTYPE="${t}"
else
    WODTYPE="backend"
fi

# Here we have either a single backend for backend install
# WODBEFQDN will point to its FQDN
# WODBEPORT will point to its port
# WODBEPROTO will point to its proto
# or we have multiple of these when installing an api-db
# WODBEFQDN will point to the list of backends with ports and proto separated with ','
# WODBEPORT will be default and not used later
# WODBEPROTO will be default and not used later
MULTIBCKEND=0
if [ ! -z "${b}" ]; then
    WODBEFQDN="`echo ${b} | cut -d: -f1`"
    res=`echo "${b}" | { grep ',' || true; }`
    if [ _"$res" != _"" ]; then
        # We have multiple backends only meaningful in api-db install
        if [ $WODTYPE = "api-db" ]; then
            WODBEFQDN="${b}"
            MULTIBCKEND=1
        else
            echo "Multiple backends are only possible when installing an api-db machine"
            echo " "
            usage
            exit -1
        fi
    else
        # Single backend get its port
        res=`echo "${b}" | { grep ':' || true; }`
        if [ _"$res" != _"" ]; then
            WODBEPORT="`echo ${b} | cut -d: -f2`"
            PROTO="`echo ${b} | cut -d: -f3`"
            if [ _"$PROTO" = _"http" ] || [ _"$PROTO" = _"https" ]; then
                WODBEPROTO=$PROTO
            fi
        fi
    fi
else
    WODBEFQDN=`hostname -f`
fi
# Here we have either a single backend for backend install
# WODBEEXTFQDN will point to its FQDN
# WODBEEXTPORT will point to its port
# WODBEEXTPROTO will point to its proto
# or we have multiple of these when installing an api-db
# WODBEEXTFQDN will point to the list of backends with ports and proto separated with ','
# WODBEEXTPORT will be default and not used later
# WODBEEXTPROTO will be default and not used later

if [ ! -z "${j}" ]; then
    WODBEEXTFQDN="`echo ${j} | cut -d: -f1`"
    res=`echo "${j}" | { grep ',' || true; }`
    if [ _"$res" != _"" ]; then
        # We have multiple backends only meaningful in api-db install
        if [ $WODTYPE = "api-db" ]; then
            WODBEFQDN="${j}"
            MULTIBCKEND=1
        else
            echo "Multiple backends are only possible when installing an api-db machine"
            echo " "
            usage
            exit -1
        fi
    else
        # Single backend get its port
        res=`echo "${j}" | { grep ':' || true; }`
        if [ _"$res" != _"" ]; then
            WODBEEXTPORT="`echo ${j} | cut -d: -f2`"
            PROTO="`echo ${j} | cut -d: -f3`"
            if [ _"$PROTO" = _"http" ] || [ _"$PROTO" = _"https" ]; then
                WODBEEXTPROTO=$PROTO
            fi
        fi
    fi
else
    WODBEEXTFQDN=$WODBEFQDN
    WODBEEXTPORT=$WODBEPORT
    WODBEEXTPROTO=$WODBEPROTO
fi


# In case of multiple backends, record which number this one is.
# only valid for backend install
if [ ! -z "${n}" ]; then
    if [ $WODTYPE = "backend" ]; then
        export WODBENBR=$((n-1))
    else
        echo "Numbering backends is only possible when installing a backend machine"
        echo " "
        usage
        exit -1
    fi
else
    export WODBENBR="0"
fi


if [ ! -z "${f}" ]; then
    WODFEFQDN="`echo ${f} | cut -d: -f1`"
    res=`echo "${f}" | { grep ':' || true; }`
    if [ _"$res" != _"" ]; then
        WODFEPORT="`echo ${f} | cut -d: -f2`"
        PROTO="`echo ${f} | cut -d: -f3`"
        if [ _"$PROTO" = _"http" ] || [ _"$PROTO" = _"https" ]; then
            WODFEPROTO=$PROTO
        fi
    fi
else
    # TODO: relevant ?
    WODFEFQDN="`echo $WODBEFQDN | cut -d: -f1`"
fi

if [ ! -z "${w}" ]; then
    WODFEEXTFQDN="`echo ${w} | cut -d: -f1`"
    res=`echo "${w}" | { grep ':' || true; }`
    if [ _"$res" != _"" ]; then
        WODFEEXTPORT="`echo ${w} | cut -d: -f2`"
        PROTO="`echo ${w} | cut -d: -f3`"
        if [ _"$PROTO" = _"http" ] || [ _"$PROTO" = _"https" ]; then
            WODFEEXTPROTO=$PROTO
        fi
    fi
else
    WODFEEXTFQDN=$WODFEFQDN
    WODFEEXTPORT=$WODFEPORT
    WODFEEXTPROTO=$WODFEPROTO
fi

if [ ! -z "${a}" ]; then
    WODAPIDBFQDN="`echo ${a} | cut -d: -f1`"
    res=`echo "${a}" | { grep ':' || true; }`
    if [ _"$res" != _"" ]; then
        WODAPIDBPORT="`echo ${a} | cut -d: -f2`"
        PROTO="`echo ${a} | cut -d: -f3`"
        if [ _"$PROTO" = _"http" ] || [ _"$PROTO" = _"https" ]; then
            WODAPIDBPROTO=$PROTO
        fi
    fi
else
    # TODO: relevant ?
    WODAPIDBFQDN=$WODFEFQDN
fi

if [ ! -z "${e}" ]; then
    WODAPIDBEXTFQDN="`echo ${e} | cut -d: -f1`"
    res=`echo "${e}" | { grep ':' || true; }`
    if [ _"$res" != _"" ]; then
        WODAPIDBEXTPORT="`echo ${e} | cut -d: -f2`"
        PROTO="`echo ${e} | cut -d: -f3`"
        if [ _"$PROTO" = _"http" ] || [ _"$PROTO" = _"https" ]; then
            WODAPIDBEXTPROTO=$PROTO
        fi
    fi
else
    WODAPIDBEXTFQDN=$WODAPIDBFQDN
    WODAPIDBEXTPORT=$WODAPIDBPORT
    WODAPIDBEXTPROTO=$WODAPIDBPROTO
fi

# This IP address is for the backend only so makes only sense deploying a backend server
if [ ! -z "${i}" ]; then
    WODBEIP="${i}"
else
    if [ ! -x /usr/bin/ping ] || [ ! -x /bin/ping ]; then
        echo "Please install the ping command before re-running this install script"
        exit -1
    fi
    # If ping doesn't work continue if we got the IP address
    FQDN="`echo $WODBEFQDN | cut -d, -f1 | cut -d: -f1`"
set +e
    WODBEIP=`ping -c 1 $FQDN 2>/dev/null | grep PING | grep $FQDN | cut -d'(' -f2 | cut -d')' -f1`
set -e
    if [ _"$WODBEIP" = _"" ]; then
        echo "Unable to find IP address for server $WODBEFQDN"
        exit -1
    fi
fi
export WODBEIP

if [ ! -z "${u}" ]; then
    export WODUSER="${u}"
else
    export WODUSER="wodadmin"
fi

if [ ! -z "${s}" ]; then
    export WODSENDER="${s}"
else
    export WODSENDER="wodadmin@localhost"
fi
if [ ! -z "${p}" ]; then
    WODPOSTPORT="${p}"
fi
if [ ! -z "${g}" ]; then
    WODGROUP="${g}"
else
    WODGROUP="production"
fi
export WODGROUP WODFEFQDN WODBEFQDN WODAPIDBFQDN WODFEEXTFQDN WODBEEXTFQDN WODAPIDBEXTFQDN WODTYPE WODBEPORT WODFEPORT WODAPIDBPORT WODBEEXTPORT WODFEEXTPORT WODAPIDBEXTPORT WODPOSTPORT WODBEPROTO WODFEPROTO WODAPIDBPROTO WODBEEXTPROTO WODFEEXTPROTO WODAPIDBEXTPROTO

WODDISTRIB=`grep -E '^ID=' /etc/os-release | cut -d= -f2 | sed 's/"//g'`-`grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | sed 's/"//g'`
# Only meaningful for Ubuntu
export WODDISTRIBNAME=`grep -E '^UBUNTU_CODENAME=' /etc/os-release | cut -d= -f2`
res=`echo $WODDISTRIB | { grep -i rocky || true; }`
if [ _"$res" != _"" ]; then
    # remove subver
    export WODDISTRIB=`echo $WODDISTRIB | cut -d. -f1`
else
    export WODDISTRIB
fi
echo "Installing a Workshop on Demand $WODTYPE environment"
echo "Using api-db $WODAPIDBFQDN on port $WODAPIDBPORT proto $WODAPIDBPROTO"
if [ _"$WODAPIDBEXTFQDN" != _"$WODAPIDBFQDN" ]; then
    echo "Using external api-db $WODAPIDBEXTFQDN on port $WODAPIDBEXTPORT proto $WODAPIDBEXTPROTO"
fi
if [ _"$MULTIBCKEND" = _"1" ]; then
    echo "Using backends $WODBEFQDN (with first IP $WODBEIP)"
else
    echo "Using backend $WODBEFQDN ($WODBEIP) on port $WODBEPORT proto $WODBEPROTO"
fi
if [ _"$WODBEEXTFQDN" != _"$WODBEFQDN" ]; then
    echo "Using external backend $WODBEEXTFQDN on port $WODBEEXTPORT proto $WODBEEXTPROTO"
fi
echo "Using groupname $WODGROUP"
echo "Using WoD user $WODUSER"
echo "Using WoD base student coef $WODBENBR"

if [ $WODTYPE != "appliance" ]; then
    echo "Using frontend $WODFEFQDN on port $WODFEPORT proto $WODFEPROTO"
fi
if [ _"$WODFEEXTFQDN" != _"$WODFEFQDN" ]; then
    echo "Using external frontend $WODFEEXTFQDN on port $WODFEEXTPORT proto $WODFEEXTPROTO"
fi

SUDOUSR=${SUDO_USER:-}
# Needs to be root
if [ _"$SUDOUSR" = _"" ]; then
    echo "You need to use sudo to launch this script"
    exit -1
fi
HDIR=`grep -E "^$SUDO_USER" /etc/passwd | cut -d: -f6`
if [ _"$HDIR" = _"" ]; then
    echo "$SUDO_USER has no home directory"
    exit -1
fi

# redirect stdout/stderr to a file in the launching user directory
mkdir -p $HDIR/.wodinstall
exec &> >(tee $HDIR/.wodinstall/install.log)

echo "Install starting at `date`"
# Get path of execution
EXEPATH=`dirname "$0"`
export EXEPATH=`( cd "$EXEPATH" && pwd )`
(cd $EXEPATH && git rev-parse HEAD ; date) >> $HDIR/.wodinstall/all-install.log

source $EXEPATH/install.repo
# Overload WODPRIVREPO if using a private one
if [ -f $EXEPATH/install.priv ]; then
    source $EXEPATH/install.priv
fi
export WODFEREPO WODBEREPO WODAPIREPO WODNOBOREPO WODPRIVREPO WODINSREPO
export WODFEBRANCH WODBEBRANCH WODAPIDBBRANCH WODNOBOBRANCH WODPRIVBRANCH WODINSBRANCH
# Potential Variables needed for Sendgrid, Slack and mail check
# Key to use when sending mail through sendgrid - Not mandatory off by default
export WODSENDGRIDAPIKEY=${WODSENDGRIDAPIKEY:="None"}
# Black list these email adresses
export WODDENYLIST=${WODDENYLIST:='@1secmail.com,@1secmail.org'}
# Default values for DB setup - Can be overwritten with an install.priv
export WODPGUSER=${WODPGUSER:='postgres'}
export WODPGPASSWD=${WODPGPASSWD:="TrèsCompliqué!!##123"}
export WODPGDB=${WODPGDB:="workshops-on-demand"}
# Default values for API setup - Can be overwritten with an install.priv
# Used by both api-db and backend
export WODAPIDBUSER=${WODAPIDBUSER:='moderator'}
export WODAPIDBUSERPWD=${WODAPIDBUSERPWD:='MotDePasseCompliquéAussi123!!!##'}
export WODAPIDBADMIN=${WODAPIDBADMIN:='hackshack'}
export WODAPIDBADMINPWD=${WODAPIDBADMINPWD:='MotDePasseCompliquéAussi789!!!##'}

export WODTMPDIR=/tmp/wod.$$

# Create the WODUSER user
if grep -qE "^$WODUSER:" /etc/passwd; then
    WODHDIR=`grep -E "^$WODUSER" /etc/passwd | cut -d: -f6`

   # For idempotency, kill potentially existing jobs
   if [ $WODTYPE = "api-db" ]; then
       set +e
       # Clean potential remaining docker containers
       docker --version 2>&1 /dev/null
       if [ $? -eq 0 ]; then
           systemctl restart docker
           docker stop postgres
           docker stop wod-api-db-adminer-1
           systemctl stop docker
       fi
       # Avoid errors with wod-api-db/data removal as WODUSER
       rm -rf $WODHDIR/wod-$WODTYPE/data
       set -e
   fi

    if ps auxww | grep -qE "^$WODUSER"; then
       pkill -u $WODUSER
       sleep 1
       set +e
       pkill -9 -u $WODUSER
       set -e
    fi
    echo "$WODUSER home directory: $WODHDIR"
    if [ -d "$WODHDIR/.ssh" ]; then
        echo "Original SSH keys"
        ls -al $WODHDIR/.ssh/
        mkdir -p $WODTMPDIR
        chmod 700 $WODTMPDIR
        if [ $WODGENKEYS -eq 0 ] && [ -f $WODHDIR/.ssh/id_rsa ]; then
            echo "Copying existing SSH keys for $WODUSER in $WODTMPDIR"
            cp -a $WODHDIR/.ssh/[a-z]* $WODTMPDIR
        fi
        chown -R $WODUSER $WODTMPDIR
    fi
    userdel -f -r $WODUSER
    if [ -d $WODHDIR ] && [ _"$WODHDIR" != _"/" ]; then
        echo $WODHDIR | grep -qE '^/home'
        if [ $? -eq 0 ]; then
            rm -rf $WODHDIR
        fi
    fi

    # If we do not have to regenerate keys
    if [ $WODGENKEYS -eq 0 ] && [ -d $WODTMPDIR ]; then
        echo "Preserved SSH keys"
        ls -al $WODTMPDIR
    else
        echo "Generating ssh keys for pre-existing $WODUSER"
    fi
else
    echo "Generating ssh keys for non-pre-existing $WODUSER"
fi
useradd -U -m -s /bin/bash $WODUSER

# Keep conf
echo "WODUSER: $WODUSER" > /etc/wod.yml
echo "WODSENDER: $WODSENDER" >> /etc/wod.yml
chown $WODUSER /etc/wod.yml
chmod 644 /etc/wod.yml

echo "# Shell variables for WoD" > /etc/wod.sh
echo "# " >> /etc/wod.sh
chown $WODUSER /etc/wod.sh
chmod 755 /etc/wod.sh

# Manage passwd
export WODPWD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1`
echo "$WODUSER:$WODPWD" | chpasswd
echo "$WODUSER is $WODPWD" > $HDIR/.wodinstall/$WODUSER

# setup sudo for $WODUSER
cat > /etc/sudoers.d/$WODUSER << EOF
Defaults:$WODUSER !fqdn
Defaults:$WODUSER !requiretty
$WODUSER ALL=(ALL) NOPASSWD: ALL
EOF
chmod 440 /etc/sudoers.d/$WODUSER

export WODGENKEYS WODINSECURE

echo "Installation environment :"
echo "---------------------------"
env | grep WOD | sort
echo "---------------------------"

# Call the distribution specific install script
echo "Installing $WODDISTRIB specificities for $WODTYPE"
$EXEPATH/install-system-$WODDISTRIB.sh

# In order to be able to access install script we need correct rights on the home dir of the uid launching the script
WODHDIR=`grep -E "^$WODUSER" /etc/passwd | cut -d: -f6`
BKPSTAT=`stat --printf '%a' $WODHDIR`
echo "Found $WODUSER home directory $WODHDIR with rights $BKPSTAT"
echo "Forcing temporarily open rights to access install scripts"
chmod o+x $WODHDIR

HDIRSTAT=`stat --printf '%a' $HDIR`
echo "Found $SUDO_USER home directory $HDIR with rights $HDIRSTAT"
echo "Forcing temporarily open rights to access install scripts"
chmod o+x $HDIR

# Now drop priviledges
# Call the common install script to finish install
echo "Installing common remaining stuff as $WODUSER"
if [ $WODDISTRIB = "centos-7" ] || [ $WODDISTRIB = "rocky-8" ] ; then
    # that su version doesn't support option -w turning around
    cat > /tmp/wodexports << EOF
export WODGROUP="$WODGROUP"
export WODFEFQDN="$WODFEFQDN"
export WODBEFQDN="$WODBEFQDN"
export WODAPIDBFQDN="$WODAPIDBFQDN"
export WODFEEXTFQDN="$WODFEEXTFQDN"
export WODBEEXTFQDN="$WODBEEXTFQDN"
export WODAPIDBEXTFQDN="$WODAPIDBEXTFQDN"
export WODTYPE="$WODTYPE"
export WODBEIP="$WODBEIP"
export WODDISTRIB="$WODDISTRIB"
export WODDISTRIBNAME="$WODDISTRIBNAME"
export WODUSER="$WODUSER"
export WODFEREPO="$WODFEREPO"
export WODBEREPO="$WODBEREPO"
export WODAPIREPO="$WODAPIREPO"
export WODNOBOREPO="$WODNOBOREPO"
export WODPRIVREPO="$WODPRIVREPO"
export WODINSREPO="$WODPRIVREPO"
export WODFEBRANCH="$WODFEBRANCH"
export WODBEBRANCH="$WODBEBRANCH"
export WODAPIDBBRANCH="$WODAPIDBBRANCH"
export WODNOBOBRANCH="$WODNOBOBRANCH"
export WODPRIVBRANCH="$WODPRIVBRANCH"
export WODINSBRANCH="$WODINSBRANCH"
export WODSENDER="$WODSENDER"
export WODGENKEYS="$WODGENKEYS"
export WODINSECURE="$WODINSECURE"
export WODTMPDIR="$WODTMPDIR"
export WODFEPORT="$WODFEPORT"
export WODBEPORT="$WODBEPORT"
export WODAPIDBPORT="$WODAPIDBPORT"
export WODFEEXTPORT="$WODFEEXTPORT"
export WODBEEXTPORT="$WODBEEXTPORT"
export WODAPIDBEXTPORT="$WODAPIDBEXTPORT"
export WODFEPROTO="$WODFEPROTO"
export WODBEPROTO="$WODBEPROTO"
export WODAPIDBPROTO="$WODAPIDBPROTO"
export WODFEEXTPROTO="$WODFEEXTPROTO"
export WODBEEXTPROTO="$WODBEEXTPROTO"
export WODAPIDBEXTPROTO="$WODAPIDBEXTPROTO"
export WODPOSTPORT="$WODPOSTPORT"
export WODBENBR="$WODBENBR"
export WODSENDGRIDAPIKEY="$WODSENDGRIDAPIKEY"
export WODDENYLIST="$WODDENYLIST"
export WODPGUSER="$WODPGUSER"
export WODPGPASSWD="$WODPGPASSWD"
export WODPGDB="$WODPGDB"
export WODAPIDBUSER="$WODAPIDBUSER"
export WODAPIDBUSERPWD="$WODAPIDBUSERPWD"
export WODAPIDBADMIN="$WODAPIDBADMIN"
export WODAPIDBADMINPWD="$WODAPIDBADMINPWD"
EOF
    chmod 644 /tmp/wodexports
    su - $WODUSER -c "source /tmp/wodexports ; $EXEPATH/install-system-common.sh"
    rm -f /tmp/wodexports
else
    su - $WODUSER -w WODGROUP,WODFEFQDN,WODBEFQDN,WODAPIDBFQDN,WODFEEXTFQDN,WODBEEXTFQDN,WODAPIDBEXTFQDN,WODTYPE,WODBEIP,WODDISTRIB,WODDISTRIBNAME,WODUSER,WODFEREPO,WODBEREPO,WODAPIREPO,WODNOBOREPO,WODPRIVREPO,WODINSREPO,WODFEBRANCH,WODBEBRANCH,WODAPIDBBRANCH,WODNOBOBRANCH,WODPRIVBRANCH,WODINSBRANCH,WODSENDER,WODGENKEYS,WODINSECURE,WODTMPDIR,WODFEPORT,WODBEPORT,WODAPIDBPORT,WODFEEXTPORT,WODBEEXTPORT,WODAPIDBEXTPORT,WODFEPROTO,WODBEPROTO,WODAPIDBPROTO,WODFEEXTPROTO,WODBEEXTPROTO,WODAPIDBEXTPROTO,WODPOSTPORT,WODBENBR,WODSENDGRIDAPIKEY,WODDENYLIST,WODPGUSER,WODPGPASSWD,WODPGDB,WODAPIDBUSER,WODAPIDBUSERPWD,WODAPIDBADMIN,WODAPIDBADMINPWD -c "$EXEPATH/install-system-common.sh"
fi

echo "Setting up original rights for $WODHDIR with $BKPSTAT"
chmod $BKPSTAT $WODHDIR
# TODO: Bug#91
chmod o+x $WODHDIR

echo "Setting up original rights for $HDIR with $HDIRSTAT"
chmod $HDIRSTAT $HDIR

# In any case remove the temp dir
rm -rf $WODTMPDIR

echo "Install ending at `date`"
