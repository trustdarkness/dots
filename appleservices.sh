#!env bash
# This list is not exhaustive and the categories are mine from manual 
# investigation using activity monitor and the investigative functions
# I've created in macutil.sh, in the same github repo where this lib
# originates.  This data was gathered on a mac running BigSur, and with
# SIP disabled (but not running the service disables in recovery mode)
# and having already run macservicedisables.sh, which is now also in 
# this repo as the original github gist page seems to be gone.
# 
# I've made it hard to run, you need to supply the disable function
# with a date of May or June 2024 in the format YYYYMMDD, then sudo, 
# etc.  It should be hard to run by accident.  Review the categories
# and their contents before running if you choose to.
#
# Disabling OS services, is of course, done at your own risk, neither
# apple nor I nor anyone else will offer you support and this is 
# provided free of charge with no warrantee, liability, or apology.
# do with it as you wish. MIT license (as opposed to the rest of this repo
# which is generally GPL2):
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the “Software”), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

needs_investigating=(
  "/System/Library/LaunchDaemons//com.apple.jetsamproperties.Mac.plist"
)

apple_airplay_services=(
  'system/com.apple.AirPlayUIAgent'
  'system/com.apple.AirPlayXPCHelper'
)

itunes_cloud=(
  'system/com.apple.itunescloudd'
)

apple_fairplay_services=(
  'system/com.apple.fairplayd'
)

apple_ad_services=(
  'system/com.apple.ap.adservicesd'
  'system/com.apple.ap.adprivacyd'
)

apple_accessibility_services=(
  'system/com.apple.accessibility.dfrhud'
  'system/com.apple.AccessibilityVisualsAgent'
  'system/com.apple.accessibility.AXVisualSupportAgent'
  'system/com.apple.accessibility.heard'
  'system/com.apple.accessibility.MotionTrackingAgent'
)

apple_analytics_services=(
  'system/com.apple.wifianalyticsd'
  'system/com.apple.osanalytics.osanalyticshelper'
  'system/com.apple.analyticsd'
)

apple_share_services=(
  'system/com.apple.coreservices.UASharedPasteboardProgressUI'
  'system/com.apple.coreservices.sharedfilelistd'
  'system/com.apple.mdworker.shared'
)

# a subset of above, this is probably what we want to disable
apple_sharedfile_services=(
  'system/com.apple.coreservices.sharedfilelistd'
)

apple_spell_services=(
  'system/com.apple.applespell'
)

# telemetry data for touchID
apple_biokit_services=(
  'system/com.apple.biokitaggdd'
  'system/com.apple.biometrickitd'
)

# tacked the following on the end manually
# bird - https://appletoolbox.com/bird-process-high-cpu-usage-mac/
apple_cloud_services=(
  'system/com.apple.ManagedClient.cloudconfigurationd'
  'system/com.apple.cloudd'
  'system/com.apple.cloudpaird'
  'system/com.apple.cloudphotod'
  'system/com.apple.iCloudNotificationAgent'
  'system/com.apple.iCloudUserNotifications'
  'system/com.apple.icloud.findmydeviced'
  'system/com.apple.icloud.findmydeviced.findmydevice-user-agent'
  'system/com.apple.icloud.fmfd'
  'system/com.apple.icloud.searchpartyd'
  'system/com.apple.icloud.searchpartyuseragent'
  'system/com.apple.itunescloudd'
  'system/com.apple.protectedcloudstorage.protectedcloudkeysyncing'
  'system/com.apple.security.cloudkeychainproxy3'
  'system/com.apple.bird'
  'system/com.apple.SecureBackupDaemon'
)

apple_cloud_notifications=(
  'system/com.apple.iCloudNotificationAgent'
  'system/com.apple.iCloudUserNotifications'
)

apple_calendar_services=(
  'system/com.apple.CalendarAgent'
)

apple_call_services=(
  'system/com.apple.CallHistoryPluginHelper'
  'system/com.apple.CallHistorySyncHelper'
  'system/com.apple.telephonyutilities.callservicesd'
)

apple_location_services=(
  'system/com.apple.CoreLocationAgent'
  'system/com.apple.locationd'
  'system/com.apple.locationmenu'
)

apple_mobile_services=(
  'system/com.apple.MobileAccessoryUpdater'
  'system/com.apple.MobileAccessoryUpdater.fudHelperAgent'
  'system/com.apple.MobileFileIntegrity'
  'system/com.apple.mobile.keybagd'
  'system/com.apple.mobile.obliteration'
  'system/com.apple.mobile.softwareupdated'
  'system/com.apple.mobile.storage_mounter'
  'system/com.apple.mobile.storage_mounter_proxy'
  'system/com.apple.mobileactivationd'
  'system/com.apple.mobileassetd'
  'system/com.apple.mobilegestalt.xpc'
)

