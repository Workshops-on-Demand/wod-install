Instructions to create a CI/CD machine
Install an ubuntu 24.04 VM with minimal server conf
apt install qemu-kvm git libnet-openssh-perl libvirt-clients libvirt-daemon-system genisoimage
User should be in groups libvirt, qemu, kvm
sudo systemctl start libvirt
Install virt-lightning following (https://github.com/virt-lightning/virt-lightning#installation-debianubuntu)[Ubuntu's instructions]
git clone https://github.com/Workshops-on-Demand/wod-install.git
cd wod-install/install
