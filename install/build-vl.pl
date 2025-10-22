#!/usr/bin/perl -w
#
# Provision the WoD stack with virt-lightning (https://github.com/virt-lightning/virt-lightning)
#
use strict 'vars';
use Getopt::Long qw(:config auto_abbrev no_ignore_case);
use Socket;
use Net::OpenSSH;
use Carp qw/confess cluck/;
#
# Ubuntu version to use
#
my $UVER="24.04";

my $VERNAME=$UVER;
$VERNAME =~ s/\.//;
$VERNAME = "u"."$VERNAME";
# 
# WODGROUP to use
#
my $WODGROUP = "vmtest";
#
# Domain name to use for resolution
#
my $DOMAIN = "wodnet.musique-ancienne.org";
#
# VM setup key: WODTYPE, value: name, disk (in GB), mem (in MB)
# 
my %m = (
	'backend' => {
		name => "wod-backend-$VERNAME.$DOMAIN",
		disk => 30,
		mem => 1500,
	},
	'frontend' => {
		name => "wod-frontend-$VERNAME.$DOMAIN",
		disk => 15,
		mem => 2000,
	},
	'api-db' => {
		name => "wod-api-db-$VERNAME.$DOMAIN",
		disk => 20,
		mem => 1500,
	},
);

# END of modifications allowed for user :-)
#
# Manages options
my %opts;							# CLI Options
GetOptions("stack|-s" => \$opts{'s'});

if (defined $opts{'s'}) {
	# Here we just deploy the WoD stack once VMs have been built
	foreach my $m (sort keys %m) {
		my $ssh = Net::OpenSSH->new($m{$m}->{'name'}, 
			master_opts => [-o => "StrictHostKeyChecking=no"]);
		#sudo ./install.sh -t backend -b wod-backend-u2404.wodnet.musique-ancienne.org -a wod-api-db-u2404.wodnet.musique-ancienne.org -f wod-frontend-u2404.wodnet.musique-ancienne.org -g vmtest -s wodadmin@wod-backend-u2404.wodnet.musique-ancienne.org
		$ssh->system("rm -rf wod-install ; git clone https://github.com/Workshops-on-Demand/wod-install.git ; cd wod-install/install ; echo 'WODBEBRANCH=\"wod-install\"' > install.priv ; echo 'WODFEBRANCH=\"wod-install\"' >> install.priv ; echo 'WODAPIDBBRANCH=\"wod-install\"' >> install.priv ;  echo 'WODPRIVBRANCH=\"wod-install\"' >> install.priv ; nohup sudo -b ./install.sh -t $m -a $m{'api-db'}->{'name'} -b $m{'backend'}->{'name'} -f $m{'frontend'}->{'name'} -g $WODGROUP -s wodadmin\@$m{'backend'}->{'name'}");
	}
	exit(0);
}
#
#
# Check that the distro is available for vl
#
my $distrofound = 0;
open(CMD, "vl distro_list |") || die "Unable to execute vl distro_list";
while (<CMD>) {
	$distrofound = 1 if (/distro: ubuntu-$UVER/);
}
close(CMD);
if ($distrofound == 0) {
	# Try to fetch missing distro
	system("vl fetch ubuntu-$UVER");
}

# Create the virt-lightning.yaml file needed to describe the stack
#
open(FILE,"> virt-lightning.yaml") || die "Unable to create virt-lightning.yaml";
foreach my $m (sort keys %m) {
	my $name = $m{$m}->{'name'};
	print FILE "- name: $name\n";
	print FILE "  distro: ubuntu-$UVER\n";
	print FILE "  memory: $m{$m}->{'mem'}\n";
	print FILE "  vcpus: 1\n";
	print FILE "  root_password: linux1\n";
	print FILE "  disks: [{\"size\": $m{$m}->{'disk'}}]\n";
	print FILE "  networks:\n";
	print FILE "    - network: virt-lightning\n";
	my $packed_ip = gethostbyname($name);
	my $ip_address;
	if (defined $packed_ip) {
		$ip_address = inet_ntoa($packed_ip);
		print FILE "      ipv4: $ip_address\n";
	} else {
		confess "ERROR: unable to resolve $name\n";
	}
}
close(FILE);
exit(0);
