#!/bin/bash
set -e 
#set -x

#
# 這個script 會自動建立 ubuntu ZFS system, 不加密
# 開機環境: Ubuntu 20.04 live CD
# 參考文件: https://openzfs.github.io/openzfs-docs/Getting%20Started/Ubuntu/Ubuntu%2020.04%20Root%20on%20ZFS.html

#
# 使用前, 請修改下列參數
#
# (1) HDD 路徑&名稱
#DISK1=/dev/disk/by-path/pci-0000:00:10.0-scsi-0:0:0:0
DISK1=/dev/disk/by-id/ata-VBOX_HARDDISK_VBe9f4c3b5-0ee66ce2

# (2) ZFS UUID (可以不用修改, 用亂數產生)
ZFS_UUID=FW

# (3) Hostname for new system
NEW_SYSTEM_HOSTNAME=build-code-srv2

# (4) Name of default network interface
NETWORK_INTERFACE=enp0s3

#
# Functions
#
function exit_process () {
  exit $1
}

function pause(){
    read -n 1 -p "$*" INP
    if [ $INP != '' ] ; then
            echo -ne '\b \n'
    fi
}

#
# Start
#
THIS_SCRIPT=`echo $0 | sed "s/^.*\///"`
SCRIPT_PATH=`echo $0 | sed "s/\/${THIS_SCRIPT}$//"`
curr_dir=`pwd`

#
# 檢查是否具有root 權限
#
if [ $EUID -ne 0 ]; then
  echo "this tool must be run as root"
  exit_process 1
fi

#
# 建立 root 密碼
#
echo "** Build ROOT password"
passwd

#
# disable automounting
#
gsettings set org.gnome.desktop.media-handling automount false

#
# 安裝一些必要套件
#
echo "** Install necessary packages"
apt update
apt install --yes openssh-server vim
apt install --yes util-linux
apt install --yes debootstrap gdisk zfsutils-linux

#
# 停止 zed
#
systemctl stop zed

#
# 關閉 swap
#
swapoff --all

#
# 清除硬碟內容
#
set +e 
wipefs -a -f ${DISK1}*
set -e 

sleep 3

sgdisk --zap-all ${DISK1}

sleep 3

dd if=/dev/zero of=${DISK1} bs=1M count=1000

sleep 3

set +e 
wipefs -a -f ${DISK1}*
set -e 

sleep 3

sgdisk --zap-all ${DISK1}

#
# 建立 partition
#
# (1) bootloader partition (512MB)
sgdisk     -n1:1M:+512M   -t1:EF00 ${DISK1}

# For legacy (BIOS) booting:
sgdisk -a1 -n5:24K:+1000K -t5:EF02 ${DISK1}

# (2) boot pool partition (2GB)
sgdisk     -n2:0:+2G      -t2:BE00 ${DISK1}

# (3) root pool partition (all left size)
sgdisk     -n3:0:0        -t3:BF00 ${DISK1}


sleep 3
#
# 建立 zpool
#
# (1) 建立 boot pool
echo "Create boot pool.."
zpool create \
    -o cachefile=/etc/zfs/zpool.cache \
    -o ashift=12 -o autotrim=on -d \
    -o feature@async_destroy=enabled \
    -o feature@bookmarks=enabled \
    -o feature@embedded_data=enabled \
    -o feature@empty_bpobj=enabled \
    -o feature@enabled_txg=enabled \
    -o feature@extensible_dataset=enabled \
    -o feature@filesystem_limits=enabled \
    -o feature@hole_birth=enabled \
    -o feature@large_blocks=enabled \
    -o feature@lz4_compress=enabled \
    -o feature@spacemap_histogram=enabled \
    -O acltype=posixacl -O canmount=off -O compression=lz4 \
    -O devices=off -O normalization=formD -O relatime=on -O xattr=sa \
    -O mountpoint=/boot -R /mnt \
    bpool ${DISK1}-part2
    

# (2) 建立 root pool
echo "Create root pool.."
zpool create \
    -o ashift=12 -o autotrim=on \
    -O acltype=posixacl -O canmount=off -O compression=lz4 \
    -O dnodesize=auto -O normalization=formD -O relatime=on \
    -O xattr=sa -O mountpoint=/ -R /mnt \
    rpool ${DISK1}-part3


sleep 3
#
# 建立 zfs
#
# (1) Create filesystem datasets to act as containers
zfs create -o canmount=off -o mountpoint=none rpool/ROOT
zfs create -o canmount=off -o mountpoint=none bpool/BOOT

# (2) Create filesystem datasets for the root and boot filesystems
zfs create -o mountpoint=/ \
    -o com.ubuntu.zsys:bootfs=yes \
    -o com.ubuntu.zsys:last-used=$(date +%s) rpool/ROOT/ubuntu_${ZFS_UUID}

