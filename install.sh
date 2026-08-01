# enable the virtualisation daemon
sudo systemctl start libvirtd

# assign a free subnet to the virtual machine so it can access the LAN and internet
NAT_NET_XML=/tmp/nat-net.xml
cat > "$NAT_NET_XML" <<'EOF'
<network>
  <name>nat-net</name>
  <forward mode="nat">
    <nat>
      <port start="1024" end="65535"/>
    </nat>
  </forward>
  <bridge name="virbr1" stp="on" delay="0"/>
  <ip address="192.168.122.1" netmask="255.255.255.0">
    <dhcp>
      <range start="192.168.122.100" end="192.168.122.200"/>
    </dhcp>
  </ip>
</network>
EOF

# register and start the NAT network
sudo virsh net-define "$NAT_NET_XML"
sudo virsh net-start nat-net
virsh net-list --all
rm -f "$NAT_NET_XML"

# set image settings
VM_NAME="htpcos"
VM_DESCRIPTION="Home Theatre PC Operating System"
VM_RAM="4096"
VM_VCPUS="2"
WORKDIR="/var/lib/libvirt/images/htpcos"
DISK_IMAGE="${WORKDIR}/arch.qcow2"
ARCH_ISO_URL="https://mirrors.kernel.org/archlinux/iso/latest/archlinux-x86_64.iso"
ARCH_ISO="${WORKDIR}/archlinux-x86_64.iso"

# prepare the disk image and download the installation media
sudo mkdir -p "$WORKDIR"
if [ ! -f "$ARCH_ISO" ]; then
  sudo curl -fL "$ARCH_ISO_URL" -o "$ARCH_ISO"
fi
if [ ! -f "$DISK_IMAGE" ]; then
  sudo qemu-img create -f qcow2 "$DISK_IMAGE" 20G
fi

# create the virtual machine
sudo virt-install \
  --name "$VM_NAME" \
  --description "$VM_DESCRIPTION" \
  --os-variant=generic \
  --virt-type kvm \
  --ram "$VM_RAM" \
  --vcpus "$VM_VCPUS" \
  --disk "${DISK_IMAGE},bus=scsi" \
  --controller type=scsi,model=virtio-scsi \
  --network network=nat-net,model=virtio \
  --cdrom "$ARCH_ISO" \
  --graphics vnc \
  --boot uefi
