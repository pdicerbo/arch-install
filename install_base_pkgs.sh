#!/bin/bash

input_user="pierluigi"
install_mode="default"

# Override defaults if arguments are provided
if [[ $# -ge 1 ]]; then
    input_user="$1"
fi
if [[ $# -ge 2 ]]; then
    install_mode="$2"
fi

echo -e "\n\tinit operations\n"
echo -e "\n\t  input user: $input_user"
echo -e "\n\t  mode: $install_mode"
sleep 3 # give user time to read input info

set -ex

# set localtime
ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime
hwclock --systohc --utc

# choose locale language
# by commenting the undesired choice
# LOCALE="it_IT.UTF-8"
LOCALE="en_US.UTF-8"

echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen

echo "LANG=$LOCALE" > /etc/locale.conf

# set hostname and hosts
echo "ArchLinux" > /etc/hostname

echo "127.0.0.1   localhost" >> /etc/hosts
echo "::1         localhost" >> /etc/hosts
echo "127.0.1.1   ArchLinux.localdomain	ArchLinux" >> /etc/hosts

# adjust time
# timedatectl set-ntp true

echo -e "\n\tbase system upgrade\n"
# upgrade the system
pacman -Suy --noconfirm

echo -e "\n\tinstall X server packages\n"
# install X server
pacman -S --noconfirm xorg xorg-server xorg-apps

echo -e "\n\tinstall xfce-4 DE\n"
# install xfce-4 DE
pacman -S --noconfirm xfce4 xfce4-goodies

echo -e "\n\tinstall network utilities\n"
pacman -S --noconfirm iw openssh
if [[ $install_mode == "vbox" || $install_mode == "vmware" ]] ; then
    pacman -S --noconfirm wpa_supplicant dialog dhcpcd netctl
elif [[ $install_mode == "default" ]] ; then
    pacman -S --noconfirm iwd
    mkdir /etc/iwd
    echo -e "[General]\nEnableNetworkConfiguration=true\n" > /etc/iwd/main.conf
    echo -e "[Network]\nNameResolvingService=systemd\n" >> /etc/iwd/main.conf
    systemctl enable iwd.service
fi

# install grub
echo -e "\n\tinstall GRUB bootloader\n"
pacman -S --noconfirm grub efibootmgr dosfstools os-prober fuse2
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
sed -i 's/ quiet//' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

echo -e "\n\tinstall base user utilities\n"
# user utils
pacman -S --noconfirm git git-delta sudo awesome conky picom rxvt-unicode urxvt-perls xsel numlockx wget inetutils bind alacritty kitty

echo -e "\n\tinstall base development utils\n"
# development utils
pacman -S --noconfirm gcc clang make cmake linux-headers perl python3 python-pip docker awk vim tmux tldr fzf ncdu neovim go

echo -e "\n\tinstall some control tools\n"
# monitor utils
pacman -S --noconfirm  ctop dive bat btop atop htop iftop iotop procs glances fastfetch

# neovime utils
echo -e "\n\tinstall neovim additional utils\n"
pacman -S --noconfirm ripgrep fd luarocks nodejs npm lazygit lynx

# image & pdf utils
pacman -S --noconfirm ksnip poppler ristretto imagemagick

echo -e "\n\tinstall some fonts\n"
pacman -S --noconfirm ttf-dejavu ttf-dejavu-nerd ttf-nerd-fonts-symbols noto-fonts gnu-free-fonts ttf-anonymous-pro ttf-jetbrains-mono-nerd


echo -e "\n\tinstall audio utils\n"
# audio utils
pacman -S --noconfirm pipewire wireplumber pipewire-pulse pamixer cava

echo -e "\n\tenabling/starting docker service\n"
systemctl enable docker.service
systemctl start  docker.service

if [[ $install_mode == "vbox" ]] ; then
    echo -e "\n\tinstall virtualbox utils\n"
    pacman -S --noconfirm virtualbox-guest-utils

    echo -e "\n\tenabling/starting vbox service\n"
    systemctl enable vboxservice.service
    systemctl start  vboxservice.service

    echo -e "\n\tadding default shared folder into /etc/fstab\n"
    echo "shared  /mnt/shared  vboxsf  uid=1000,gid=1000,rw,dmode=700,fmode=600,noauto,x-systemd.automount" >> /etc/fstab
elif [[ $install_mode == "vmware" ]] ; then
    echo -e "\n\tinstall VMware utils\n"
    pacman -S --noconfirm open-vm-tools xf86-input-vmmouse mesa gtkmm3


    echo -e "\n\tenabling/starting VMware service\n"
    systemctl enable vmtoolsd.service
    systemctl start vmtoolsd.service
    systemctl enable  vmware-vmblock-fuse.service
    systemctl start vmware-vmblock-fuse.service

    mkdir -p /mnt/shared
    echo -e "\n\tadding default shared folder into /etc/fstab\n"
    echo ".host:/VmShared   /mnt/shared fuse.vmhgfs-fuse nofail,allow_other 0 0" >> /etc/fstab
fi

echo -e "\n\tenabling systemd-resolved.service at startup\n"
systemctl enable systemd-resolved.service
systemctl start  systemd-resolved.service

echo -e "\n\tadd new user $input_user\n"
useradd -m --groups root,wheel,docker $input_user

echo -e "$input_user ALL=(ALL) NOPASSWD:ALL\n" > /etc/sudoers.d/$input_user

echo -e "\n\tadd basic user utilities to root user\n"
./user_install.sh "ROOT"

# override some default files
cp Xstuff/root_bashrc $HOME/.bashrc
cp Xstuff/root_bash_profile $HOME/.bash_profile
cp Xstuff/10-monitor.conf   /etc/X11/xorg.conf.d/
cp Xstuff/20-synaptics.conf /etc/X11/xorg.conf.d/

if [[ $install_mode == "vbox" ]] ; then
    echo -e "\n\tadopting the default netctl profile for wired connection..\n"
    cd /etc/netctl/
    cp examples/ethernet-dhcp .
    sed -i 's/Interface=eth0/Interface=enp0s3/' ethernet-dhcp
    netctl enable ethernet-dhcp
    cd -
elif [[ $install_mode == "vmware" ]] ; then
    echo -e "\n\tadopting the default netctl profile for wired connection..\n"
    cd /etc/netctl/
    cp examples/ethernet-dhcp .
    sed -i 's/Interface=eth0/Interface=ens33/' ethernet-dhcp
    netctl enable ethernet-dhcp
    cd -
fi
echo -e "\n\tremember to set the new user [$input_user] and root password!\n\tjust exec the following command:\n\tpasswd [username]\n\n\tthen continue with:\n\tsu $input_user\n\t./user_install.sh\n"
