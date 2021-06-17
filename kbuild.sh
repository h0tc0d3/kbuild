#!/usr/bin/bash
# Author: Grigory Vasilyev <echo "h0tc0d3(-*A*-)g-m*a-i-l(-d#t-)c#m" | sed -e 's/-//ig;s/*//ig;s/(A)/@/i;s/#/o/ig;s/(dot)/./i'>
# License: Apache License 2.0

KERNEL_VERSION='5.12.9'         # Which version of kernel we will build.
KERNEL_POSTFIX='noname'         # Kernel postfix
KERNEL_CONFIG='/proc/config.gz' # Kernel configuration file. Support text files and gz files with extension gz.
KERNEL_CONFIGURATOR='nconfig'   # Kernel configurator nconfig, menuconfig, xconfig.
# I recomment use nconfig, it better than menuconfig.
# You can write full string like MENUCONFIG_COLOR=blackbg menuconfig
# Detailed information you are can find https://www.kernel.org/doc/html/latest/kbuild/kconfig.html
MKINITCPIO=1                          # Run mkinicpio -p configname after kernel install? 0 - NO, 1-YES.
MKINITCPIO_CONFIG="${KERNEL_POSTFIX}" # mkinicpio config file name.

CONFIGURATOR=0      # Start kernel configurator? 0 - NO, 1-YES. If you not need configure kernel set 0.
LLVM=0              # Use LLVM for build? 1-LLVM, 0-GCC(or another dafault system CC)
THREADS=8           # Number of threads for build kernel. For automatic detection change to $(nproc)
BUILD_DIR='/tmp'    # Build Directory. I have 32gb memory and build kernel in memory tmpfs.
DOWNLOAD_DIR=${PWD} # Directory for saving kernel archove files. ${PWD} - current working directory.

DIST_CLEAN=0    # If source directory exist make disclean before build? 0 - NO, 1-YES
CLEAN_SOURCE=0  # Clean source code after build? 0 - NO, 1-YES.
REMOVE_SOURCE=1 # Remove source code directory after build? 0 - NO, 1-YES. I recommend use only one CLEAN_SOURCE or DIST_CLEAN or REMOVE_SOURCE
SYSTEM_MAP=0    # Copy System.map to /boot/System-${KERNEL_POSTFIX}.map" after build? 0 - NO, 1-YES.

PATCH_SOURCE=1                          # Apply kernel patches? 0 - NO, 1-YES.
PATCHES=("${HOME}/confstore/gcc.patch") # Kernel patches for apply.

DKMS_INSTALL=1                                        # DKMS Install? 0 - NO, 1-YES.
DKMS_UNINSTALL=1                                      # DKMS Uninstall? 0 - NO, 1-YES.
DKMS_MODULES=('openrazer-driver/3.0.1' 'digimend/10') # DKMS Modules what we will install.

# Don't change! Stops for debug and manual control!
STOP_DOWNLOAD=0 # Stop after download source archive? 0 - NO, 1-YES.
STOP_EXTRACT=0  # Stop after extract source archive? 0 - NO, 1-YES.
STOP_PATCH=0    # Stop after patch source? 0 - NO, 1-YES.
STOP_CONFIG=0   # Stop after kernel configurator? 0 - NO, 1-YES.
STOP_BUILD=0    # Stop after build? 0 - NO, 1-YES.
STOP_INSTALL=0  # Stop after install? 0 - NO, 1-YES.

# Strict Mode
set -euo pipefail

# Check user previlegies
if [[ ${EUID} -eq 0 ]]; then
  echo -e "\E[1;31m[-] Linux kernel build script can't be run with root previlegies! \E[0m"
  exit 1
fi

# Load user settings from ${HOME}/.kbuild
if [[ -f "${HOME:?}/.kbuild" ]]; then
  # shellcheck disable=SC1091
  source "${HOME:?}/.kbuild"
fi

# Current Kernel Name. Need for DKMS uninstall.
CURRENT_KERNEL=$(uname -a | grep -oP "[0-9]+\.[0-9]+\.(\w|-)+")

