ARG UID
ARG USERNAME
ARG BUILDROOT_RELEASE
ARG UBOOT_RELEASE

FROM ubuntu:24.04 AS base
LABEL maintainer="Alexey Barnukoff <barnukoff@gmail.com> "
LABEL homepage="https://github.com/alexeyavb"
LABEL license="GPL3"

ARG UID
ARG USERNAME
ARG BUILDROOT_RELEASE

# ENV Settings
ENV HOME=/home/${USERNAME}
ENV FORCE_UNSAFE_CONFIGURE=1
ENV DEBIAN_FRONTEND=noninteractive

# cache apt-get update results
RUN apt-get update --fix-missing

# install build prerequisites
# @todo remove python3-distutils after upgrading U-Boot
RUN apt-get install -qy \
    bc \
    bison \
    build-essential \
    bzr \
    chrpath \
    cpio \
    cvs \
    devscripts \
    diffstat \
    fakeroot \
    flex \
    gawk \
    git \
    libncurses5-dev \
    libssl-dev \
    locales \
    python3-dev \
    python3-setuptools \
    python3-pyelftools \
    python3-unidecode \
    python3-coloredlogs \
    python3-yamlordereddictloader \
    yamllint \
    rsync \
    subversion \
    swig \
    texinfo \
    unzip \
    wget \
    whiptail \
    nano \
    sudo \
    mtools \
    xxd

RUN echo 'tzdata tzdata/Areas select Europe' | debconf-set-selections \
    && echo 'tzdata tzdata/Zones/Europe select Paris' | debconf-set-selections
RUN DEBIAN_FRONTEND="noninteractive" apt-get install -qy \
    tzdata pkg-config libconfuse-dev mtools dosfstools mc \
    libcurl4-gnutls-dev libjwt-gnutls-dev libneon27-gnutls-dev \
    && update-locale LC_ALL=C
RUN DEBIAN_FRONTEND="noninteractive" apt-get install -qy \
    gcc-arm-none-eabi \
    gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf

RUN useradd --uid ${UID} --create-home --shell /bin/bash -G sudo,root ${USERNAME} \
    && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# external toolchain needs this
RUN update-locale LC_ALL=C
USER ${USERNAME}
WORKDIR ${HOME}


FROM base AS devuan_bootstrap
ARG UID
ARG UID
ARG UBOOT_RELEASE
ARG USERNAME
ARG LINUX_RELEASE
ENV HOME=/home/${USERNAME}

WORKDIR ${HOME}/buildroot/${BUILDROOT_RELEASE}
RUN sudo apt install -qy \
     debian-keyring gawk diffstat unzip texinfo \
     chrpath socat lzop \
     debootstrap qemu-user-static

WORKDIR ${HOME}/output/rootfs
RUN export DEBIAN_FRONTEND='noninteractive' \
	&& sudo debootstrap --no-check-gpg --variant=minbase --components=main \
    --include=console-setup,fonts-terminus,nano,locales,zip,unzip,dialog,makedev,sudo,dosfstools \
    --exclude=systemd-systemv,systemd,ca-certificates \
    --arch=armhf stable ${HOME}/output/rootfs \
    http://deb.devuan.org/merged/

RUN sudo cp -rv /usr/bin/qemu-arm-static /usr/bin/qemu-armhf-static ${HOME}/output/rootfs/usr/bin/
# RUN sudo chroot ${HOME}/output/rootfs/ /usr/bin/qemu-armhf-static /bin/bash -c "/sbin/debootstrap --second-stage"


RUN sudo chroot ${HOME}/output/rootfs/ /usr/bin/qemu-armhf-static /bin/bash -c "echo 'tzdata tzdata/Areas select Asia' | debconf-set-selections"
RUN sudo chroot ${HOME}/output/rootfs/ /usr/bin/qemu-armhf-static /bin/bash -c "echo 'tzdata tzdata/Zones/Europe select Yekaterinburg' | debconf-set-selections"

RUN sudo chroot ${HOME}/output/rootfs/ /usr/bin/qemu-armhf-static /bin/bash -c "DEBIAN_FRONTEND='noninteractive' apt-get install -qy \
    tzdata pkg-config libconfuse-dev mtools dosfstools mc \
    libcurl4-gnutls-dev libjwt-gnutls-dev libneon27-gnutls-dev \
    "


