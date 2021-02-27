# PhotonOS Storage Appliance


This is a project to develop a Packer template to have an NFS server and S3 server provided by MinIO. 

The OVA is based around Photon OS and can be built using [Packer](https://www.packer.io). It is based around the work by [William Lam](https://github.com/lamw/photonos-nfs-appliance) and [Timo Sugliani](https://github.com/tsugliani/packer-vsphere-debian-appliances). 

The following Packer templates will build an OVA using a VMware vSphere ESXi host (although it is easily modifiable to build from VMware Workstation or Fusion) from a Photon 3.0 image. After the creation, the VM will be customizable using OVF parameters, so network, root password and Harbor configuration will be assignable during deployment. If no network is configured during deployment, it will use DHCP.

---

## Requirements

- A Linux or Mac environment (to be able to run the shell-local provisioner)
- A VMware ESXi host to use as builder prepared for Packer using [this guide](https://nickcharlton.net/posts/using-packer-esxi-6.html)
    - Note: if you are using a ESXi 7.x as a builder, switch to the esxi-70 branch, as it is configured to use [VNC over websockets](https://www.virtuallyghetto.com/2020/10/quick-tip-vmware-iso-builder-for-packer-now-supported-with-esxi-7-0.html)
- A DHCP-enabled network.
- [Packer 1.6.6](https://www.packer.io/downloads)
- [OVFTool](https://www.vmware.com/support/developer/ovf/) installed and configured in your PATH.


---

## Building

To build this template, you will need to edit the photonos-storage-appliance-builder.json file with your ESXi values:


```
{
  "builder_host": "packerbuild.sclab.local",
  "builder_host_username": "root",
  "builder_host_password": "VMware1!",
  "builder_host_datastore": "datastore1",
  "builder_host_portgroup": "VM Network"
}
```

Then run the photonos-storage-appliance.sh script or execute the following commands:

```
rm -f output-vmware-iso/*

packer build -var-file=photonos-storage-appliance-builder.json -var-file=photonos-storage-appliance-version.json -var-file=photonos-storage-appliance-version.json photonos-storage-appliance.json
```

---


## Deployment parameters

The following network parameters can be configured when deploying the OVA in vSphere:


| Value          | Description              | Default value |
|----------------|--------------------------|---------------|
| Hostname       | Hostname for the VM.     | photonos-storage-appliance        |
| IP Address     | IP address of the VM     | (DHCP)        |
| Netmask Prefix | Netmask in CIDR notation | (DHCP)        |
| Gateway        | Gateway of the VM        | (DHCP)        |
| DNS            | DNS Server of the VM     | (DHCP)        |
| DNS Domain     | DNS Domain of the VM     | (DHCP)        |


The password for the root user must be configured on deployment:


| Value         | Description                                  | Default value   |
|---------------|----------------------------------------------|-----------------|
| Root Password | Password to log into the system as root user | Mandatory value |


The following storage configuration parameters can be set during deployment:


| Value                                | Description                                           | Default value              |
|--------------------------------------|-------------------------------------------------------|----------------------------|
| NFS Data Volume size                 | Size of NFS data volume in GB                         | 60 GB                      |
| MinIO Data Volume size               | Size of MinIO data volume in GB                       | 60 GB                      |



An additional flag can be configured for virtual machine deployment debugging:


| Value | Description                                                | Default value |
|-------|------------------------------------------------------------|---------------|
| Debug | Enables logging to /var/log/photon-customization-debug.log | False         |


---

## Storage parameters

After the VM boots, the NFS share will be available on /mnt/nfs, which can be verified by using:

```
root@storage [ ~ ]# showmount -e
Export list for storage:
/mnt/nfs *
```

MinIO will also be installed and available in the port 9000. It can be accessed in the URL http://YOUR-IP:9000 (where YOUR_IP is your selected IP, either static or set dynamically with DHCP):

- MinIO username: minioadmin
- MinIO password: minioadmin

## Acknowledgements


This project is possible because of the great work done by the Harbor project maintainers. Also, a big thank you to the  [packer-vsphere-debian-appliances](https://github.com/tsugliani/packer-vsphere-debian-appliances) project by Timo Sugliani and [photonos-nfs-appliance](https://github.com/lamw/photonos-nfs-appliance) project
