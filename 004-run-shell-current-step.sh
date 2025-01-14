#!/bin/bash -e
. 00!_docker_env.sh
docker build  --build-arg UID=$UID --build-arg USERNAME=$USER --build-arg BUILDROOT_RELEASE=$EBR_RELEASE --build-arg UBOOT_RELEASE=$UBT_RELEASE --build-arg LINUX_RELEASE=$LNX_RELEASE \
    -t $DOCKER_ID \
    --target $TARGET \
    -f Dockerfile \
    .			\
&& \
docker run --ipc=host  -it --rm \
  -l "${USER}_devuan_t113" \
  -v ${PWD}/:/home/${USER}/from_host_mapped \
  ${DOCKER_ID} \
  /bin/bash
