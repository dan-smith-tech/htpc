#!/bin/bash

set -euo pipefail

# --- cleanup any prior state on the target disk ---
vgscan 2>/dev/null || true
vgchange -an vg_system 2>/dev/null || true
vgremove -f vg_system 2>/dev/null || true
while IFS= read -r part; do
    swapoff "/dev/$part" 2>/dev/null || true
    umount -l "/dev/$part" 2>/dev/null || true
done < <(lsblk -ln -o NAME /dev/sda | tail -n +2)
sleep 1
partx --delete /dev/sda 2>/dev/null || true

sgdisk --zap-all /dev/sda

parted -s /dev/sda \
    mklabel gpt \
    mkpart primary fat32 1MiB 1GiB \
    mkpart primary ext4 1GiB 2GiB \
    mkpart primary ext4 2GiB 100% \
    set 1 esp on \
    set 3 lvm on
sleep 2
partprobe /dev/sda
sleep 5

for part in 1 2 3; do
    wipefs -a "/dev/sda$part" 2>/dev/null || true
done
mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/sda2
LVM_PART=/dev/sda3
dd if=/dev/zero of="$LVM_PART" bs=1M count=100 status=none
wipefs -a "$LVM_PART"
pvcreate --yes --force "$LVM_PART"
vgcreate vg_system "$LVM_PART"
lvcreate -l 100%FREE vg_system -n lv_root
modprobe dm_mod
vgscan
vgchange -ay
mkfs.ext4 /dev/vg_system/lv_root

mount /dev/vg_system/lv_root /mnt
mkdir -p /mnt/boot
mount /dev/sda2 /mnt/boot
mkdir -p /mnt/boot/EFI
mount /dev/sda1 /mnt/boot/EFI

pacstrap /mnt base linux linux-firmware lvm2 networkmanager sudo efibootmgr

genfstab -U /mnt >> /mnt/etc/fstab

cat > /mnt/setup_chroot.sh << 'CHROOT_SCRIPT'
#!/bin/bash

set -eo pipefail

echo "root:passwd" | chpasswd
useradd -m -g users -G tty,input,video,audio,optical,storage,wheel "htpc"
echo "htpc:passwd" | chpasswd

pacman -S --noconfirm base efibootmgr egl-wayland grub linux linux-firmware linux-headers lvm2 networkmanager nvidia-open sudo

echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' >> /etc/sudoers

sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block lvm2 filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -p linux

sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

mkdir -p /boot/EFI
mount /dev/sda1 /boot/EFI
grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub
mkdir -p /boot/grub/locale
cp /usr/share/locale/en\\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo 2>/dev/null || true
grub-mkconfig -o /boot/grub/grub.cfg

mkdir -p /hostshare
echo 'hostshare /hostshare virtiofs defaults 0 0' >> /etc/fstab

systemctl enable NetworkManager
CHROOT_SCRIPT

chmod +x /mnt/setup_chroot.sh
arch-chroot /mnt /setup_chroot.sh
rm /mnt/setup_chroot.sh

umount -R /mnt
reboot
