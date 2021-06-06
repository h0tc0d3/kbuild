# Flexible Linux Kernel Build Script

To see help start script with --help or -h paramer `./kbuild.sh --help`.
Script parameters overwrite default configuration values.

```text

USAGE: kbuild.sh [options]...

  Options:                       Description:           Example:
  --version, -v                  Linux Kernel version   --version 5.12.9 | -v 5.13-rc4
  --postfix, -p                  Linux Kernel postfix   --postfix noname | -p noname
  --config, -c                   Linux Kernel config    --config /proc/config.gz | -c /proc/config.gz
  --dir, -d                      Build directory        --dir /tmp | -d /tmp
  --download, -z                 Download directory     --download /tmp | -z /tmp
  --threads, -t                  Build threads          --threads 8 | -t 8
  --configurator, -x             Kernel configurator    --configurator nconfig | -x "MENUCONFIG_COLOR=blackbg menuconfig"

  --start, -s                    Start configurator
  --disable-start, -ds           Don't start configurator

  --mkinitcpio, -mk              Start mkinitcpio after kernel installation
  --disable-mkinitcpio, -dmk     Don't start mkinitcpio after kernel installation
  --mkinitcpio-config, -mc       Mkinitcpio config      --mkinitcpio-config noname | -mc noname

  --llvm, -l                     Enable LLVM
  --disable-llvm, -dl            Disable LLVM

  --patch, -ps                   Apply kernel patches
  --disable-patch, -dp           Don't apply kernel patches

  --map, -m                      Copy System.map to /boot/System-postfix.map
  --disable-map, -dm             Don't copy System.map

  --clean, -cs                   Clean source after build
  --disable-clean, -dc           Don't clean source after build
  --distclean, -cd               Make distclean before build
  --disable-distclean, -dd       Don't make distclean before build
  --remove, -r                   Remove source directory after build
  --disable-remove, -dr          Don't remove source directory after build

  --dkms-install, -di            Enable Install DKMS Modules
  --disable-dkms-install, -ddi   Disable Install DKMS Modules
  --dkms-uninstall, -du          Enable Uninstall DKMS Modules
  --disable-dkms-uninstall, -ddu Disable Uninstall DKMS Modules

  --stop-download, -sd           Stop after download
  --stop-extract, -se            Stop after extract archive
  --stop-patch, -sp              Stop after patch source
  --stop-config, -sc             Stop after kernel configurator
  --stop-build, -sb              Stop after build
  --stop-install, -si            Stop after install

```

You are can add command alias to yours .bashrc file. `echo "alias kbuild='fullpath/kbuild.sh'" >> "${HOME}/.bashrc"`. Replace **fullpath** with yours path to script.
After you are can start script with command `kbuild --help`.

For define default variables edit kbuild.sh file or copy code below to .kbuild file at yours home directory, `vi "${HOME}/.kbuild"`, `nano "${HOME}/.kbuild"`.

```text
KERNEL_VERSION='5.12.9'         # Which version of kernel we will build.
KERNEL_POSTFIX='noname'         # Kernel postfix
KERNEL_CONFIG='/proc/config.gz' # Kernel configuration file. Support text files and gz files with extension gz.
KERNEL_CONFIGURATOR='nconfig'   # Kernel configurator nconfig, menuconfig, xconfig.
# I recomment use nconfig, it better than menuconfig.
# You can write full string like MENUCONFIG_COLOR=blackbg menuconfig
# Detailed information you are can find https://www.kernel.org/doc/html/latest/kbuild/kconfig.html
MKINITCPIO=1 # Run mkinicpio -p configname after kernel install? 0 - NO, 1-YES.
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