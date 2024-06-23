declare -a BOOT_ARGS

declare -a macboot_namerefs
macboot_namerefs=(
    "BOOT_ARGS"
    "macboot_namerefs"
    "sip_enable_allow_nvram"
    "enableamfidisablelibraryverification"
    "clearbootargs"
    "bootargs_bootstrap"
    "disableamfioomw"
    "disableamfi80"
    "bootargs_csr_disable"
    "execute_bootargs"
    "unsource_macboot"
)

# to be executed from recovery, after which, the rest should be able to be run
# from the running system with sip enabled.
function sip_enable_allow_nvram() {
  csrutil enable --without nvram
} 

# It seems as thuough a number of things that used to be accomplished by 
# disabling AMFI, most folks are finding that disabling library verification
# via the enclosed plist edit is sufficient.  There are separate functions
# for each as well.
function enableamfidisablelibraryverification() {
  # that's a mouthful
  local backups=$(find /etc -depth 1 -type f -name "nvram-boot-args*" 2>/dev/null)
  if [ $? -eq 0 ]; then
   echo "nvram-boot-args backups exist in /etc, please investigate before continuing."
   return 1
  fi
  sudo nvram boot-args=""; 
  # https://github.com/MacEnhance/MacForge/issues/30
  sudo defaults write /Library/Preferences/com.apple.security.libraryvalidation.plist DisableLibraryValidation -bool true
}

# If you made modificat ions to boot-args with this tool, you may have a backup
# of your original boot args in /etc.  IF so, it will force you to look at the 
# backup and restore or clear it before it does things like clear the current
# boot args.
function clearbootargs() {
  local backups=$(find /etc -depth 1 -type f -name "nvram-boot-args*" 2>/dev/null)
  if [ $? -eq 0 ]; then
    echo "nvram-boot-args backups exist in /etc, please investigate before continuing."
    return 1
  fi
  sudo nvram boot-args=""; 
}

# Sets up loading a set of bootargs from functions in this file
function bootargs_bootstrap() {
  BOOT_ARGS=()
  local existing=$(sudo nvram boot-args)
  if [ -z "${existing}" ]; then
    # just to be paranoid
    existing=$(sudo nvram -p 2>/dev/null|grep boot-args)
    if [ -z "${existing}" ]; then
      echo "Found no existing boot-args.  This may be WAI.  Know your system."
    fi
  fi
  if [ -n "${existing}" ]; then 
    echo "Prepending existing boot-args: ${existing}"
    BOOT_ARGS+=( "${existing}" )
    local ts="$(date '+%Y%m%d %H:%M:%S')"
    echo "also writing a backup to /etc/nvram-boot-args-${ts}"
    echo "enableamfi* functions will check for any backups"
    echo "and ask if you want to restore."
    sudo echo "${existing}" > /etc/nvram-boot-args-${ts}
    sudo chmod 644 /etc/nvram-boot-args-${ts}
  fi
  BOOT_ARGS+=( "-v" )
}

# AMFI is controlled from /System/Library/LaunchDaemons/com.apple.MobileFileIntegrity
# kernel extension is /System/Library/Extensions/AppleMobileFileIntegrity

# disables amfi using amfi_get_out_of_my_way=1
function disableamfioomw() {
  BOOT_ARGS+=( "-no-compat-check" )
  BOOT_ARGS+=( "amfi_get_out_of_my_way=1" )
  # https://github.com/MacEnhance/MacForge/issues/30
  BOOT_ARGS+=( "ipc_control_port_options=0" )
  #sudo nvram boot-args="${BOOT_ARGS_final}"
}

# disables amfi using amfi0x80
function disableamfi80() {
  # 0x80 is a bitmask equivalent to AMFI_ALLOW_EVERYTHING
  BOOT_ARGS+=( "amfi0x80" )
}

# disables sip using csr-active-config=03080000
function bootargs_csr_disable {
  BOOT_ARGS+=( "csr-active-config=03080000" )
}

# executes the loaded bootargs
function execute_bootargs() {
  bootargs_bootstrap
  disableamfioomw
  if ! gt "${#BOOT_ARGS[@]}" 1; then
    >&2 printf "bootstrap failed.  bailing out."
    return 1
  fi

  # now insert any other bootargs functions from above that youd
  # like to be included in your nvram boot args below

  # run the function to make sure that your command looks correct and 
  # then copy and paste it to run by hand  you're playing with fire, 
  # treat her with the respect she deserves.
  echo "sudo nvram boot-args ${BOOT_ARGS[@]}"
}

# returns 0 if the boot volume can be modified, 1 otherwise
function boot_volume_is_mutable() {
  grep disabled < <(csrutil authenticated-root status) > /dev/null
  return $?
}

# returns 0 if the boot volume can't be modified, 1 otherwise
function boot_volume_is_immutable() {
  grep enabled < <(csrutil authenticated-root status) > /dev/null
  return $?
}

# returns the boot volume (symlinked to /)
function boot_volume() {
  for volume in $(ls /Volumes); do
    if [[ $(realpath "$volume") == "/" ]]; then 
      echo "$volume"
    fi
  done
}
alias boot_disk="boot_volume"
alias root_volume="boot_volume"
alias root_disk="boot_volume"

# attempts to mount the boot volume rw.  this method does not
# seem to work
function mount_boot_volume_rw() {
  local ar=$(csrutil authenticated-root status|grep disabled)
  local root_volume=""
  if [ $? -eq 0 ]; then 
    sudo mount -uw "$(boot_volume)"
  fi
}

# mounts the root filesystem to ~/rootfs
function mount_system_from_recovery() {
  local dev="${1:-}"
  
  if [ -e "${dev}" ]; then
    mkdir -p ~/rootfs
    se !:?
    sudo mount -o nobrowse -t apfs "${dev}" ~/rootfs
    # chroot mnt
  fi
}

# Simulates rebooting holding the option key --
# boots to the boot disk picker
function boottostartoptions() {
  sudo /usr/sbin/nvram manufacturing-enter-picker=true
  sudo reboot
}

# boots the system normally after having set nvram to
# boot to the picker
function boottostartupdisknooptions() {
  sudo /usr/sbin/nvram manufacturing-enter-picker=false
  sudo reboot
}

# blesses the root file system after an edit and creates a new snapsshot
function post-system-edit() {
  systemvol="$HOME/rootfs"
  sudo bless --folder "${systemvol}"/System/Library/CoreServices --bootefi --create-snapshot
  # if > bigsur
  # sudo bless --mount MOUNT_PATH/System/Library/CoreServices --setBoot --create-snapshot
}

# effectively removes everything from this script from env, see
# cleanup_namespace in util.sh for more info
# TODO: update namerefs and change to use the similar routine in util.sh
unsource_macboot() {
  if exists cleanup_namespace; then 
    cleanup_namespace macboot
  fi  
}