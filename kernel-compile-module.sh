#!/bin/bash

##Set branch to pull from for dependencies
set -ea

: "${DEPENDENCY_BRANCH:=master}"

##Pull variables from github
wget -nc https://raw.githubusercontent.com/linuxserver/Unraid-Dependencies/${DEPENDENCY_BRANCH}/build_scripts/variables.sh
wget -nc https://raw.githubusercontent.com/linuxserver/Unraid-Dependencies/${DEPENDENCY_BRANCH}/build_scripts/dvb-variables.sh

source ./variables.sh

if [[ -z "$D" ]]; then
    echo "Must provide D in environment" 1>&2
    exit 1
fi

source ${D}/dvb-variables.sh

##Grab Slackware packages
echo -e "${BLUE}Kernel Compile Module${NC}    -----    Install packages"
[ ! -d "${D}/packages" ] && mkdir ${D}/packages
  wget -nc -P ${D}/packages -i ${D}/URLS_CURRENT
  if [[ $? != 0 ]]; then
    echo "Package missing. Exiting..."
    exit 1
  fi

##Pull patchutils & ProcessTable
  wget -nc -P ${D}/packages https://github.com/linuxserver/Unraid-Dependencies/raw/${DEPENDENCY_BRANCH}/files/patchutils-0.3.4-x86_64-4.tgz
  wget -nc -P ${D}/packages https://github.com/linuxserver/Unraid-Dependencies/raw/${DEPENDENCY_BRANCH}/files/Proc-ProcessTable-0.53-x86_64-4.tgz

##Pull static gcc deps
  wget -nc -P ${D}/packages https://github.com/linuxserver/Unraid-Dependencies/raw/${DEPENDENCY_BRANCH}/gcc/gcc-8.3.0-x86_64-1.txz
  wget -nc -P ${D}/packages https://github.com/linuxserver/Unraid-Dependencies/raw/${DEPENDENCY_BRANCH}/gcc/gcc-g++-8.3.0-x86_64-1.txz

