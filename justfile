vm_name := "htpc"
workdir := "/var/lib/libvirt/images/htpc"
net_name := "nat-net"
isobuild := "/var/lib/libvirt/images/htpc/isobuild"
arch_install_script := "htpcinstall.sh"
hostshare := justfile_dir() + "/htpc"

set shell := ["bash", "-euo", "pipefail", "-c"]

# create a htpc virtual machine with a network connection from scratch
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

    # create and populate custom archiso profile from releng
    sudo rm -rf {{ isobuild }}
    sudo cp -r /usr/share/archiso/configs/releng {{ isobuild }}

    # copy install script into the live filesystem at /root/htpcinstall.sh
    sudo install -Dm755 {{ arch_install_script }} {{ isobuild }}/airootfs/root/htpcinstall.sh

    # add script= boot parameter to UEFI bootloader config
    sudo sed -i '/^options / s|$| script=/root/htpcinstall.sh|' \
        {{ isobuild }}/efiboot/loader/entries/01-archiso-linux.conf

    # add script= boot parameter to BIOS bootloader config
    sudo sed -i '/^APPEND / s|$| script=/root/htpcinstall.sh|' \
        {{ isobuild }}/syslinux/archiso_sys-linux.cfg

    # set file permissions for the installer script in profiledef.sh
    if ! grep -q '/root/htpcinstall.sh' {{ isobuild }}/profiledef.sh; then
        sudo sed -i '/^file_permissions=(/a\\  ["/root/htpcinstall.sh"]="0:0:755"' {{ isobuild }}/profiledef.sh
    fi

    # build the custom ISO
    sudo mkarchiso -v -w {{ workdir }}/build -o {{ workdir }} {{ isobuild }}

    # resolve the generated ISO (avoid hardcoding versioned filenames) and move into place
    sudo bash -c 'mv "$(find {{ workdir }} -maxdepth 1 -name "archlinux-*.iso" | head -n 1)" {{ workdir }}/archlinux-custom.iso'

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
        --cdrom {{ workdir }}/archlinux-custom.iso \
        --graphics vnc \
        --boot uefi \
        --filesystem='{{ hostshare }},hostshare,driver.type=virtiofs' \
        --memorybacking=source.type=memfd,access.mode=shared \
        --noautoconsole

    # interface with the vm via a gui
    virt-viewer --connect qemu:///system --wait {{ vm_name }} &

# completely remove the htpc virtual machine and network
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

    sudo rm -rf {{ isobuild }}
    sudo rm -rf {{ workdir }}

# run the existing htpc virtual machine
up:
    #!/usr/bin/env bash

    # start virtualisation deamon
    sudo systemctl start libvirtd

    # start the existing vm
    sudo virsh start {{ vm_name }}

    # interface with the vm via a gui
    virt-viewer --connect qemu:///system --wait {{ vm_name }} &

# gracefully shut down the existing htpc virtual machine
down:
    #!/usr/bin/env bash

    # gracefully terminate the vm
    sudo virsh shutdown {{ vm_name }}

# display the configuration of the htpc virtual machine
status:
    # display configuration status of the vm if it exists
    sudo virsh dominfo {{ vm_name }} 2>/dev/null || echo 'VM not defined'