zfs create -o mountpoint=/boot bpool/BOOT/ubuntu_${ZFS_UUID}

# (3) Create datasets for OS directories.
zfs create -o com.ubuntu.zsys:bootfs=no \
    rpool/ROOT/ubuntu_${ZFS_UUID}/srv
zfs create -o com.ubuntu.zsys:bootfs=no -o canmount=off \
    rpool/ROOT/ubuntu_${ZFS_UUID}/usr
zfs create rpool/ROOT/ubuntu_${ZFS_UUID}/usr/local
zfs create -o com.ubuntu.zsys:bootfs=no -o canmount=off \
    rpool/ROOT/ubuntu_${ZFS_UUID}/var

zfs create rpool/ROOT/ubuntu_${ZFS_UUID}/var/games
zfs create rpool/ROOT/ubuntu_${ZFS_UUID}/var/lib
zfs create rpool/ROOT/ubuntu_${ZFS_UUID}/var/lib/AccountsService
zfs create rpool/ROOT/ubuntu_${ZFS_UUID}/var/lib/apt
zfs create rpool/ROOT/ubuntu_${ZFS_UUID}/var/lib/dpkg
zfs create rpool/ROOT/ubuntu_${ZFS_UUID}/var/lib/NetworkManager
zfs create rpool/ROOT/ubuntu_${ZFS_UUID}/var/log
zfs create rpool/ROOT/ubuntu_${ZFS_UUID}/var/mail
zfs create rpool/ROOT/ubuntu_${ZFS_UUID}/var/snap
zfs create rpool/ROOT/ubuntu_${ZFS_UUID}/var/spool
zfs create rpool/ROOT/ubuntu_${ZFS_UUID}/var/www

# (4) Create datasets for USER datas
zfs create -o canmount=off -o mountpoint=/ \
    rpool/USERDATA
zfs create -o com.ubuntu.zsys:bootfs-datasets=rpool/USERDATA/ubuntu_${ZFS_UUID} \
    -o canmount=on -o mountpoint=/root \
    rpool/USERDATA/root_${ZFS_UUID}

zfs create -o com.ubuntu.zsys:bootfs-datasets=rpool/USERDATA/ubuntu_${ZFS_UUID} \
    -o canmount=on -o mountpoint=/home \
    rpool/USERDATA/home_${ZFS_UUID}

chmod 700 /mnt/root
    
# (5) Create datasets for /boot/grub
zfs create -o com.ubuntu.zsys:bootfs=no bpool/grub

# (6) Create datasets for /tmp
zfs create -o com.ubuntu.zsys:bootfs=no \
    rpool/ROOT/ubuntu_${ZFS_UUID}/tmp
chmod 1777 /mnt/tmp

#
# Create /mnt/run (mount a tempfs)
#
mkdir /mnt/run
mount -t tmpfs tmpfs /mnt/run
mkdir /mnt/run/lock

#
# Install the minimal system
#
debootstrap focal /mnt

#
# Copy in zpool.cache
#
mkdir /mnt/etc/zfs
cp /etc/zfs/zpool.cache /mnt/etc/zfs/

#
# Configuration for new System
#
# (1) HOSTNAME
hostname ${NEW_SYSTEM_HOSTNAME}
hostname > /mnt/etc/hostname

echo >> /mnt/etc/hosts
echo 127.0.1.1   ${NEW_SYSTEM_HOSTNAME} >> /mnt/etc/hosts
echo >> /mnt/etc/hosts

# (2) network interface
cat << EOF > /mnt/etc/netplan/01-netcfg.yaml
network:
  version: 2
  ethernets:
    ${NETWORK_INTERFACE}:
      dhcp4: true
EOF

# (3) Configure the package sources
cat << EOF > /mnt/etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu focal main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu focal-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu focal-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu focal-security main restricted universe multiverse
EOF
    
#
# Create second stage shell script for chroot
#
cat << EOF > /mnt/root/chroot_second_stage.sh
#!/bin/bash
#set -e
set -x

#
# Configure a basic system environment
#
apt update
dpkg-reconfigure locales tzdata keyboard-configuration console-setup
apt install --yes nano
apt install --yes vim
apt install --yes openssh-server
apt install --yes psmisc
apt install --yes dosfstools

#
# Create the EFI filesystem
#
mkdosfs -F 32 -s 1 -n EFI ${DISK1}-part1
EFI_BLKID=\$(blkid -s UUID -o value ${DISK1}-part1)
echo EFI EFI_BLKID = \${EFI_BLKID}
mkdir /boot/efi
echo /dev/disk/by-uuid/\${EFI_BLKID} /boot/efi vfat defaults 0 0 >> /etc/fstab
mount /dev/disk/by-uuid/\${EFI_BLKID} /boot/efi