# Command line parameters
for arg in "$@"; do
  case "${arg}" in
  -v | --version)
    shift
    KERNEL_VERSION="${1}"
    ;;
  -p | --postfix)
    shift
    KERNEL_POSTFIX="${1}"
    ;;
  -c | --config)
    shift
    KERNEL_CONFIG="${1}"
    ;;
  -d | --dir)
    shift
    BUILD_DIR="${1}"
    ;;
  -z | --download)
    shift
    DOWNLOAD_DIR="${1}"
    ;;
  -x | --configurator)
    shift
    KERNEL_CONFIGURATOR="${1}"
    CONFIGURATOR=1
    ;;
  -s | --start)
    shift
    CONFIGURATOR=1
    ;;
  -ds | --disable-start)
    shift
    CONFIGURATOR=0
    ;;
  -mk | --mkinitcpio)
    shift
    MKINITCPIO=1
    ;;
  -dmk | --disable-mkinitcpio)
    shift
    MKINITCPIO=0
    ;;
  -mc | --mkinitcpio-config)
    shift
    MKINITCPIO_CONFIG="${1}"
    ;;
  -j | --threads)
    shift
    THREADS="${1}"
    ;;
  -l | --llvm)
    shift
    LLVM=1
    ;;
  -dl | --disable-llvm)
    shift
    LLVM=0
    ;;
  -m | --map)
    shift
    SYSTEM_MAP=1
    ;;
  -dm | --disable-map)
    shift
    SYSTEM_MAP=0
    ;;
  -cs | --clean)
    shift
    CLEAN_SOURCE=1
    ;;
  -dc | --disable-clean)
    shift
    CLEAN_SOURCE=0
    ;;
  -cd | --distclean)
    shift
    DIST_CLEAN=1
    ;;
  -dd | --disable-distclean)
    shift
    DIST_CLEAN=0
    ;;
  -r | --remove)
    shift
    REMOVE_SOURCE=1
    ;;
  -dr | --disable-remove)
    shift
    REMOVE_SOURCE=0
    ;;
  -ps | --patch)
    shift
    PATCH_SOURCE=1
    ;;
  -dp | --disable-patch)
    shift
    PATCH_SOURCE=0
    ;;
  -di | --dkms-install)
    shift
    DKMS_INSTALL=1
    ;;
  -ddi | --disable-dkms-install)
    shift
    DKMS_INSTALL=0
    ;;
  -du | --dkms-uninstall)
    shift
    DKMS_UNINSTALL=1
    ;;
  -ddu | --disable-dkms-uninstall)
    shift
    DKMS_UNINSTALL=0
    ;;
  -sd | --stop-download)
    shift
    STOP_DOWNLOAD=1
    ;;
  -se | --stop-extract)
    shift
    STOP_EXTRACT=1
    ;;
  -sp | --stop-patch)
    shift
    STOP_PATCH=1
    ;;
  -sc | --stop-config)
    shift
    STOP_CONFIG=1
    ;;
  -sb | --stop-build)
    shift
    STOP_BUILD=1
    ;;
  -si | --stop-install)
    shift
    STOP_INSTALL=1
    ;;
  -h | --help)
    echo -e "\nUSAGE: $(basename "$0") [options]...\n\n" \
      " Options:\t\t\t Description:\t\tExample:\n" \
      " --version, -v\t\t\t Linux Kernel version\t--version 5.12.9 | -v 5.13-rc4\n" \
      " --postfix, -p\t\t\t Linux Kernel postfix\t--postfix noname | -p noname\n" \
      " --config, -c\t\t\t Linux Kernel config\t--config /proc/config.gz | -c /proc/config.gz\n" \
      " --dir, -d\t\t\t Build directory\t--dir /tmp | -d /tmp\n" \
      " --download, -z\t\t Download directory\t--download /tmp | -z /tmp\n" \
      " --threads, -t\t\t\t Build threads\t\t--threads 8 | -t 8\n" \
      " --configurator, -x\t\t Kernel configurator\t--configurator nconfig | -x \"MENUCONFIG_COLOR=blackbg menuconfig\"\n\n" \
      " --start, -s\t\t\t Start configurator\n" \
      " --disable-start, -ds\t\t Don't start configurator\n\n" \
      " --mkinitcpio, -mk\t\t Start mkinitcpio after kernel installation\n" \
      " --disable-mkinitcpio, -dmk\t Don't start mkinitcpio after kernel installation\n" \
      " --mkinitcpio-config, -mc\t Mkinitcpio config\t--mkinitcpio-config noname | -mc noname\n\n" \
      " --llvm, -l\t\t\t Enable LLVM\n" \
      " --disable-llvm, -dl\t\t Disable LLVM\n\n" \
      " --patch, -ps\t\t\t Apply kernel patches\n" \
      " --disable-patch, -dp\t\t Don't apply kernel patches\n\n" \
      " --map, -m\t\t\t Copy System.map to /boot/System-\E[1;33mpostfix\E[0m.map\n" \
      " --disable-map, -dm\t\t Don't copy System.map\n\n" \
      " --clean, -cs\t\t\t Clean source after build\n" \
      " --disable-clean, -dc\t\t Don't clean source after build\n" \
      " --distclean, -cd\t\t Make distclean before build\n" \
      " --disable-distclean, -dd\t Don't make distclean before build\n" \
      " --remove, -r\t\t\t Remove source directory after build\n" \
      " --disable-remove, -dr\t\t Don't remove source directory after build\n\n" \
      " --dkms-install, -di\t\t Enable Install DKMS Modules\n" \
      " --disable-dkms-install, -ddi\t Disable Install DKMS Modules\n" \
      " --dkms-uninstall, -du\t\t Enable Uninstall DKMS Modules\n" \
      " --disable-dkms-uninstall, -ddu Disable Uninstall DKMS Modules\n\n" \
      " --stop-download, -sd\t\t Stop after download\n" \
      " --stop-extract, -se\t\t Stop after extract archive\n" \
      " --stop-patch, -sp\t\t Stop after patch source\n" \
      " --stop-config, -sc\t\t Stop after kernel configurator\n" \
      " --stop-build, -sb\t\t Stop after build\n" \
      " --stop-install, -si\t\t Stop after install\n"

    exit 0
    ;;
  *) shift ;;
  esac