RUN sudo chroot ${HOME}/output/rootfs/ /usr/bin/qemu-armhf-static /bin/bash -c "DEBIAN_FRONTEND='noninteractive' apt-get -qy install build-essential \
    devuan-keyring libreadline-dev gettext \
    devscripts m4 cmake universal-ctags diffstat bison flex byacc gawk mtools xxd rsync wget i2c-tools spi-tools gpiod libgpiod-dev \
    dosfstools \
    libasound2 libasound2-data libasound2-dev libglib2.0-bin libglib2.0-dev libglib2.0-dev-bin libmp3lame0 libmpg123-0 libogg0 libpcre2-16-0 \
    alsa-ucm-conf alsa-topology-conf dbus libpng-tools libpcre2-32-0 libpcre2-dev libpcre2-posix3 libpkgconf3 libpng-dev libpthread-stubs0-dev \ 
    libz3-4 pkg-config pkgconf pkgconf-bin uuid-dev mc htop nano colormake \
    net-tools kmod iproute2 bc flex yacc bison netscript-2.4 \
    libpng-dev libturbojpeg0-dev libmng-dev \
    inetutils-ping inetutils-traceroute inetutils-tools openssh-server \
    libgbm-dev libmpg123-dev libsamplerate-dev \
    --no-install-recommends"

##	libdbus-1-dev libgl1-mesa-dri genimage libdrm-dev 

RUN sudo chroot ${HOME}/output/rootfs/ /usr/bin/qemu-armhf-static /bin/bash -c "echo root:root | chpasswd"
RUN sudo chroot ${HOME}/output/rootfs/ /usr/bin/qemu-armhf-static /bin/bash -c "useradd --uid ${UID} --create-home -G root,disk,users,i2c,video,render,staff,src,sudo --shell /bin/bash user \
    && echo user:user | chpasswd && adduser user sudo \
    && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers"

RUN sudo chroot ${HOME}/output/rootfs/ /usr/bin/qemu-armhf-static /bin/bash -c \
    "sed -i 's|#T0:23:respawn:/sbin/getty -L ttyS0 9600 vt100|T0:2345:respawn:/sbin/getty -L ttyS3 115200 vt100|g' /etc/inittab"

RUN sudo chroot ${HOME}/output/rootfs/ /usr/bin/qemu-armhf-static /bin/bash -c \
    "sed -i 's|127.0.0.1	localhost|127.0.0.1	localhost	localhost.localdomain	localhost.local	localhost.localdomain.local|g' /etc/hosts"

RUN sudo mv ./etc/fstab ./etc/fstab.dis
COPY <<EOF ./etc/fstab
## proc            /proc           proc    defaults        0       0
devpts          /dev/pts        devpts  defaults,gid=5,mode=620,ptmxmode=0666   0       0
tmpfs           /dev/shm        tmpfs   mode=0777       0       0
tmpfs           /tmp            tmpfs   mode=1777       0       0
tmpfs           /run            tmpfs   mode=0755,nosuid,nodev  0       0
tmpfs		/var/log	tmpfs	mode=0740	0	0
sysfs           /sys            sysfs   defaults        0       0
debugfs		/sys/kernel/debug	debugfs	defaults	0	0
/swapfile.swp   none            swap    none            0       0
EOF

#
# CDC setting-up startup script
COPY <<EOF ./etc/init.d/usbcdcadapter.sh
#! /bin/sh
### BEGIN INIT INFO
# Provides:          usbcdcadapter
# Required-Start:    mountall-bootclean
# Required-Stop:
# Should-Start:      glibc
# Default-Start:     S
# Default-Stop:
# Short-Description: bringing up host usb cdc NDIS network interface with defaut adderss 192.168.131.1 and client 192.168.131.2
# Description:       bringing up host usb cdc NDIS network interface with defaut adderss 192.168.131.1 and client 192.168.131.2
#                    update the kernel sysfs value with this value.
### END INIT INFO

PATH=/sbin:/bin

. /lib/init/vars.sh
. /lib/lsb/init-functions

