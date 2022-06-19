#!/bin/bash

function check_env() {
    test -z $VM_NAME && echo 'Please specify VM_NAME' && exit 1

    if [[ -z $INIT ]]; then
        test -z $K3S_URL && echo 'Please specify $K3S_URL' && exit 1
        test -z $K3S_TOKEN && echo 'Please specify $K3S_TOKEN' && exit 1
    else
        test -z $DATASTORE && echo 'Please specify $DATASTORE' && exit 1
    fi

    OVA=${OVA:-../coreos.ova}
    BUTANE=${BUTANE:-config.yml}
    IGNITION=${IGNITION:-config.ign}
    FORMAT=${FORMAT:-../.format}
    NETWORK=${NETWORK:-NAT}
    INSTALL_K3S_VERSION=${INSTALL_K3S_VERSION:-v1.23.6+k3s1}
    ADAPTER=$(ip route ls default | grep -Po '(?<= dev )(\S+)')
}

function render_configuration() {
    envsubst "$(cat $FORMAT)" < $BUTANE | butane --pretty --strict > $IGNITION
}

function create_vm() {
    vboxmanage import --vsys 0 --vmname "$VM_NAME" "$OVA"
    vboxmanage guestproperty set "$VM_NAME" /Ignition/Config "$(cat $IGNITION)"
}

function setup_bridge_network() {
    echo "Putting network in bridge mode"
    vboxmanage modifyvm "$VM_NAME" --nic1 bridged --nictype1 82545EM --bridgeadapter1 "$ADAPTER"
}

function setup_host_network() {
    echo "Putting network in hostonly mode"
}

function setup_nat_network() {
    echo "Putting network in nat mode"
    HOSTONLY_NETWORK=${HOSTONLY_NETWORK:-"vboxnet0"}
    vboxmanage modifyvm "$VM_NAME" --nic1 hostonly --hostonlyadapter1 "$HOSTONLY_NETWORK"
    vboxmanage modifyvm "$VM_NAME" --nic2 nat
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Verify all configuration is valid
    # and initalize computable variables
    check_env

    # Render ignition file using environment variables
    render_configuration

    # Import OVA file and add ignition file
    create_vm

    # Setup networking
    if [[ "$NETWORK" == "BRIDGE" ]]; then
        setup_bridge_network
    elif [[ "$NETWORK" == "NAT" ]]; then
        setup_nat_network
    else
        echo "No network setup"
    fi

    # Start VM and remove ignition if it was started successfully
    vboxmanage startvm "$VM_NAME" --type headless && rm $IGNITION
fi
