#!/bin/bash -x

echo "Building PhotonOS Storage Appliance ..."
rm -f output-vmware-iso/*

packer build -var-file=photonos-storage-appliance-builder.json -var-file=photonos-storage-appliance-version.json -var-file=photonos-storage-appliance-version.json photonos-storage-appliance.json

