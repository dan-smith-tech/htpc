vm_name := "htpcos"
workdir := "/var/lib/libvirt/images/htpcos"
iso_url := "https://mirrors.kernel.org/archlinux/iso/latest/archlinux-x86_64.iso"
net_name := "nat-net"

set shell := ["bash", "-euo", "pipefail", "-c"]

# create a htpcos virtual machine with a network connection from scratch
setup:
    #!/usr/bin/env bash

    # start virtualisation deamon
    sudo systemctl start libvirtd

    # create and start a network for the vm to connect to
    cat > /tmp/{{ net_name }}.xml <<-'XML'
    <network>
        <name>{{ net_name }}</name>
        <forward mode='nat'>
            <nat>
                <port start='1024' end='65535'/>
            </nat>
        </forward>
        <bridge name='virbr1' stp='on' delay='0'/>
        <ip address='192.168.122.1' netmask='255.255.255.0'>
            <dhcp>
                <range start='192.168.122.100' end='192.168.122.200'/>
            </dhcp>
        </ip>
    </network>
    XML
    sudo virsh net-define /tmp/{{ net_name }}.xml
    rm -f /tmp/{{ net_name }}.xml
    sudo virsh net-start {{ net_name }}

    sudo mkdir -p {{ workdir }}

    # download the arch linux iso and create a vm image
    sudo curl -fL {{ iso_url }} -o {{ workdir }}/archlinux-x86_64.iso
    sudo qemu-img create -f qcow2 {{ workdir }}/arch.qcow2 20G

    # create and start a vm from the arch linux image
    sudo virt-install \
        --name {{ vm_name }} \
        --description 'Home Theatre PC Operating System' \
        --os-variant archlinux \
        --virt-type kvm \
        --ram 4096 \
        --vcpus 2 \
        --disk '{{ workdir }}/arch.qcow2,bus=scsi' \
        --controller type=scsi,model=virtio-scsi \
        --network network={{ net_name }},model=virtio \
        --cdrom {{ workdir }}/archlinux-x86_64.iso \
        --graphics vnc \
        --boot uefi \
        --noautoconsole

    # interface with the vm via a gui
    virt-viewer --connect qemu:///system --wait {{ vm_name }} &

# completely remove the htpcos virtual machine and network
destroy:
    #!/usr/bin/env bash

    # kill the vm process
    sudo virsh destroy {{ vm_name }} 2>/dev/null || true

    # delete the vm instance
    sudo virsh undefine {{ vm_name }} --keep-nvram 2>/dev/null || true

    # kill the network process and interface
    sudo virsh net-destroy {{ net_name }} 2>/dev/null || true

    # delete the network instance
    sudo virsh net-undefine {{ net_name }} 2>/dev/null || true

    sudo rm -rf {{ workdir }}

# run an existing htpcos virtual machine
up:
    #!/usr/bin/env bash

    # start virtualisation deamon
    sudo systemctl start libvirtd

    # start the existing vm
    sudo virsh start {{ vm_name }}

    # interface with the vm via a gui
    virt-viewer --connect qemu:///system --wait {{ vm_name }} &

# gracefully shut down an existing htpcos virtual machine
down:
    #!/usr/bin/env bash

    # gracefully terminate the vm
    sudo virsh shutdown {{ vm_name }}

# display the configuration of htpcos virtual machine
status:
    # display configuration status of the vm if it exists
    sudo virsh dominfo {{ vm_name }} 2>/dev/null || echo 'VM not defined'