##Install packages  
installpkg ${D}/packages/*.*

#Change to current directory
echo -e "${BLUE}Kernel Compile Module${NC}    -----    Change to current directory"
cd ${D}

##Unmount bzmodules and make rw
echo -e "${BLUE}Kernel Compile Module${NC}    -----    Unmount bzmodules and make rw"
cp -r /lib/modules /tmp
umount -l /lib/modules/
rm -rf  /lib/modules
mv -f  /tmp/modules /lib

##Unmount bzfirmware and make rw
echo -e "${BLUE}Kernel Compile Module${NC}    -----    Unmount bzfirmware and make rw"
cp -r /lib/firmware /tmp
umount -l /lib/firmware/
rm -rf  /lib/firmware
mv -f  /tmp/firmware /lib


##Download and Install Kernel
echo -e "${BLUE}Kernel Compile Module${NC}    -----    Download and Install Kernel"
[[ $(uname -r) =~ ([0-9.]*) ]] &&  KERNEL=${BASH_REMATCH[1]} || return 1
 LINK="https://www.kernel.org/pub/linux/kernel/v${KERNEL:0:1}.x/linux-${KERNEL}.tar.xz"
 rm -rf ${D}/kernel; mkdir ${D}/kernel
 [[ ! -f ${D}/linux-${KERNEL}.tar.xz ]] && wget ${LINK} -O ${D}/linux-${KERNEL}.tar.xz
 tar -C ${D}/kernel --strip-components=1 -Jxf ${D}/linux-${KERNEL}.tar.xz
 rsync -av /usr/src/linux-$(uname -r)/ ${D}/kernel/
 cd ${D}/kernel
 for p in $(find . -type f -iname "*.patch"); do patch -N -p 1 < $p
 done
 make oldconfig

##Make menuconfig
echo -e "${BLUE}Kernel Compile Module${NC}    -----    Make menuconfig"
cd ${D}
#if wget --spider https://lsio.ams3.digitaloceanspaces.com/unraid-dvb/${UNRAID_VERSION}/stock/.config 2>/dev/null; then
#   rm -f .config
#   wget https://lsio.ams3.digitaloceanspaces.com/unraid-dvb/${UNRAID_VERSION}/stock/.config
   rsync ${D}/.config ${D}/kernel/.config
#else
#   cd ${D}/kernel
#   make menuconfig
#fi

##Compile Kernel
echo -e "${BLUE}Kernel Compile Module${NC}    -----    Compile Kernel"
cd ${D}/kernel
make -j $(grep -c ^processor /proc/cpuinfo)

##Install Kernel Modules
echo -e "${BLUE}Kernel Compile Module${NC}    -----    Install Kernel Modules"
cd ${D}/kernel
make all modules_install install

IFS=',' read -r -a oot_drivers <<< "${OOT_DRIVERS}"

for each in "${oot_drivers[@]}"
do
	echo -e "${BLUE}Kernel Compile Module${NC}    -----    Going to compile $each"
done

if [[ " ${oot_drivers[@]} " =~ " rocketraid " ]]; then
     #Install Rocketraid R750
    echo -e "${BLUE}Kernel Compile Module${NC}    -----    Install Rocketraid R750"
    mkdir -p /usr/src/drivers/highpoint
    cd /usr/src/drivers/highpoint
    wget https://s3.amazonaws.com/dnld.lime-technology.com/archive/R750_Linux_Src_v${ROCKET}.tar.gz
    tar xf R750_Linux_Src_v${ROCKET}.tar.gz
    echo -e "${BLUE}Kernel Compile Module${NC}    -----    Build out of tree driver: RocketRaid r750"
    ( cd /usr/src/drivers/highpoint
      ./r750-linux-src-v${ROCKET}.bin --keep --noexec --target r750-linux-src-v${ROCKETSHORT} )
    ( cd /usr/src/drivers/highpoint/r750-linux-src-v${ROCKETSHORT}/product/r750/linux/
      make KERNELDIR=${D}/kernel
      xz -f r750.ko
      install -m 644 -o root -g root r750.ko.xz -D -t /lib/modules/$(uname -r)/kernel/drivers/scsi/ )
fi


if [[ " ${oot_drivers[@]} " =~ " rr3740a " ]]; then
     #Install RR3740A
     echo -e "${BLUE}Kernel Compile Module${NC}    -----    Install RR3740A"
     cd /usr/src/drivers/highpoint
     wget http://www.highpoint-tech.com/BIOS_Driver/RR3740A_840A/Linux/RR3740A_840A_2840A_Linux_Src_v${RR}.tar.gz
     tar xf RR3740A_840A_2840A_Linux_Src_v${RR}.tar.gz
     echo -e "${BLUE}Kernel Compile Module${NC}    -----    Build out of tree driver: RocketRaid 3740A"
     ( cd /usr/src/drivers/highpoint
       ./rr3740a_840a_2840a_linux_src_v${RR}.bin --keep --noexec --target rr3740a-linux-src-v${RRSHORT} )
     ( cd /usr/src/drivers/highpoint/rr3740a-linux-src-v${RRSHORT}/product/rr3740a/linux/
       make KERNELDIR=${D}/kernel
       xz -f rr3740a.ko
       install -m 644 -o root -g root rr3740a.ko.xz -D -t /lib/modules/$(uname -r)/kernel/drivers/scsi/ )
fi


if [[ " ${oot_drivers[@]} " =~ " rocketnvme " ]]; then
     #Install RocketNVMe
    echo -e "${BLUE}Kernel Compile Module${NC}    -----    Install RocketNVMe"
    mkdir -p /usr/src/drivers/highpoint
    cd /usr/src/drivers/highpoint
    wget http://www.highpoint-tech.com/BIOS_Driver/NVMe/RocketNVMe_Linux_Src_v${RN}.tar.gz
    tar xf RocketNVMe_Linux_Src_v${RN}.tar.gz
    echo -e "${BLUE}Kernel Compile Module${NC}    -----    Build out of tree driver: RocketNVMe"
    ( cd /usr/src/drivers/highpoint
      ./rsnvme_linux_src_v${RN}.bin --keep --noexec --target rsnvme_linux_src_v${RNSHORT} )
    ( cd /usr/src/drivers/highpoint/rsnvme_linux_src_v${RNSHORT}/product/rsnvme/linux/
      make KERNELDIR=${D}/kernel
      xz -f rsnvme.ko
      install -m 644 -o root -g root rsnvme.ko.xz -D -t /lib/modules/$(uname -r)/kernel/drivers/scsi/ )
fi


if [[ " ${oot_drivers[@]} " =~ " tehuti " ]]; then
     #Install Tehuti Drivers
     echo -e "${BLUE}Kernel Compile Module${NC}    -----    Installing Tehuti 10GB drivers"
     mkdir -p /usr/src/drivers/tehuti/tn40xx-${TEHUTI}
     cd /usr/src/drivers/tehuti
     wget --content-disposition https://github.com/chbmb/tn40xx-driver/tarball/vendor-drop/v${TEHUTI} -O tn40xx-${TEHUTI}.tar.gz
     tar xf tn40xx-${TEHUTI}.tar.gz -C /usr/src/drivers/tehuti/tn40xx-${TEHUTI} --strip 1
     KERNEL_VERSION=$(uname -r)
     echo "Build out of tree driver: Tehuti 10Gbit Ethernet"
     ( cd /usr/src/drivers/tehuti/tn40xx-${TEHUTI}
       KVERSION=${KERNEL_VERSION} make clean
       KVERSION=${KERNEL_VERSION} make -j $(grep -c ^processor /proc/cpuinfo)
       xz -f tn40xx.ko
       install -m 644 -o root -g root tn40xx.ko.xz -t /lib/modules/${KERNEL_VERSION}/kernel/drivers/net/ )
fi


if [[ " ${oot_drivers[@]} " =~ " ixgbe " ]]; then
     ##Install Intel 10GB drivers
     echo -e "${BLUE}Kernel Compile Module${NC}    -----    Installing Intel 10GB drivers"
     mkdir -p /usr/src/drivers/intel
     cd /usr/src/drivers/intel
#     wget https://downloadmirror.intel.com/14687/eng/ixgbe-${IXGBE}.tar.gz
     wget https://sourceforge.net/projects/e1000/files/ixgbe%20stable/${IXGBE}/ixgbe-${IXGBE}.tar.gz
     tar xf ixgbe-${IXGBE}.tar.gz
     KERNEL_VERSION=$(uname -r)
     echo "Build out of tree driver: Intel 10Gbit Ethernet"
     ( cd /usr/src/drivers/intel
       cd ixgbe-*/src
       BUILD_KERNEL=${KERNEL_VERSION} make install )
     