done

# Check download directory
if [[ ! -d "${DOWNLOAD_DIR:?}" ]]; then
  echo -e "\E[1;31m[-] Download directory ${DOWNLOAD_DIR} not exist! \E[0m"
  exit 1
fi

# Check build directory
if [[ ! -d "${BUILD_DIR:?}" ]]; then
  echo -e "\E[1;31m[-] Build directory ${BUILD_DIR} not exist! \E[0m"
  exit 1
fi

# Kernel version for DKMS. Need for DKMS install.
KERNEL_VERSION_DKMS=${KERNEL_VERSION}

# Linux Kernel Download URL and KERNEL_VERSION_DKMS for rc version.
KERNEL_URL=''
if [[ "${KERNEL_VERSION}" =~ "rc" ]]; then                                      # If version contain rc string.
  KERNEL_URL="https://git.kernel.org/torvalds/t/linux-${KERNEL_VERSION}.tar.gz" # Kernel Download URL For RC Versions.
  KERNEL_VERSION_DKMS="${KERNEL_VERSION%-*}.0-${KERNEL_VERSION#*-}"
else
  KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_VERSION:0:1}.x/linux-${KERNEL_VERSION}.tar.xz" # Kernel Download URL For Release Versions.
fi

# Build flags can be empty for GCC and set to LLVM.
BUILD_FLAGS=''
# Set build flags if wea re using LLVM
if [[ ${LLVM} -eq 1 ]]; then
  echo -e "\E[1;33m[+] LLVM and Clang Enabled \E[0m"
  if clang --version 2>/dev/null | grep -iq "clang\s*version\s*[0-9]" && ld.lld --version 2>/dev/null | grep -iq "LLD\s*[0-9]"; then
    BUILD_FLAGS="LLVM=1 LLVM_IAS=1 CC=clang CXX=clang++ LD=ld.lld AR=llvm-ar NM=llvm-nm STRIP=llvm-strip READELF=llvm-readelf HOSTCC=clang HOSTCXX=clang++ HOSTAR=llvm-ar HOSTLD=ld.lld OBJCOPY=llvm-objcopy OBJDUMP=objdump"
  else
    echo -e "\E[1;31m[-]Clang and ld.lld not found. Will use default system compiler! \E[0m"
  fi
fi

# If kernel source archive not exist than download kernel source.
if [[ ! (-f "${DOWNLOAD_DIR}/linux-${KERNEL_VERSION}.tar.xz" || -f "${DOWNLOAD_DIR}/linux-${KERNEL_VERSION}.tar.gz") ]]; then
  echo -e "\E[1;33m[+] Downloading Linux Kernel Source: ${KERNEL_URL} \E[0m"
  wget "${KERNEL_URL}" -P "${DOWNLOAD_DIR}" || exit 1
