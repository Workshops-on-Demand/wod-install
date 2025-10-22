#!/bin/bash
#
#
# As calling vl from perl doesn't give the hand back, I encapsulate stuff in this script :-)
#
EXEPATH=`dirname "$0"`
#
# Prepare the conf file for vl
$EXEPATH/build-vl.pl
# Ask vl to launch the VMs
vl up
# Install the WoD stack
$EXEPATH/build-vl.pl -s