# NFC Readers and such
apple_ifd_services=(
  'system/com.apple.ifdreader'
)

apple_speech_services=(
  'system/com.apple.corespeechd'
  'system/com.apple.speech.speechdatainstallerd'
  'system/com.apple.speech.speechsynthesisd.arm64'
  'system/com.apple.speech.speechsynthesisd.x86_64'
  'system/com.apple.speech.synthesisserver'
)

# may be required for some basic connectivity, but perhpas just apple
# https://apple.stackexchange.com/questions/259641/ctkahp-quit-unexpectedly
# includes things like ctkd ctkahd
# keybagd:
# https://www.blackhat.com/docs/us-16/materials/us-16-Krstic.pdf
apple_crypto_services=(
  'system/com.apple.CryptoTokenKit.ahp'
  'system/com.apple.CryptoTokenKit.ahp.agent'
  'system/com.apple.mobile.keybagd'
)

apple_spotlight_services=(
  'system/com.apple.Spotlight'
  'system/com.apple.corespotlightd'
  'system/com.apple.corespotlightservice'
  'system/com.apple.diagnosticextensions.osx.spotlight.helper'
)

# commerce added manually; purchased apps and content
apple_appstore_services=(
  'system/com.apple.appstoreagent'
  'system/com.apple.appstorecomponentsd'
  'system/com.apple.appstored'
  'system/com.apple.commerce'
)

apple_audio_services=(
  'system/com.apple.audio.AudioComponentRegistrar'
  'system/com.apple.audio.AudioComponentRegistrar.daemon'
  'system/com.apple.audio.coreaudiod'
  'system/com.apple.audio.systemsoundserverd'
  'system/com.apple.bluetoothaudiod'
  'system/com.apple.dpaudiothru'
)

# TODO: distribute these to their parent services, where applicable
apple_plugin_services=(
  'system/com.apple.CallHistoryPluginHelper'
  'system/com.apple.WebKit.PluginAgent'
  'system/com.apple.dspluginhelperd'
  'system/com.apple.pluginkit.pkd'
  'system/com.apple.pluginkit.pkreporter'
)

# duet is related to connecting to other macs and iOS devices, 
# presumably primarily through the Sidecar functionality
# https://www.duetdisplay.com/
# dasd - Duet Activity Scheduler Daemon
# https://www.howtogeek.com/357437/what-is-dasd-and-why-is-it-running-on-my-mac/
apple_duet_services=(
  'system/com.apple.coreduetd.osx'
  'system/com.apple.dasd-OSX'
)

# added dmd manually:
# dmd is the system daemon and user agent processes responsible for backing
# the DeviceManagement system private framework.
# https://forum.dlang.org/post/laduhiryvenpxjuihyyk@forum.dlang.org
# also $(man dmd)
# lightsoutmanagementd:
# https://support.apple.com/guide/deployment/lights-out-management-payload-settings-dep580cf25bc/web
apple_mdm_services=(
  'system/com.apple.mdmclient.agent'
  'system/com.apple.mdmclient.daemon'
  'system/com.apple.mdmclient.daemon.runatboot'
  'system/com.apple.lightsoutmanagementd'
)

# Apple's cute little differential privacy service
# DPSubmissionService also falls under here (but no launch agent/daemon)
apple_dprivacy_services=(
  'system/com.apple.dprivacyd'
)

apple_security_services=(
  'system/com.apple.EscrowSecurityAlert'
  'system/com.apple.endpointsecurity.endpointsecurityd'
  'system/com.apple.security.DiskUnmountWatcher'
  'system/com.apple.security.FDERecoveryAgent'
  'system/com.apple.security.KeychainStasher'
  'system/com.apple.security.agent'
  'system/com.apple.security.agent.login'
  'system/com.apple.security.authhost'
  'system/com.apple.security.authtrampoline'
  'system/com.apple.security.cloudkeychainproxy3'
  'system/com.apple.security.keychain-circle-notification'
  'system/com.apple.security.syspolicy'
  'system/com.apple.securityd'
  'system/com.apple.securityd_service'
  'system/com.apple.securityuploadd'
)

apple_input_services=(
  'system/com.apple.TextInputMenuAgent'
  'system/com.apple.TextInputSwitcher'
  'system/com.apple.imklaunchagent'
)

apple_keychain_services=(
  'system/com.apple.security.KeychainStasher'
  'system/com.apple.security.cloudkeychainproxy3'
  'system/com.apple.security.keychain-circle-notification'
  'system/com.apple.systemkeychain'
)

