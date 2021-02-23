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

echo '> Configuring Minio...'
useradd --system minio-user --shell /sbin/nologin
groupadd minio-user
curl -O https://dl.minio.io/server/minio/release/linux-amd64/minio
mv minio /usr/local/bin
chmod +x /usr/local/bin/minio
chown minio-user:minio-user /usr/local/bin/minio

mkdir /etc/minio
mkdir -p /mnt/s3

chown minio-user:minio-user /etc/minio
chown minio-user:minio-user /mnt/s3

echo "MINIO_VOLUMES="/mnt/s3"" > /etc/default/minio
echo "MINIO_OPTS="-C /etc/minio"" >> /etc/default/minio

# Configure MinIO Systemd Service
setcap 'cap_net_bind_service=+ep' /usr/local/bin/minio
curl -O https://raw.githubusercontent.com/minio/minio-service/master/linux-systemd/minio.service
mv minio.service /etc/systemd/system

echo '> Enable Docker in Systemd'
systemctl enable docker

echo '> Done'