fi

# Stop after download
if [[ ${STOP_DOWNLOAD} -eq 1 ]]; then
  exit 0
fi

# Extract source and cd to build directory.
if [[ -d "${BUILD_DIR:?}/linux-${KERNEL_VERSION}" ]]; then

  # Cd to build directory.
  echo -e "\E[1;33m[+] Changing working directory to kernel source directory: ${BUILD_DIR}/linux-${KERNEL_VERSION}\E[0m"
  cd "${BUILD_DIR:?}/linux-${KERNEL_VERSION}" || (
    echo -e "\E[1;31m[-] Can't cd to ${BUILD_DIR}/linux-${KERNEL_VERSION} build directory! Probably bad directory permssions! \E[0m"
    exit 1
  )

  # If source directory exist make disclean before build.
  if [[ ${DIST_CLEAN} -eq 1 ]]; then
    echo -e "\E[1;33m[+] Make distclean \E[0m"
    make distclean
  fi

else

  # Detect kernel source archive extension. RC versions have tar.gz extension and releases have tar.xz
  _ext=$(find "${DOWNLOAD_DIR}" -maxdepth 1 -name "linux-${KERNEL_VERSION}.tar.*" | head -n 1 | grep -oP "\w*$")

  echo -e "\E[1;33m[+] Extracting Linux Kernel source archive: linux-${KERNEL_VERSION}.tar.${_ext}\E[0m"
  if [[ ! -f "${DOWNLOAD_DIR}/linux-${KERNEL_VERSION}.tar.${_ext}" ]]; then
    echo -e "\E[1;31m[-] Kernel source achive linux-${KERNEL_VERSION}.tar.${_ext} not exist! \E[0m"
    exit 1
  fi

  # Extracting source.
  tar -xf "${DOWNLOAD_DIR}/linux-${KERNEL_VERSION}.tar.${_ext}" -C "${BUILD_DIR:?}" || (
    echo "\E[1;31m[-] Kernel source archive extract failed! Bad archive or build directory permissions! \E[0m"
    exit 1
  )

  # Cd to build directory.
  echo -e "\E[1;33m[+] Changinge working directory to kernel source directory: ${BUILD_DIR}/linux-${KERNEL_VERSION}\E[0m"
  cd "${BUILD_DIR:?}/linux-${KERNEL_VERSION}" || (
    echo -e "\E[1;31m[-] Can't cd to ${BUILD_DIR}/linux-${KERNEL_VERSION} build directory! The source archive is probably damaged! \E[0m"
    exit 1
  )

fi

# Stop after extract
if [[ ${STOP_EXTRACT} -eq 1 ]]; then
  exit 0
fi

# Apply kernel patches.
if [[ ${PATCH_SOURCE} -eq 1 ]]; then
  for patch_file in "${PATCHES[@]}"; do
    # Checking if patch file not exist in the source forlder than copy patch and apply
    if [[ ! -f "${patch_file##*/}" ]]; then
      echo -e "\E[1;33m[+] Apply patch ${patch_file##*/} \E[0m"
      cp "${patch_file:?}" "${patch_file##*/}"
      patch --forward --strip=1 --input="${patch_file:?}"
    fi
  done
fi

# Stop after pacth
if [[ ${STOP_PATCH} -eq 1 ]]; then
  exit 0
fi

# Add postfix to kernel
if [[ ! -f .scmversion ]]; then
  echo -e "\E[1;33m[+] Add kernel postfix: ${KERNEL_POSTFIX} \E[0m"
  echo "-${KERNEL_POSTFIX}" >.scmversion
fi

# Using active configuration
if [[ ! -f .config && -f "${KERNEL_CONFIG}" ]]; then
  echo -e "\E[1;33m[+] Copy kernel configuration: ${KERNEL_CONFIG} \E[0m"
  if [[ "${KERNEL_CONFIG##*.}" == "gz" ]]; then
    zcat "${KERNEL_CONFIG}" >.config
  else
    cp "${KERNEL_CONFIG}" .config
  fi
fi

# Update old config to new kernel
echo -e "\E[1;33m[+] Updating old config to new kernel \E[0m"
eval "make ${BUILD_FLAGS} oldconfig"

