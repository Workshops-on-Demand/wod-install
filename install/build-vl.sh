#!/bin/bash
#
#
# As calling vl from perl doesn't give the hand back, I encapsulate stuff in this script :-)
#
EXEPATH=`dirname "$0"`
#
# Prepare the conf file for vl
$EXEPATH/build-vl.pl
# Start the VM if necessary
for v in `grep name: virt-lightning.yaml | cut -d: -f2`; do
	LANG=C virsh -c qemu:///system list | grep $v | grep -q 'shut off'
	if [ $? -eq 0 ]; then
		virsh -c qemu:///system start $v
		sleep 30
	fi
done
# Ask vl to launch the VMs
vl up
# Install the WoD stack
$EXEPATH/build-vl.pl -s