do_start () {
        [ -d /sys/kernel/config/usb_gadget ] || return
        [ "\$VERBOSE" != no ] && log_action_begin_msg "Setting up USB CDC for usb0"
        mkdir /sys/kernel/config/usb_gadget/g1
        echo "0x1d6b" > /sys/kernel/config/usb_gadget/g1/idVendor
        echo "0x0104" > /sys/kernel/config/usb_gadget/g1/idProduct
        mkdir /sys/kernel/config/usb_gadget/g1/functions/rndis.rn0
        mkdir /sys/kernel/config/usb_gadget/g1/configs/c1.1
        ln -s /sys/kernel/config/usb_gadget/g1/functions/rndis.rn0 /sys/kernel/config/usb_gadget/g1/configs/c1.1/
#         echo "72:00:4c:78:ee:85" > /sys/kernel/config/usb_gadget/g1/configs/c1.1/rndis.rn0/dev_addr
#         echo "72:00:4c:78:ee:86" > /sys/kernel/config/usb_gadget/g1/configs/c1.1/rndis.rn0/host_addr
        echo "musb-hdrc.1.auto" >/sys/kernel/config/usb_gadget/g1/UDC
        ifconfig usb0 192.168.131.1/24 up
        ES=\$\?
        [ "\$VERBOSE" != no ] && log_action_end_msg \$ES
        exit \$ES
}

case "\$1" in
  start|"")
        do_start
        ;;
  restart|reload|force-reload)
        echo "Error: argument '\$1' not supported" >&2
        exit 3
        ;;
  stop)
        # No-op
        ;;
  status)
        exit 0
        ;;
  *)
        echo "Usage: hostname.sh [start|stop]" >&2
        exit 3
        ;;
esac

:

EOF

RUN sudo chmod +x ./etc/init.d/usbcdcadapter.sh

# setting up interface
# CDC setting-up /etc/network/interfaces
COPY <<EOF ./etc/network/interfaces
auto lo
iface lo inet loopback

auto usb0
allow-hotplug usb0
iface usb0 inet static
address 192.168.131.1
netmask 255.255.255.0

auto wlan0
## allow-hotplug wlan0
iface wlan0 inet dhcp
    wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf

EOF

FROM devuan_bootstrap AS kbuilder
ARG UID
ARG UBOOT_RELEASE
ARG USERNAME
ARG LINUX_RELEASE
ENV HOME=/home/${USERNAME}

USER $USERNAME
WORKDIR ${HOME}/src/gpio_f1c100s
RUN git clone https://github.com/wuxx/f1c100s-gpio-tools.git
WORKDIR ${HOME}/src/cedar_lib
RUN git clone https://github.com/aodzip/libcedarc.git
WORKDIR ${HOME}/src/cedarx_05_04
RUN git clone https://github.com/aodzip/cedar.git
WORKDIR ${HOME}/src/cedarx_05_15
RUN git clone -b "5.15.x" https://github.com/Angelic47/cedar.git
WORKDIR ${HOME}/src/cedarx_06_02
RUN git clone -b "6.2.x" https://github.com/Angelic47/cedar.git

#
# Linux kernel 6
WORKDIR ${HOME}/src/linux/${LINUX_RELEASE}
ENV KERNEL_SRC="linux-${LINUX_RELEASE}.tar.gz"
ENV KERNEL_CHL="ChangeLog-${LINUX_RELEASE}"
ENV KERNEL_URL="https://www.kernel.org/pub/linux/kernel/v6.x"
RUN wget -qO- ${KERNEL_URL}/${KERNEL_SRC} | tar --strip-components=1 -xz
RUN wget -q ${KERNEL_URL}/${KERNEL_CHL}

#
# u-boot sources
WORKDIR ${HOME}/src/u-boot/
ENV UBOOT_VER=${UBOOT_RELEASE}
ENV UBOOT_SRC="u-boot-${UBOOT_VER}.tar.bz2"
ENV UBOOT_URL="https://ftp.denx.de/pub/u-boot"
RUN wget -qO- ${UBOOT_URL}/${UBOOT_SRC} | tar --strip-components=1 -xj

#
# NoInTree modules and drivers 
###
# rtl8189fs with kernel tree patch

# WORKDIR ${HOME}/src/linux/${LINUX_RELEASE}
# COPY sources/rtl8189fs.tar.gz ${HOME}/src
# RUN tar -zxf ${HOME}/src/rtl8189fs.tar.gz -C ${HOME}/src/linux/${LINUX_RELEASE}/drivers/net/wireless/realtek/rtl818x/
# COPY patches/network/001-add-rtl8189fs.patch .
# RUN sudo patch -Np1 -i ./001-add-rtl8189fs.patch \
#    && rm -rf ./001-add-rtl8189fs.patch \
#    && echo "kernel nointree driver for8189fs installed"

