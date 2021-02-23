#!/bin/bash

# Bootstrap script

set -euo pipefail

    HOSTNAME_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.hostname")
    IP_ADDRESS_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.ipaddress")
    NETMASK_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.netmask")
    GATEWAY_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.gateway")
    DNS_SERVER_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.dns")
    DNS_DOMAIN_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.domain")
    ROOT_PASSWORD_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.root_password")

    HOSTNAME=$(echo "${HOSTNAME_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
    IP_ADDRESS=$(echo "${IP_ADDRESS_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
    NETMASK=$(echo "${NETMASK_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
    GATEWAY=$(echo "${GATEWAY_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
    DNS_SERVER=$(echo "${DNS_SERVER_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
    DNS_DOMAIN=$(echo "${DNS_DOMAIN_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
    ROOT_PASSWORD=$(echo "${ROOT_PASSWORD_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')

configureNFS() {
    echo -e "\e[92mConfiguring NFS ..." > /dev/console

    mkdir -p /mnt/nfs

    DISK=/dev/sdb
    printf "o\nn\np\n1\n\n\nw\n" | fdisk "${DISK}"
    mkfs.ext3 -L nfs "${DISK}1"
    mount -o defaults "${DISK}1" /mnt/nfs
    echo ""${DISK}1"     /mnt/nfs         ext3 defaults 0 2" >> /etc/fstab

    mkdir -p /mnt/nfs
    echo "/mnt/nfs *(no_root_squash,rw,async,no_subtree_check,insecure)" > /etc/exports
}


configureMinIO() {
    echo -e "\e[92mConfiguring MinIO ..." > /dev/console

    mkdir -p /mnt/s3

    DISK=/dev/sdc
    printf "o\nn\np\n1\n\n\nw\n" | fdisk "${DISK}"
    mkfs.ext3 -L nfs "${DISK}1"
    mount -o defaults "${DISK}1" /mnt/s3
    echo ""${DISK}1"     /mnt/s3         ext3 defaults 0 2" >> /etc/fstab

    mkdir -p /mnt/s3

    # Prepare PhotonOS for MinIO
    useradd --system minio-user --shell /sbin/nologin
    groupadd minio-user
    curl -O https://dl.minio.io/server/minio/release/linux-amd64/minio
    mv minio /usr/local/bin
    chmod +x /usr/local/bin/minio
    chown minio-user:minio-user /usr/local/bin/minio

    mkdir /etc/minio
    chown minio-user:minio-user /etc/minio
    chown minio-user:minio-user /mnt/s3

    echo "MINIO_VOLUMES="/mnt/s3"" > /etc/default/minio
    echo "MINIO_OPTS="-C /etc/minio"" >> /etc/default/minio

    # Configure MinIO Systemd Service
    setcap 'cap_net_bind_service=+ep' /usr/local/bin/minio
    curl -O https://raw.githubusercontent.com/minio/minio-service/master/linux-systemd/minio.service
    mv minio.service /etc/systemd/system
    systemctl daemon-reload
    systemctl enable minio
    systemctl start minio
}

configureDHCP() {
    echo -e "\e[92mConfiguring network using DHCP..." > /dev/console
    cat > /etc/systemd/network/${NETWORK_CONFIG_FILE} << __CUSTOMIZE_PHOTON__
[Match]
Name=e*

[Network]
DHCP=yes
IPv6AcceptRA=no
__CUSTOMIZE_PHOTON__
}

configureStaticNetwork() {

    echo -e "\e[92mConfiguring Static IP Address ..." > /dev/console
    cat > /etc/systemd/network/${NETWORK_CONFIG_FILE} << __CUSTOMIZE_PHOTON__
[Match]
Name=e*

[Network]
Address=${IP_ADDRESS}/${NETMASK}
Gateway=${GATEWAY}
DNS=${DNS_SERVER}
Domain=${DNS_DOMAIN}
__CUSTOMIZE_PHOTON__
}

configureHostname() {
    echo -e "\e[92mConfiguring hostname ..." > /dev/console
    [ -z "${HOSTNAME}" ] && HOSTNAME=harbor hostnamectl set-hostname harbor  || hostnamectl set-hostname ${HOSTNAME}
    echo "${IP_ADDRESS} ${HOSTNAME}" >> /etc/hosts
}

restartNetwork() {
    echo -e "\e[92mRestarting Network ..." > /dev/console
    systemctl restart systemd-networkd
}

configureRootPassword() {
    echo -e "\e[92mConfiguring root password ..." > /dev/console
    echo "root:${ROOT_PASSWORD}" | /usr/sbin/chpasswd
}

createCustomizationFlag() {
    # Ensure that we don't run the customization again
    touch /opt/ran_customization
}

if [ -e /opt/ran_customization ]; then
    exit
else
    NETWORK_CONFIG_FILE=$(ls /etc/systemd/network | grep .network)

    DEBUG_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.debug")
    DEBUG=$(echo "${DEBUG_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
    LOG_FILE=/var/log/bootstrap.log
    if [ ${DEBUG} == "True" ]; then
        LOG_FILE=/var/log/photon-customization-debug.log
        set -x
        exec 2> ${LOG_FILE}
        echo
        echo "### WARNING -- DEBUG LOG CONTAINS ALL EXECUTED COMMANDS WHICH INCLUDES CREDENTIALS -- WARNING ###"
        echo "### WARNING --             PLEASE REMOVE CREDENTIALS BEFORE SHARING LOG            -- WARNING ###"
        echo
    fi

# Leaving blank IP address, netmask or gateway will force DHCP
if [ -z "${IP_ADDRESS}" ] || [ -z "${NETMASK}" ] || [ -z "${GATEWAY}" ]; then

    configureDHCP
    configureHostname
    restartNetwork
    configureRootPassword
    configureNFS
    configureMinIO
    createCustomizationFlag

    else

    configureStaticNetwork
    configureHostname
    restartNetwork
    configureRootPassword
    configureNFS
    configureMinIO
    createCustomizationFlag

    fi
fi