# Start kernel configurator
if [[ ${CONFIGURATOR} -eq 1 ]]; then
  echo -e "\E[1;33m[+] Starting kernel configurator: ${KERNEL_CONFIGURATOR}. \E[0m"
  eval "make ${BUILD_FLAGS} -j${THREADS} ${KERNEL_CONFIGURATOR}"
fi

# Stop after kernel configurator
if [[ ${STOP_CONFIG} -eq 1 ]]; then
  exit 0
fi

# Build Kernel
echo -e "\E[1;33m[+] Build linux kernel \E[0m"
eval "make ${BUILD_FLAGS} -j${THREADS}" || (
  echo -e "\E[1;31m[-] Kernel build failed! \E[0m"
  exit 1
)

# Build Modules
echo -e "\E[1;33m[+] Build kernel modules \E[0m"
eval "make ${BUILD_FLAGS} -j${THREADS} modules" || (
  echo -e "\E[1;31m[-] Kernel Modules build failed! \E[0m"
  exit 1
)

# Stop after build
if [[ ${STOP_BUILD} -eq 1 ]]; then
  exit 0
fi

# Uninstall dkms module from current kernel. This is necessary to not produce dead dkms modules in dkms list.
if [[ ${DKMS_UNINSTALL} -eq 1 ]]; then
  for dkms_module in "${DKMS_MODULES[@]}"; do
    echo -e "\E[1;33m[+] Uninstall DKMS module: ${dkms_module} \E[0m"
    set +e
    sudo dkms uninstall "${dkms_module}" -k "${CURRENT_KERNEL}"
    sudo dkms remove "${dkms_module}" -k "${CURRENT_KERNEL}"
    set -e
  done
fi

# Remove modules directory if it exist with same version and name.
if [[ -d "/lib/modules/${KERNEL_VERSION:?}-${KERNEL_POSTFIX:?}" ]]; then
  echo -e "\E[1;33m[+] Removing modules directory: /lib/modules/${KERNEL_VERSION}-${KERNEL_POSTFIX} \E[0m"
  sudo rm -fr "/lib/modules/${KERNEL_VERSION:?}-${KERNEL_POSTFIX:?}"
fi

# Modules install
echo -e "\E[1;33m[+] Installing kernel modules \E[0m"
eval "sudo make ${BUILD_FLAGS} -j${THREADS} modules_install"
# Copy Linux kernel to /boot and name vmlinuz-POSTFIX
echo -e "\E[1;33m[+] Copy linux kernel to /boot/vmlinuz-${KERNEL_POSTFIX} \E[0m"
sudo cp -v arch/x86_64/boot/bzImage "/boot/vmlinuz-${KERNEL_POSTFIX:?}"

# Install DKMS Modules
if [[ ${DKMS_INSTALL} -eq 1 ]]; then
  for dkms_module in "${DKMS_MODULES[@]}"; do
    echo -e "\E[1;33m[+] Install DKMS module: ${dkms_module} \E[0m"
    set +e
    eval "sudo ${BUILD_FLAGS} dkms install ${dkms_module} -k ${KERNEL_VERSION_DKMS}-${KERNEL_POSTFIX}"
    set -e
  done
fi

# Stop after install
if [[ ${STOP_INSTALL} -eq 1 ]]; then
  exit 0
fi

# Copy System.map to /boot and name System-POSTFIX.map
if [[ ${SYSTEM_MAP} -eq 1 ]]; then
  echo -e "\E[1;33m[+] Copy System.map to /boot/System-${KERNEL_POSTFIX}.map \E[0m"
  sudo cp -v System.map "/boot/System-${KERNEL_POSTFIX:?}.map"
fi

# Update boot init image
if [[ ${MKINITCPIO} -eq 1 ]]; then
  echo -e "\E[1;33m[+] Updating init boot image with config ${MKINITCPIO_CONFIG} \E[0m"
  sudo mkinitcpio -p "${MKINITCPIO_CONFIG}"
fi

# Clean source code after build
if [[ ${CLEAN_SOURCE} -eq 1 ]]; then
  echo -e "\E[1;33m[+] Make clean \E[0m"
  eval "make -j${THREADS} clean"
fi

# Remove source code directory
if [[ ${REMOVE_SOURCE} -eq 1 ]]; then
  echo -e "\E[1;33m[+] Removing source directory: ${BUILD_DIR}/linux-${KERNEL_VERSION} \E[0m"
  rm -fr "${BUILD_DIR:?}/linux-${KERNEL_VERSION:?}"
fi
