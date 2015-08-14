#!/bin/bash
set -e

spinner()
{
	local pid=$1
	local delay=0.175
	local spinstr='|/-\'
	local infotext=$2
	tput civis;

	while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
		local temp=${spinstr#?}
		printf " [%c] %s" "$spinstr" "$infotext"
		local spinstr=$temp${spinstr%"$temp"}
		sleep $delay
		printf "\b\b\b\b\b\b"

		for i in $(seq 1 ${#infotext}); do
			printf "\b"
		done
	
	done

	printf " \b\b\b\b"
	tput cnorm;
}

# set defaults
default_hostname="$(hostname)"
default_domain="intra.fd.nl"
tmp=$(pwd)

clear

# check for root privilege
if [ "$(id -u)" != "0" ]; then
	echo " this script must be run as root" 1>&2
	echo
	exit 1
fi

# determine ubuntu version
ubuntu_version=$(lsb_release -cs)

# check for interactive shell
if ! grep -q "noninteractive" /proc/cmdline ; then
	stty sane

	# ask questions
	read -ep " please enter your preferred hostname: " -i "$default_hostname" hostname
	read -ep " please enter your preferred domain: " -i "$default_domain" domain
fi

# print status message
echo " preparing your server; this may take a few minutes ..."

# set fqdn
fqdn="$hostname.$domain"

# update hostname
echo "$hostname" > /etc/hostname
sed -i "s@ubuntu.ubuntu@$fqdn@g" /etc/hosts
sed -i "s@ubuntu@$hostname@g" /etc/hosts
hostname "$hostname"

# update repos
(apt-get -y update > /dev/null 2>&1) & spinner $! "updating apt repository ..."
echo
(apt-get -y upgrade > /dev/null 2>&1) & spinner $! "upgrade ubuntu os ..."
echo
(apt-get -y dist-upgrade > /dev/null 2>&1) & spinner $! "dist-upgrade ubuntu os ..."
echo
(apt-get -y install openssh-server git curl vim > /dev/null 2>&1) & spinner $! "installing extra software ..."
echo
(apt-get -y autoremove > /dev/null 2>&1) & spinner $! "removing old kernels and packages ..."
echo
(apt-get -y purge > /dev/null 2>&1) & spinner $! "purging removed packages ..."
echo

# adding the keys from sumanage01
mkdir /root/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCqMg5JJRmb1Mi0UqvPb8XArw5GHppnNQmiN1yxsgMLjESwydR/Xqdmci1MBja/QBcgNlkmpKtW5eOrPQraT7AWG8faM+DWVBRJJpOMes6HLU3WfvdwagYNZc/fMzrfWlPrgv49vSPoji0rXJc+xJ94kOBHxATQ7yQiBohML1jQbU+vdJLaldSBzfylI4POymafwKR/0xjM5c2Dd38nFN9ErtiJw6+e9NlRspK7L3IOa1xcMZZmyK47IxcTOhVMpOJV1T8LFu8HTmT0lbXqthc2wDjPgwn56Dj63Z4UsnZ4w+YVkIw7B/MWDshWjESm4xt/8vv7qmF/MFDuQGNtGPEJ ansible@sumanage01" >> /root/.ssh/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAoL5VyQXE6RtwsoR/h/kiRtynWucLSw6uJGRLp5K8CMv5ZskHxiz1Qgprl/0i0HGBanPLGC46MJbZ23VtA5JeQ5Nor+ukS5uK1MD6r4pLahVNX5G1bajNmp/gKBxZhFtFSZgEQZ5gAed9GvRbpFBwYUqnK0MbBkOs66ACGUkyt/30iZ3yZz/b7UytFfMibCw3xKMuZCFGO/rJ5wb0tBaa1C5ehx946/4VqwNlSAjXV3h52qbI8SDjDK/hkd5k8M0ifge2Iuged2+nWgmHLyRIKMrZeWE4Tyiar7Vuab/ls1PE6WF2phki877Wj4g9T7CYsx0pxNvgc/GctsQ2kA6Wxw== root@sumanage01" >> /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh

# remove myself to prevent any unintended changes at a later stage
rm $0

# finish
echo " DONE; rebooting ... "

# reboot
shutdown -r now
