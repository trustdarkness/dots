#!/usr/bin/env osascript
on run argList
	set p to item 1 of argList
	set mac_reference to p as POSIX file as alias
	set posix_reference to POSIX path of mac_reference
	set filepath to mac_reference as string
	return filepath
end run
