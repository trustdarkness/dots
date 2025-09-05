#!/usr/bin/env osascript
on run argv
	set [theApp] to argv
	try

		-- Force-refresh database; for testing only
		-- https://forum.keyboardmaestro.com/t/script-is-app-installed/5970/3
		-- do shell script "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -r -f -apps user,local,system"
		set theID to id of application theApp
		return theID
	on error
		return null
	end try
end run