WORKDIR ${HOME}/src/rtl8189fs/
RUN git clone https://github.com/jwrdegoede/rtl8189ES_linux.git -b rtl8189fs

#
#
# build kernel and u-boot
FROM kbuilder AS kernel_build
ARG UID
ARG UBOOT_RELEASE
ARG USERNAME
ARG LINUX_RELEASE
ENV HOME=/home/${USERNAME}
USER ${USERNAME}
WORKDIR ${HOME}/src/linux/${LINUX_RELEASE}

COPY configs/linux/${LINUX_RELEASE}/sun8i_t113_defconfig ./arch/arm/configs
COPY patches/sound/	.
COPY patches/graphics/	.
COPY patches/devicetree/ .
COPY <<EOF apply_patches.sh
#!/bin/bash -e
for file in *.patch
do
        echo "\$file"
        patch -Np1 -i \$file
done
EOF

RUN sudo chmod +x ./apply_patches.sh \
    && sudo chown user:user ./*.patch ./*.sh \
    && ./apply_patches.sh \
    && echo patches applyed \
    && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- sun8i_t113_defconfig -j`nproc` \
    && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- bzImage -j`nproc` \
    && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- modules dtbs -j`nproc` \
    && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- tarbz2-pkg -j`nproc` \
    && cp arch/arm/boot/dts/allwinner/sun8i-t113s-mangopi-mq-r-t113.dtb ${HOME}/ \
    && cp linux-${LINUX_RELEASE}-arm.tar.bz2 ${HOME}/ \
    && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- \
	INSTALL_HDR_PATH=${HOME}/linux_headers_for_mcu headers_install \
    && cd ${HOME}/linux_headers_for_mcu \
    && tar -jcf ${HOME}/linux-${LINUX_RELEASE}-headers.tar.bz2 .

WORKDIR ${HOME}/src/rtl8189fs/

RUN cd rtl8189ES_linux \
    && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- KSRC=${HOME}/src/linux/${LINUX_RELEASE}

WORKDIR ${HOME}/src/linux/${LINUX_RELEASE}

RUN make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- \
	INSTALL_MOD_PATH=${HOME}/linux_modules_for_mcu modules_install \
    && mkdir -p ${HOME}/linux_modules_for_mcu/lib/modules/${LINUX_RELEASE}/drivers/net/wireless/realtek/rtl818x \
    && cp -r ${HOME}/src/rtl8189fs/rtl8189ES_linux/8189fs.ko ${HOME}/linux_modules_for_mcu/lib/modules/${LINUX_RELEASE}/drivers/net/wireless/realtek/rtl818x \
    && cd ${HOME}/linux_modules_for_mcu \
    && tar -jcf ${HOME}/linux-${LINUX_RELEASE}-modules.tar.bz2 .


RUN rm -rf ${HOME}/linux_*_for_mcu

# build u-boot
WORKDIR ${HOME}/src/u-boot/
RUN make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- mangopi_mq_r_defconfig -j`nproc` \
    && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j`nproc` \
    && cp ./u-boot-sunxi-with-spl.bin ${HOME}

WORKDIR ${HOME}/output/rootfs
#
# set up bootable data
RUN echo "Unpacking compiled kernel..." \
    && mkdir -p prebuild/usr && cd prebuild \
    && sudo tar -jxf ${HOME}/linux-${LINUX_RELEASE}-arm.tar.bz2 \
    && sudo tar -jxf ${HOME}/linux-${LINUX_RELEASE}-modules.tar.bz2 \
    && sudo tar -jxf ${HOME}/linux-${LINUX_RELEASE}-headers.tar.bz2 \
    && sudo mv -fv include/ ../usr/include/ \
    && sudo mv -fv boot/* ../boot/ \
    && sudo mkdir -p ../boot/extlinux \
    && sudo cp -rfv ${HOME}/u-boot-sunxi-with-spl.bin ../boot \
    && sudo cp -rfv ${HOME}/sun8i-t113s-mangopi-mq-r-t113.dtb ../boot \
    && sudo mv -fv lib/* ../lib/ \
    && cd .. && sudo rm -rf prebuild \
    && cd boot \
    && sudo ln -sf vmlinux-kbuild-6.6.71 zImage
COPY <<EOF ./boot/extlinux/extlinux.conf
label LCPI-T113-F133-MQ1RDW2
    kernel /boot/zImage
    devicetree /boot/sun8i-t113s-mangopi-mq-r-t113.dtb
    append console=ttyS3,115200 root=/dev/mmcblk0p1 rootwait panic=10 \${extra}
EOF

# RUN sudo chroot . /usr/bin/qemu-armhf-static /bin/bash -c "depmod -a"

RUN sudo chroot . /usr/bin/qemu-armhf-static /bin/bash -c "cd /etc/rcS.d && ln -s ../init.d/usbcdcadapter.sh S10usbcdcadapter.sh && update-rc.d usbcdcadapter.sh enable S"
RUN sudo chroot . /usr/bin/qemu-armhf-static /bin/bash -c "DEBIAN_FRONTEND='noninteractive' apt-get install -qy wpasupplicant \
     wireless-tools wireless-regdb colordiff colorize colortail colortest tree"
RUN sudo chroot . /usr/bin/qemu-armhf-static /bin/bash -c "echo '8189fs' >>/etc/modules"

COPY <<EOF ./etc/ld.so.conf.d/optlibs.conf
# manually builded libraries
/usr/local/lib
/opt/lib
/opt/SDL

EOF

COPY <<EOF ./root/runwifi.sh
#!/bin/bash
# disable stdout module messages
echo 1 > /proc/sys/kernel/printk
# up wlan0
ip link set dev wlan0 up
wpa_supplicant -c /etc/wpa_supplicant/wpa_supplicant.conf -i wlan0 &
sleep 3
dhclient wlan0
EOF
RUN sudo chmod +x ./root/runwifi.sh

COPY <<EOF ./etc/wpa_supplicant/wpa_supplicant.conf
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=root
#
# home network; allow all valid ciphers
network={ 
    ssid="Xiaomi_Home" 
    scan_ssid=1 
    key_mgmt=WPA-PSK 
    psk="Dpkjvftim7"
}
EOF
RUN sudo chmod 440 ./etc/wpa_supplicant/wpa_supplicant.conf

RUN sudo dd if=/dev/urandom of=swapfile.swp bs=1M count=128 && sudo mkswap swapfile.swp
RUN sudo mkfs.ext4 -d . -r 1 -N 0 -m 5 -L rootfs -I 256 -O ^64bit ${HOME}/output/rootfs.ext4 2G

# FROM kernel_build AS PAUSE
#
# test fake root
# remove after boot
####
## RUN mkdir -p ../fakeroot/boot \
##    && cp -rvf ./boot/* ../fakeroot/boot \
##    && mkfs.ext4 -d ../fakeroot -r 1 -N 0 -m 5 -L rootfs -I 256 -O ^64bit ${HOME}/output/fakerootfs.ext4 64M
####

RUN sudo apt-get -qy install genimage

#
# oldway with boot over boot.scr image
# RUN sudo mkimage -v -A arm -T script -d boot-lcd.cmd boot.scr


RUN ln -s ${HOME}/u-boot-sunxi-with-spl.bin .
COPY <<EOF genimage.cfg
image sdcard.img {
        hdimage {
        }

        partition u-boot {
                in-partition-table = "no"
                image = "${HOME}/u-boot-sunxi-with-spl.bin"
                offset = 8K
                size = 1016K # 1MB - 8KB
        }

        partition rootfs {
                partition-type = 0x83
##                image = "${HOME}/output/fakerootfs.ext4"
                image = "${HOME}/output/rootfs.ext4"
        }
}
EOF
RUN sudo rm -rf ./.genimg \
     && sudo mkdir -p ./.genimg/root \
     && sudo genimage --rootpath ".genimg/root" --tmppath ".genimg/tmp" --inputpath "." --outputpath ".genimg/output" --config "genimage.cfg"
RUN sudo mv .genimg/output/sdcard.img ${HOME}/output

WORKDIR ${HOME}

#
# kernel image
FROM scratch AS kernel_dis
ARG USERNAME
ENV HOME=/home/${USERNAME}
COPY --from=kernel_build ${HOME}/output/sdcard.img .