#
# Install GRUB/Linux/ZFS in the chroot environment for the new system
#
# Choose one of below boot method
# (1) For Legacy (BIOS) booting
#apt install --yes grub-pc linux-image-generic zfs-initramfs

# (2) For EFI booting
apt install --yes \
    grub-efi-amd64 grub-efi-amd64-signed linux-image-generic \
    shim-signed zfs-initramfs

echo "Set root password for new system"
passwd

#
# Mount a tmpfs to /tmp
#
cp /usr/share/systemd/tmp.mount /etc/systemd/system/
systemctl enable tmp.mount

#
# Setup system groups
#
addgroup --system lpadmin
addgroup --system lxd
addgroup --system sambashare

#
# setup sshd config
#
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config


#
# GRUB installation
#
# (1) Verify that the ZFS boot filesystem is recognized
grub-probe /boot

# (2) Refresh the initrd files
#
update-initramfs -c -k all

# (3) Disable memory zeroing.
# Add init_on_alloc=0 to: GRUB_CMDLINE_LINUX_DEFAULT  in /etc/default/grub
sed -i -e 's/^\(GRUB_CMDLINE_LINUX_DEFAULT=\"\)\(.*\)\"/\1\2 init_on_alloc=0\"/g' /etc/default/grub

# (4) Optional (but highly recommended): Make debugging GRUB easier 
# 4.1 Remove splash quiet in GRUB_CMDLINE_LINUX_DEFAULT of /etc/default/grub
# 4.2 Comment out: GRUB_TIMEOUT_STYLE=hidden
# 4.3 Set: GRUB_TIMEOUT=5, below GRUB_TIMEOUT set GRUB_RECORDFAIL_TIMEOUT=5
# 4.4 Uncomment: GRUB_TERMINAL=console
sed -i -e 's/^\(GRUB_CMDLINE_LINUX_DEFAULT=.*\)splash\ *\(.*\)\"/\1\2"/g' /etc/default/grub
sed -i -e 's/^\(GRUB_CMDLINE_LINUX_DEFAULT=.*\)quiet\ *\(.*\)\"/\1\2"/g' /etc/default/grub
sed -i -e 's/^GRUB_TIMEOUT_STYLE=hidden/#GRUB_TIMEOUT_STYLE=hidden/g' /etc/default/grub
sed -i -e 's/^GRUB_TIMEOUT=0/GRUB_TIMEOUT=5\nGRUB_RECORDFAIL_TIMEOUT=5/g' /etc/default/grub
sed -i -e 's/^#GRUB_TERMINAL=console/GRUB_TERMINAL=console/g' /etc/default/grub

# (4) Update the boot configuration
update-grub

#
# Install the boot loader
#
# Choose one of below boot method
# (1) For Legacy (BIOS) booting
#grub-install $DISK1

# (2) For EFI booting
grub-install --target=x86_64-efi --efi-directory=/boot/efi \
    --bootloader-id=ubuntu --recheck --no-floppy

#
# Disable grub-initrd-fallback.service
#
systemctl mask grub-initrd-fallback.service

#
# Fix filesystem mount ordering
#
mkdir /etc/zfs/zfs-list.cache
touch /etc/zfs/zfs-list.cache/bpool
touch /etc/zfs/zfs-list.cache/rpool
ln -s /usr/lib/zfs-linux/zed.d/history_event-zfs-list-cacher.sh /etc/zfs/zed.d
zed -F &

sleep 3

zfs set canmount=on bpool/BOOT/ubuntu_${ZFS_UUID}
sleep 3
cat /etc/zfs/zfs-list.cache/bpool

zfs set canmount=on rpool/BOOT/ubuntu_${ZFS_UUID}
sleep 3
cat /etc/zfs/zfs-list.cache/rpool

killall -9 zed

sed -Ei "s|/mnt/?|/|" /etc/zfs/zfs-list.cache/*

EOF
chmod +x /mnt/root/chroot_second_stage.sh

#
# Bind the virtual filesystems from the LiveCD environment to the new system and chroot into it
#
mount --make-private --rbind /dev  /mnt/dev
mount --make-private --rbind /proc /mnt/proc
mount --make-private --rbind /sys  /mnt/sys
chroot /mnt /usr/bin/env DISK1=${DISK1} ZFS_UUID=${ZFS_UUID} bash -c /root/chroot_second_stage.sh

#
# Unmount all filesystem in the LiveCD environment
#
mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | \
    xargs -i{} umount -lf {}
zpool export -a

echo "Done.. You can reboot the system"
