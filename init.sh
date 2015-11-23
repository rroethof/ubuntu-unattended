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
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7HqgtZh7LUMGonXS8p7dotfrLqZx0RH1jcUjdEOH5MEa/Q3Y8u5rlz0FO10rt+Qp9vb+ugzkfPtEGZz4Vz3JhJlCJV4/y419Km6IkdJvomGsfnzmswHW+5Ell6btX72iE3498g3xiD3Vq9NJHveOWmBRnsSolgLkqg0vn9p6lZO31SnnhlWvNNZdgXTJwKpo3NdUJWEj3RDYpXQDoUrcJOJG1f5OdLtlySb9ehh4o+FScuHpmEIBaU+T3oDqRxNNak3AZ/OmtGJXyJF6GrhBjLbsOdAXTH1AolKJNj2uaByxxPiNXT+Bu0yXRubzPG9e2GvNMKL8MK5d+/ULpYh8x root@ansible.familieroethof.nl" >> /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh

# remove myself to prevent any unintended changes at a later stage
rm $0

# finish
echo " DONE; rebooting ... "

# reboot
shutdown -r now