fi


if [[ " ${oot_drivers[@]} " =~ " ixgbevf " ]]; then
     #Install Intel 10GB virtual function drivers
     echo -e "${BLUE}Kernel Compile Module${NC}    -----    Installing Intel 10GB virtual function drivers"
     mkdir -p /usr/src/drivers/intel
     cd /usr/src/drivers/intel
#     wget https://downloadmirror.intel.com/18700/eng/ixgbevf-${IXGBEVF}.tar.gz
     wget https://sourceforge.net/projects/e1000/files/ixgbevf%20stable/${IXGBEVF}/ixgbevf-${IXGBEVF}.tar.gz
     tar xf ixgbevf-${IXGBEVF}.tar.gz
     KERNEL_VERSION=$(uname -r)
     ( cd /usr/src/drivers/intel
       cd ixgbevf-*/src
       BUILD_KERNEL=${KERNEL_VERSION} make install )     
fi


if [[ " ${oot_drivers[@]} " =~ " realtek " ]]; then
     #Install Realtek r8125
    echo -e "${BLUE}Kernel Compile Module${NC}    -----    Install Realtek r8125"
    mkdir -p /usr/src/drivers/realtek
    cd /usr/src/drivers/realtek
    wget https://github.com/ibmibmibm/r8125/archive/${REALTEK}.tar.gz
    tar xf ${REALTEK}.tar.gz
    echo -e "${BLUE}Kernel Compile Module${NC}    -----    Build out of tree driver: Realtek r8125"
    ( cd /usr/src/drivers/realtek/r8125-${REALTEK}
      make KERNELDIR=${D}/kernel
	  cd /usr/src/drivers/realtek/r8125-${REALTEK}/src
      xz -f r8125.ko
      install -m 644 -o root r8125.ko.xz /lib/modules/$(uname -r)/kernel/drivers/net/ethernet/realtek/ )