apple_launch_services=(
  'system/com.apple.coreservices.launchservicesd'
  'system/com.apple.imklaunchagent'
)

# not sure about this one:
# https://github.com/azenla/MacHack
apple_t2_services=(
    'system/com.apple.lskdd'
)

# MTLCompilerService seems to be here
# Metal GPU Compiler
# https://discussions.apple.com/thread/252731048?sortBy=best
apple_window_services=(
  'system/com.apple.UserEventAgent-LoginWindow'
  'system/com.apple.UserNotificationCenterAgent-LoginWindow'
  'system/com.apple.WindowServer'
  'system/com.apple.loginwindow'
  'system/com.apple.loginwindow.LWWeeklyMessageTracer'
)

apple_gpu_services=(
  'system/com.apple.DumpGPURestart'
  'system/com.apple.ReportGPURestart'
  'system/com.apple.SafeEjectGPUAgent'
  'system/com.apple.SafeEjectGPUStartupDaemon'
)

apple_tcc_services=(
  'system/com.apple.tccd'
  'system/com.apple.tccd.system'
)

TO_DISABLE_20240529=(
  "${apple_airplay_services[@]}"
  "${apple_fairplay_services[@]}"
  "${apple_apad_services[@]}"
  "${apple_sharedfile_services[@]}"
  "${apple_biokit_services[@]}"
  "${apple_cloud_services[@]}"
  "${apple_calendar_services[@]}"
  "${apple_call_services[@]}"
  "${apple_mobile_services[@]}"
  "${apple_ifd_services[@]}"
  "${apple_appstore_services[@]}"
  "${apple_duet_services[@]}"
  "${apple_mdm_services[@]}"
  "${apple_dprivacy_services[@]}"
)

TO_DISABLE_20240602_MONTEREY=(
  "${apple_ad_services[@]}"
  "${apple_airplay_services[@]}"
  "${itunes_cloud[@]}"
  "${apple_sharedfile_services[@]}"
  "${apple_appstore_services[@]}"
  "${apple_location_services[@]}"
)

# not in recovery, but with sip disabled, root ro
# for i in $(for i in "${TO_DISABLE_20240602_MONTEREY[@]}"; do services_running | grep  $i; done); do service_stop $i; done
# for i in $(for i in "${TO_DISABLE_20240602_MONTEREY[@]}"; do services_running | grep  $i; done); do service_disable $i; done

if ! out=$(declare -p plists_to_reset 2> /dev/null); then 
  declare -a plists_to_reset 
fi 
disable_services() {
  # pre-system-edit
  # mount_system_from_recovery
    good_to_go=false
    if [ "${#plists_to_reset[@]}" -gt 2 ]; then 
      echo "plists_to_reset is already populated"
      echo "1. continue with those services"
      echo "2. see what we're talking about"
      echo "3. clear and startover."
      echo "4. exit."
      chosen=$(get_keypress "pick 1-4")
      case ${chosen} in
        1) 
          good_to_go=true;
          ;;
        2) 
          for plist in "${plists_to_reset[@]}"; do 
            echo "${plist}"
          done
          ;;
        3) 
          plists_to_reset=()
          ;;
        4) 
          return 255
          ;;
      esac
    fi
  # else
  #   echo "you did not enter the magic incantation"
  #   echo "and I cannot let you destroy your system"
  #   echo "please read the code and try again."
  #   return 254
  # fi
  if ! $good_to_go && [ "${#plists_to_reset[@]}" -lt 1 ]; then 
    for service in "${TO_DISABLE_20240529[@]}"; do
      # plist_from_qualified_service_name uses FAKEROOT, so should 
      # return properly qualified absolute paths
      plist=$(plist_from_qualified_service_name "${service}")
      if [ -f "${plist}" ]; then 
        # but just to be safe, we will load them in an array for 
        # manual inspection first
        plists_to_reset+=( "${plist}" )
      else
        se "could not locate plist ${plist} for ${service}"
      fi
    done
    good_to_go=true # presumably
  fi
  if $good_to_go; then
    if [ "${#plists_to_reset[@]}" -gt 2 ]; then 
      # 2 is arbitrary
      echo "We're about to disable these coreservices by moving their"
      echo "plist files into the disabled folder.  Hope you know"
      echo "what you're doing."
      for plist in "${plists_to_reset[@]}"; do 
        echo "${plist}"
      done
      if confirm_yes; then 
        for plist in "${plists_to_reset[@]}"; do 
          pref_reset "${plist}"
        done
      fi
    fi
  fi
}