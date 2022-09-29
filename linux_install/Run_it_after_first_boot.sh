#!/bin/bash
set -e 
set -x

#
# 在第一次boot 成功後, 請執行這個script, 以完成完整的安裝
# 參考文件: https://openzfs.github.io/openzfs-docs/Getting%20Started/Ubuntu/Ubuntu%2020.04%20Root%20on%20ZFS.html

#
# 使用前, 請修改下列參數
#
# (1) 使用者名稱
username=YOUR_USERNAME

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
# 檢查是否具有root 權限
#
if [ $EUID -ne 0 ]; then
  echo "this tool must be run as root"
  exit_process 1
fi

#
# Install GRUB to additional disks
#
dpkg-reconfigure grub-efi-amd64


#
# Create a user account
#
UUID=$(dd if=/dev/urandom bs=1 count=100 2>/dev/null | tr -dc 'a-z0-9' | cut -c-6)
ROOT_DS=$(zfs list -o name | awk '/ROOT\/ubuntu_/{print $1;exit}')
zfs create -o com.ubuntu.zsys:bootfs-datasets=$ROOT_DS \
    -o canmount=on -o mountpoint=/home/$username \
    rpool/USERDATA/${username}_$UUID
adduser $username
cp -a /etc/skel/. /home/$username
chown -R $username:$username /home/$username
usermod -a -G adm,cdrom,dip,lpadmin,lxd,plugdev,sambashare,sudo $username

#
# Full Software Installation
#
apt dist-upgrade --yes
apt install --yes ubuntu-standard

#
# 若要安裝桌面環境, 請使用下列指令
# apt install --yes ubuntu-desktop
#

pause "Press any key to reboot.."
reboot