fi


cd ${D}

##Download Original Unraid And move it to stock
echo -e "${BLUE}Kernel Compile Module${NC}    -----    Download Original Unraid And move it to stock"
if [ -e "${D}/unRAIDServer-${UNRAID_DOWNLOAD_VERSION}-x86_64.zip" ]; then
 unzip -o unRAIDServer-${UNRAID_DOWNLOAD_VERSION}-x86_64.zip -d ${D}/unraid/
else
	if [[ ${UNRAID_DOWNLOAD_VERSION} == *"rc"* ]]; then
	  wget -nc https://s3.amazonaws.com/dnld.lime-technology.com/next/unRAIDServer-${UNRAID_DOWNLOAD_VERSION}-x86_64.zip
	else 
	  wget -nc https://s3.amazonaws.com/dnld.lime-technology.com/stable/unRAIDServer-${UNRAID_DOWNLOAD_VERSION}-x86_64.zip
	fi
    unzip -o unRAIDServer-${UNRAID_DOWNLOAD_VERSION}-x86_64.zip -d ${D}/unraid/
  fi

##Copy default Unraid bz files to folder prior to uploading
echo -e "${BLUE}Kernel Compile Module${NC}    -----    Copy default Unraid bz files to folder prior to uploading"
mkdir -p ${D}/${UNRAID_VERSION}/stock/
cp -f ${D}/unraid/bzimage ${D}/${UNRAID_VERSION}/stock/
cp -f ${D}/unraid/bzroot ${D}/${UNRAID_VERSION}/stock/
cp -f ${D}/unraid/bzroot-gui ${D}/${UNRAID_VERSION}/stock/
cp -f ${D}/unraid/bzmodules ${D}/${UNRAID_VERSION}/stock/
cp -f ${D}/unraid/bzfirmware ${D}/${UNRAID_VERSION}/stock/
cp -f ${D}/kernel/.config ${D}/${UNRAID_VERSION}/stock/

##Calculate sha256 on stock files - can then switch to SHA256 in the future
echo -e "${BLUE}Kernel Compile Module${NC}    -----    Calculate sha256 on stock files"
cd ${D}/${UNRAID_VERSION}/stock/
sha256sum bzimage > bzimage.sha256
sha256sum bzroot > bzroot.sha256
sha256sum bzmodules > bzmodules.sha256
sha256sum bzfirmware > bzfirmware.sha256
sha256sum bzroot-gui > bzroot-gui.sha256

##Make new bzmodules and bzfirmware - not overwriting existing
echo -e "${BLUE}Kernel Compile Module${NC}    -----    Make new bzmodules and bzfirmware - not overwriting existing"
mksquashfs /lib/modules/$(uname -r)/ ${D}/${UNRAID_VERSION}/stock/bzmodules-new -keep-as-directory -noappend
mksquashfs /lib/firmware ${D}/${UNRAID_VERSION}/stock/bzfirmware-new -noappend

#Package Up new bzimage
echo -e "${BLUE}Kernel Compile Module${NC}    -----    Package Up new bzimage"
cp -f ${D}/kernel/arch/x86/boot/bzImage ${D}/${UNRAID_VERSION}/stock/bzimage-new

##Make backup of /lib/firmware & /lib/modules
echo -e "${BLUE}Kernel Compile Module${NC}    -----    Make backup of /lib/firmware & /lib/modules"
mkdir -p ${D}/backup/modules
cp -r /lib/modules/ ${D}/backup/
mkdir -p ${D}/backup/firmware
cp -r /lib/firmware/ ${D}/backup/

##Calculate sha256 on new bzimage, bzfirmware & bzmodules - can then switch to SHA256 in the future
echo -e "${BLUE}Kernel Compile Module${NC}    -----    Calculate sha256 on new bzimage, bzfirmware & bzmodules"
cd ${D}/${UNRAID_VERSION}/stock/
sha256sum bzimage-new > bzimage-new.sha256
sha256sum bzmodules-new > bzmodules-new.sha256
sha256sum bzfirmware-new > bzfirmware-new.sha256

##Return to original directory
echo -e "${BLUE}Kernel Compile Module${NC}    -----    Return to original directory"
cd ${D}
