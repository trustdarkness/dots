#!/bin/zsh
#Credit: Original idea and script disable.sh by pwnsdx https://gist.github.com/pwnsdx/d87b034c4c0210b988040ad2f85a68d3

#Disabling unwanted services on macOS 11 Big Sur (11) and macOS Monterey (12)
#Disabling SIP is required  ("csrutil disable" from Terminal in Recovery)
#Modifications are written in /private/var/db/com.apple.xpc.launchd/ disabled.plist and disabled.501.plist


# user
TODISABLE=()

TODISABLE+=('com.apple.accessibility.MotionTrackingAgent' \
'com.apple.AddressBook.ContactsAccountsService' \
'com.apple.AMPArtworkAgent' \
'com.apple.AMPDeviceDiscoveryAgent' \
'com.apple.AMPLibraryAgent' \
'com.apple.ap.adprivacyd' \
'com.apple.ap.adservicesd' \
'com.apple.ap.promotedcontentd' \
'com.apple.assistant_service' \
'com.apple.assistantd' \
'com.apple.avconferenced' \
'com.apple.BiomeAgent' \
'com.apple.biomesyncd' \
'com.apple.CalendarAgent' \
'com.apple.cloudd' \
'com.apple.cloudpaird' \
'com.apple.cloudphotod' \
'com.apple.CloudPhotosConfiguration' \
'com.apple.CommCenter-osx' \
'com.apple.ContactsAgent' \
'com.apple.CoreLocationAgent' \
'com.apple.familycircled' \
'com.apple.familycontrols.useragent' \
'com.apple.familynotificationd' \
'com.apple.followupd' \
'com.apple.gamed' \
'com.apple.geod' \
'com.apple.homed' \
'com.apple.icloud.findmydeviced' \
'com.apple.icloud.findmydeviced.aps-demo' \
'com.apple.icloud.findmydeviced.aps-development' \
'com.apple.icloud.findmydeviced.aps-production' \
'com.apple.icloud.findmydeviced.findmydevice-user-agent' \
'com.apple.icloud.findmydeviced.ua-services' \
'com.apple.icloud.fmfd' \
'com.apple.icloud.searchpartyd' \
'com.apple.icloud.searchpartyd.accessorydiscoverymanager' \
'com.apple.icloud.searchpartyd.advertisementcache' \
'com.apple.icloud.searchpartyd.beaconmanager' \
'com.apple.icloud.searchpartyd.beaconmanager.agentdaemoninternal' \
'com.apple.icloud.searchpartyd.finderstatemanager' \
'com.apple.icloud.searchpartyd.pairingmanager' \
'com.apple.icloud.searchpartyd.scheduler' \
'com.apple.icloud.searchpartyuseragent' \
'com.apple.iCloudNotificationAgent' \
'com.apple.iCloudUserNotifications' \
'com.apple.imagent' \
'com.apple.imautomatichistorydeletionagent' \
'com.apple.imtransferagent' \
'com.apple.itunescloudd' \
'com.apple.knowledge-agent' \
'com.apple.ManagedClient.cloudconfigurationd' \
'com.apple.ManagedClientAgent.enrollagent' \
'com.apple.Maps.mapspushd' \
'com.apple.Maps.pushdaemon' \
'com.apple.mediaanalysisd' \
'com.apple.mediastream.mstreamd' \
'com.apple.newsd' \
'com.apple.nsurlsessiond' \
'com.apple.parsec-fbf' \
'com.apple.parsecd' \
'com.apple.passd' \
'com.apple.photoanalysisd' \
'com.apple.photolibraryd' \
'com.apple.progressd' \
'com.apple.protectedcloudstorage.protectedcloudkeysyncing' \
'com.apple.quicklook' \
'com.apple.quicklook.ui.helper' \
'com.apple.quicklook.ThumbnailsAgent' \
'com.apple.rapportd-user' \
'com.apple.remindd' \
'com.apple.routined' \
'com.apple.SafariCloudHistoryPushAgent' \
'com.apple.SafeEjectGPUAgent' \
'com.apple.screensharing.agent' \
'com.apple.screensharing.menuextra' \
'com.apple.screensharing.MessagesAgent' \
'com.apple.ScreenTimeAgent' \
'com.apple.security.cloudkeychainproxy3' \
'com.apple.sidecar-hid-relay' \
'com.apple.sidecar-relay' \
'com.apple.Siri.agent' \
'com.apple.siri.context.service' \
'com.apple.siriknowledged' \
'com.apple.suggestd' \
'com.apple.telephonyutilities.callservicesd' \
'com.apple.TMHelperAgent' \
'com.apple.TMHelperAgent.SetupOffer' \
'com.apple.UsageTrackingAgent' \
'com.apple.videosubscriptionsd' \
'com.apple.wifi.WiFiAgent')

for agent in "${TODISABLE[@]}"
do
	launchctl bootout gui/501/${agent}
	launchctl disable gui/501/${agent}
done

# system
TODISABLE=()

TODISABLE+=('com.apple.airportd' \
'com.apple.bootpd' \
'com.apple.backupd' \
'com.apple.backupd-helper' \
'com.apple.cloudd' \
'com.apple.cloudpaird' \
'com.apple.cloudphotod' \
'com.apple.CloudPhotosConfiguration' \
'com.apple.CoreLocationAgent' \
'com.apple.coreduetd' \
'com.apple.dhcp6d' \
'com.apple.diagnosticextensions.osx.wifi.helper' \
'com.apple.familycontrols' \
'com.apple.findmymacmessenger' \
'com.apple.followupd' \
'com.apple.FollowUpUI' \
'com.apple.ftp-proxy' \
'com.apple.ftpd' \
'com.apple.GameController.gamecontrollerd' \
'com.apple.geod' \
'com.apple.icloud.findmydeviced' \
'com.apple.icloud.findmydeviced.aps-demo' \
'com.apple.icloud.findmydeviced.aps-development' \
'com.apple.icloud.findmydeviced.aps-production' \
'com.apple.icloud.findmydeviced.findmydevice-user-agent' \
'com.apple.icloud.findmydeviced.ua-services' \
'com.apple.icloud.fmfd' \
'com.apple.icloud.searchpartyd' \
'com.apple.icloud.searchpartyd.accessorydiscoverymanager' \
'com.apple.icloud.searchpartyd.advertisementcache' \
'com.apple.icloud.searchpartyd.beaconmanager' \
'com.apple.icloud.searchpartyd.beaconmanager.agentdaemoninternal' \
'com.apple.icloud.searchpartyd.finderstatemanager' \
'com.apple.icloud.searchpartyd.pairingmanager' \
'com.apple.icloud.searchpartyd.scheduler' \
'com.apple.icloud.searchpartyuseragent' \
'com.apple.iCloudHelper' \
'com.apple.iCloudNotificationAgent' \
'com.apple.iCloudUserNotificationsd' \
'com.apple.itunescloudd' \
'com.apple.ManagedClient.cloudconfigurationd' \
'com.apple.netbiosd' \
'com.apple.nsurlsessiond' \
'com.apple.protectedcloudstorage.protectedcloudkeysyncing' \
'com.apple.rapportd' \
'com.apple.screensharing' \
'com.apple.security.cloudkeychainproxy3' \
'com.apple.siri.morphunassetsupdaterd' \
'com.apple.siriinferenced' \
'com.apple.wifianalyticsd' \
'com.apple.wifiFirmwareLoader' \
'com.apple.wifip2pd' \
'com.apple.wifivelocityd')

for daemon in "${TODISABLE[@]}"
do
	sudo launchctl bootout system/${daemon}
	sudo launchctl disable system/${daemon}
done
