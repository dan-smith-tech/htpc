vm_name := "htpcos"
workdir := "/var/lib/libvirt/images/htpcos"
iso_url := "https://mirrors.kernel.org/archlinux/iso/latest/archlinux-x86_64.iso"
net_name := "nat-net"

set shell := ["bash", "-euo", "pipefail", "-c"]

setup:
    #!/usr/bin/env bash

    systemctl is-active --quiet libvirtd || sudo systemctl start libvirtd

    if ! sudo virsh net-list --all --name | grep -qx '{{ net_name }}'; then
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
    fi

    if ! sudo virsh net-list --name | grep -qx '{{ net_name }}'; then
    	sudo virsh net-start {{ net_name }}
    fi

    sudo mkdir -p {{ workdir }}

    if [ ! -f {{ workdir }}/archlinux-x86_64.iso ]; then
    	sudo curl -fL {{ iso_url }} -o {{ workdir }}/archlinux-x86_64.iso
    fi

    if [ ! -f {{ workdir }}/arch.qcow2 ]; then
    	sudo qemu-img create -f qcow2 {{ workdir }}/arch.qcow2 20G
    fi

    if ! sudo virsh list --all --name | grep -qx '{{ vm_name }}'; then
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
    fi

    if ! sudo virsh domstate {{ vm_name }} | grep -qx 'running'; then
    	sudo virsh start {{ vm_name }}
    fi

    sleep 2
    virt-viewer --connect qemu:///system --wait {{ vm_name }} &

destroy:
    #!/usr/bin/env bash
    sudo virsh destroy {{ vm_name }} 2>/dev/null || true
    sudo virsh undefine {{ vm_name }} --keep-nvram 2>/dev/null || true
    sudo virsh net-destroy {{ net_name }} 2>/dev/null || true
    sudo virsh net-undefine {{ net_name }} 2>/dev/null || true
    sudo rm -rf {{ workdir }}

up:
    #!/usr/bin/env bash
    systemctl is-active --quiet libvirtd || sudo systemctl start libvirtd
    if sudo virsh domstate {{ vm_name }} | grep -qE 'shut off|shutdown'; then
    	sudo virsh start {{ vm_name }}
    fi
    sleep 2
    virt-viewer --connect qemu:///system --wait {{ vm_name }} &

down:
    #!/usr/bin/env bash
    sudo virsh shutdown {{ vm_name }}
    sleep 15
    if ! sudo virsh domstate {{ vm_name }} | grep -qE 'shut off|shutdown'; then
    	sudo virsh destroy {{ vm_name }}
    fi

restart:
    just down
    sleep 15
    just up

status:
    sudo virsh dominfo {{ vm_name }} 2>/dev/null || echo 'VM not defined'
