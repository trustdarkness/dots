tell application "System Events"
	keystroke "c" using {command down}
	keystroke "g" using {shift down, command down}
	keystroke (key code 124)
	keystroke "/Contents"
	keystroke return
end tell