#!/bin/bash
# requires wmctrl
# https://forum.xfce.org/viewtopic.php?id=15530
# x1,y1,x2,y2 bounding box of "external" monitor - based on xrandr

# --- horizontal example ---
EXTx=1921 
EXTy=0
EXTw=3840
EXTh=1080
ORIENTATION=horizontal
# --- vertical example ---
#EXTx=0 
#EXTy=0
#EXTw=2560
#EXTh=1440
#ORIENTATION=vertical

### don't change anything below #####################################################################################3
# make sure that only one instance of this script is running per user
lockfile=/tmp/.emsa.$USER.lockfile
if ( set -o noclobber; echo "locked" > "$lockfile") 2> /dev/null; then
   trap 'rm -f "$lockfile"; exit $?' INT TERM EXIT
   echo "emsaDEBUG: Locking succeeded" >&2

   # variable to hold stickied windows
   STICKS=""

   while true
   do
      # get a list of visible windows and put it in an array
      readarray -t windows < <(wmctrl -lG | grep -v "\-1")
		
      # walk the list of visible windows to see if the top corner of any window is in the monitor range and sticky it
      for x in "${windows[@]}"
      do
         case $ORIENTATION in
            horizontal) 
               if [ $(echo $x | awk '{print $3}') -ge $EXTx -a $(echo $x | awk '{print $3}') -le $EXTw ] 
               then
                  WINID=$(echo $x | awk '{print $1}')
                  if ! [ $(echo $STICKS | grep $WINID) ]
                  then 
                     # sticky the window
                     wmctrl -i -r $WINID -b add,sticky
                  fi
               fi
            ;;
            vertical)
               if [ $(echo $x | awk '{print $4}') -ge $EXTy -a $(echo $x | awk '{print $4}') -le $EXTh ] 
               then
                  WINID=$(echo $x | awk '{print $1}')
                  if ! [ $(echo $STICKS | grep $WINID) ]
                  then 
                     # sticky the window
                     wmctrl -i -r $WINID -b add,sticky
                  fi
               fi
            ;;
            *) echo "Error: ORIENTATION not defined"
               exit 1
            ;;
         esac

            # save the window ID ensuring no duplicates
            STICKS=$(echo "$STICKS $WINID" | awk '{for (i=1;i<=NF;i++) if (!a[$i]++) printf("%s%s",$i,FS)}{printf("\n")}')
      done 

      # convert list of stickied window IDs to an array
      IFS=' ' read -a stickies <<< "$STICKS"
      
      # walk the list of stickied windows to make sure they still need to be sticky
      for y in "${stickies[@]}"
      do
         yx=$(wmctrl -lG | grep $y)
         case $ORIENTATION in
            horizontal)
               if ! [ $(echo $yx | awk '{print $3}') -ge $EXTx -a $(echo $yx | awk '{print $3}') -le $EXTw ] 
               then                  
                  # remove the sticky bit
                  wmctrl -i -r $y -b remove,sticky
                  STICKS=$(echo $STICKS | sed "s/ $y//g")
               fi
            ;;
            vertical)
               if ! [ $(echo $yx | awk '{print $4}') -ge $EXTy -a $(echo $yx | awk '{print $4}') -le $EXTh ] 
               then                  
                  # remove the sticky bit
                  wmctrl -i -r $y -b remove,sticky
                  STICKS=$(echo $STICKS | sed "s/$y//g")
               fi
            ;;
            *) echo "Error: ORIENTATION not defined properly"
               exit 1
            ;;
         esac
      done
         
      unset windows stickies WINID y
      
      # pause before next cycle
      sleep 1

   done

# can't create lockfile - notify user and quit
else
   echo "emsaDEBUG: Lock failed, check for existing process and/or lock file and delete - exiting." >&2
   exit 1
fi			

exit 0
