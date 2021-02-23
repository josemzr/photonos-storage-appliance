#!/bin/bash -eux

##
## Misc configuration
##

echo '> Disable IPv6'
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf

echo '> Update package repos to VMware'
sed  -i 's/dl.bintray.com\/vmware/packages.vmware.com\/photon\/$releasever/g' /etc/yum.repos.d/photon.repo /etc/yum.repos.d/photon-updates.repo /etc/yum.repos.d/photon-extras.repo /etc/yum.repos.d/photon-debuginfo.repo

echo '> Applying latest Updates...'
tdnf -y update

echo '> Installing Additional Packages...'
tdnf install -y \
  less \
  logrotate \
  curl \
  wget \
  unzip \
  awk \
  tar \
  nfs-utils

echo '> Enable Docker in Systemd'
systemctl enable docker

echo '> Done'
