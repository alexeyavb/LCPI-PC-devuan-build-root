#!/bin/bash -e
. 00!_docker_env.sh
TARGET=kernel_build
docker build  --build-arg UID=$UID --build-arg USERNAME=$USER --build-arg BUILDROOT_RELEASE=$EBR_RELEASE --build-arg UBOOT_RELEASE=$UBT_RELEASE --build-arg LINUX_RELEASE=$LNX_RELEASE \
    -t $DOCKER_ID \
    --target $TARGET \
    -f Dockerfile \
    . \
&& \
docker run --ipc=host  -it --rm \
  -l "${USER}_devuan_t113" \
  -v ${PWD}/:/home/${USER}/buildroot/2024.10/f1c100s_debian/output/rootfs/usr/src/from_host_mapped \
  -v ${PWD}/.builder:/home/${USER}/buildroot/2024.10/f1c100s_debian/output/rootfs/usr/src/from_host_builder \
  ${DOCKER_ID} \
  sudo chroot /home/${USER}/output/rootfs/ /usr/bin/qemu-arm-static /bin/bash

