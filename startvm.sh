#!/bin/bash

test -z $VM_NAME && echo 'Please specify VM_NAME' && exit 1

if [[ -z $INIT ]]; then
    test -z $K3S_URL && echo 'Please specify K3S_URL' && exit 1
    test -z $K3S_TOKEN && echo 'Please specify K3S_TOKEN' && exit 1
fi

OVA=${OVA:-../coreos.ova}
BUTANE=${BUTANE:-config.yml}
IGNITION=${IGNITION:-config.ign}
FORMAT=${FORMAT:-../.format}
INSTALL_K3S_VERSION=${INSTALL_K3S_VERSION:-v1.23.6+k3s1}
ADAPTER=$(ip route ls default | grep -Po '(?<= dev )(\S+)')


envsubst "$(cat $FORMAT)" < $BUTANE | butane --pretty --strict > $IGNITION
vboxmanage import --vsys 0 --vmname "$VM_NAME" "$OVA"
vboxmanage guestproperty set "$VM_NAME" /Ignition/Config "$(cat $IGNITION)"
vboxmanage modifyvm "$VM_NAME" --nic1 bridged --nictype1 82545EM --bridgeadapter1 "$ADAPTER"
vboxmanage startvm "$VM_NAME" --type headless

rm $IGNITION
