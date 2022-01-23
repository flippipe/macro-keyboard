#!/bin/bash
set -ueo pipefail

#https://www.urbanautomaton.com/blog/2014/09/09/redirecting-bash-script-output-to-syslog/
exec 1> >(logger -s -t "$(basename "$0")") 2>&1

# if no information about key pressed, then exit
if [ -z "${1-}" ]; then
    exit 2
else
    keyPressed="${1}"
fi

echo "Pressed ${keyPressed} $MPC_HOST" 

### 
##   FIX issues with keyboard different from the DE
#
setxkbmap -layout us -variant intl


###
##  List mpris players
#
function mprisList (){
    dbus-send --session --dest=org.freedesktop.DBus --print-reply /org/freedesktop/DBus org.freedesktop.DBus.ListNames \
    | grep -F org.mpris.MediaPlayer2. | awk '{print $2}' | sed -e 's:"::g'
}

###
##  Get status from your mpris player
#
function mprisStatus (){
    player='vlc' # totem
    dbus-send --print-reply --dest=org.mpris.MediaPlayer2.${player} /org/mpris/MediaPlayer2 org.freedesktop.DBus.Properties.Get \
            string:'org.mpris.MediaPlayer2.Player' string:'PlaybackStatus' | \
            grep -F string | awk '{print $3}' | sed -e 's:"::g' 2>> /dev/null

    # https://gist.github.com/derblub/823d9ba5876a011fc004
    # to find out your mpris players while they are running, execute previous function mprisList
}

###
##  Send commands to mpris via dbus
#
# https://specifications.freedesktop.org/mpris-spec/2.2/Player_Interface.html
function dbusSend (){
    mprisList | while read -r bus; do 
        dbus-send --type=method_call --dest="${bus}" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player."${1}"
    done
}


###
##  Send command to teams
#
function sendTeams() {

    # xdotool set_desktop $(xdotool get_desktop_for_window $WID)
    # xdotool windowfocus --sync $WID
    # https://askubuntu.com/questions/695017/why-does-my-xdotool-key-command-not-work


    echo "Sending to Window ${keyPressed} string $2" 

    desktop=$(xdotool get_desktop)
    xdotool set_desktop "$(xdotool get_desktop_for_window "$WID")"

    xdotool windowactivate --sync "${keyPressed}"  
    xdotool windowfocus --sync "${keyPressed}"  
    sleep 0.5
    xdotool key --window "${keyPressed}" Control_L+e 
    sleep 0.5
    xdotool getwindowfocus windowfocus --sync type --window "${keyPressed}" "$2" 
    sleep 0.5
    xdotool key --window "${keyPressed}" KP_Enter 

    xdotool set_desktop "$desktop"
}

###
##  mpcStatus
#

# note: mpc use env MPD_HOST, which i define in ~/.pam_environment

function mpcStatus (){
    tmp=$(mpc status | grep -E "^\[")
    [[ $tmp =~ [a-z]+ ]] && echo "${BASH_REMATCH[0]}" || echo "stop"
    # printf '%s\n' "${BASH_REMATCH[@]}"
}

###
##  Send commands to mpd
#
function mpcSend(){
    mpc --quiet "${keyPressed}"  # >> /dev/null
}



###
##  manage audio
#
function audio (){

    echo "arg audio function ${keyPressed}" 

    ## Case sensitivity in mpcSend and dbusSend is !!important!!
    case ${keyPressed} in
        play)
            mpcSend play
            #dbusSend Play
        ;;
        pause)
            # dbusSend Pause
            mpcSend pause
        ;;
        stop)
            #dbusSend Stop
            mpcSend stop
        ;;
        next)
            # dbusSend Next
            mpcSend next
        ;;
        prev)
            # dbusSend Previous
            mpcSend prev
        ;;
        toggle)
            # choose your single source of truth and adapt if needed
            status=$(mpcStatus)
            echo "mpd status: $status" 
            # status=$(mprisStatus)
            if [ "$status" = playing ]; then
                audio stop
                # audio pause
            elif [ "$status" = paused ]; then
                audio play
            elif [ "$status" = stop ]; then
                audio play
            fi
        ;;
        *)
            echo "audio: unkown action"
        ;;
        esac
}


function swapAudio {

    usbCard='usb-C-Media_Electronics_Inc._USB_Audio_Device-00'

    # check if USB Audio Interface exists
    if ! "$(pacmd list-cards | grep "alsa_card.${usbCard}" > /dev/null )"; then 
        echo "No Usb Audio Present" | osd_cat --pos=middle --align=center --lines=1 --delay 1 --font=-*-*-*-*-*-*-32-*-*-*-*-*-*-*  --colour=red
        return
    fi
    
    # ver o que meter nas variais com pacmd info
    if "$(pacmd stat | grep  "Default sink name: alsa_output.${usbCard}" > /dev/null )"; then
       srcProfile='analog-stereo'
       snkProfile='analog-stereo'
       card='pci-0000_00_1f.3'
       cardText='Built In Audio'
    else
       srcProfile='mono-fallback'
       snkProfile='analog-stereo'
       card='usb-C-Media_Electronics_Inc._USB_Audio_Device-00'
       cardText='USB Audio'
    fi

    echo "#################################"

    # Set the choosen card profile as sink
    # echo pactl set-card-profile "alsa_card.${card}" "output:${snkProfile}";
    # pactl set-card-profile "alsa_card.${card}" "output:${snkProfile}";
    # echo    pactl set-card-profile "alsa_card.${card}" "input:${srcProfile}";
    # pactl set-card-profile "alsa_card.${card}" "input:${srcProfile}";

    # Set the default sink to the new one
    echo pacmd set-default-sink "alsa_output.${card}.${snkProfile}" #&> /dev/null
    pacmd set-default-sink "alsa_output.${card}.${snkProfile}" #&> /dev/null

    # Set default mic
    echo pacmd set-default-source "alsa_input.${card}.${srcProfile}" 
    pacmd set-default-source "alsa_input.${card}.${srcProfile}" 

    # Redirect the existing inputs to the new sink
    for i in $(pacmd list-sink-inputs | grep index | awk '{print $2}'); do
        echo pacmd move-sink-input "$i" "alsa_output.${card}.${snkProfile}" 
        pacmd move-sink-input "$i" "alsa_output.${card}.${snkProfile}" 
    done

    echo "${cardText}" | osd_cat --pos=middle --align=center --lines=1 --delay 1 --font=-*-*-*-*-*-*-32-*-*-*-*-*-*-*  --colour=orange --outline=2 --outlinecolour=black


}

###############################################################################
####                                                                       MAIN
##

case ${keyPressed} in
    ####################
    # 1st row
    172) # key not working ;( 
        # xdotool key U1f600
        # xdotool type 😀
        # slow https://github.com/jordansissel/xdotool/issues/10
    ;;
    15) 
        swapAudio 
    ;;
    106) # key not working ;( 
        WID=$(xdotool search --onlyvisible --name "Mozilla Thunderbird" )
        if [ "$WID" ]; then
            echo "Found window $WID"
            xdotool windowactivate --sync "$WID"
        fi
    ;;
    140) # key not working ;( 
        xdotool key XF86Calculator 
    ;;
    ####################
    # 2nd row
    69) # bring front teams window
        WID=$(xdotool search --onlyvisible --name "Microsoft Teams" )
        echo "$WID" 

        if [ "$WID" ]; then
            echo "Found window $WID" 
            xdotool windowactivate --sync "$WID"  
        else
            teams &
        fi
    ;;
    98) # set available
        audio play
        timew continue
        WID=$(xdotool search --name " \| Microsoft Teams" )
        echo "$WID" 

        if [ "$WID" ]; then
            sendTeams "$WID" "/available"
        fi
        # curl -q "http://wled-LEDs1.lan/win&A=255&R=251&G=135&B=8&FX=0" 

        ;;
    55) # set dnd
        WID=$(xdotool search --name " \| Microsoft Teams"  )
        echo "$WID" 
        if [ "$WID" ]; then
            sendTeams "$WID" "/dnd"
        fi
        # curl -q "http://wled-LEDs1.lan/win&A=255&R=255&G=0&B=0&FX=0" 
        ;;


    14) # set away
        WID=$(xdotool search --name " \| Microsoft Teams" )
        echo "$WID" 

        if [ "$WID" ]; then
            sendTeams "$WID" "/away"
        fi
        audio stop
        timew stop
        # curl -q "http://wled-LEDs1.lan/win&A=255&R=10&G=235&B=0&FX=0" 
        ;;

    ####################
    # 3rd row
    71)
        audio toggle
    ;;
    72) 
        audio prev
    ;;
    73) 
        audio next
    ;;
    74)
        # Volume down
        xdotool key XF86AudioLowerVolume
    ;;
    ####################
    # 4th row
    75)

        playlist=$(mpc lsplaylists | head -n 1)
        mpc load "$playlist" 
        mpc play 
        mpc rm "$playlist" 
    ;;
    76)
        # take a area screenshot
        flameshot gui &
    ;;
    77)
        if [[ $( xdotool getactivewindow getwindowname) =~  ^Write:.*Thunderbird$ ]]; then
            xdotool key Alt_L+6
        else
            # open gedit (or new tab if open)
            gedit --new-document &
        fi
    ;;
    78)
        # Volume down
        xdotool key XF86AudioRaiseVolume
    ;;
    ####################
    # 6th row, more key than real usages.
    # just to have phun
    # this can be helpful 
    # https://gitlab.com/cunidev/gestures/-/wikis/xdotool-list-of-key-codes
    79)
        declare -a greetings
        greetings[0]="Howdies"
        greetings[2]="Dias Bons"
        greetings[1]="¡Buenos Dias!"
        greetings[3]="Bons dias"
        greetings[5]="Hi Hi Sir!"
        greetings[4]="Always harbor positivity in your mind because you will never find it in the real world. Good morning. Have a great day!"
        greetings[6]="\"Every morning I get up and look through the Forbes list of the richest people in America. If I'm not there, I go to work.\" – Robert Orben"
        greetings[7]="\"Every morning I jump out of bed and step on a landmine. The landmine is me. After the explosion, I spent the rest of the day putting the pieces together.\" – Ray Bradbury"
        greetings[8]="\"Every morning is a battle between the superego and the id, and I am a mere foot soldier with mud and a snooze button on her shield.\" – Catherynne Valente"
        greetings[9]="Every morning is a blessing only if you don't have an alarm clock by your bed. With an alarm clock, it's a curse. Good morning!"
        greetings[10]="\"Everyone wants me to be a morning person. I could be one, only if morning began after noon.\" – Tony Smite"
        greetings[11]="Good morning. Have a cup of coffee and start your engines because it's still a long way before you reach the weekend."
        greetings[12]="Good morning! If you think you didn't have enough sleep last night, don't worry, you still have your chance to take some mid-day naps later."
        greetings[13]="\"Good morning is a contradiction of terms.\" – Jim Davis"
        greetings[14]="If the world was kind to me, it would have slept like an Olympic discipline. Good morning to everyone living in this cruel, unjust world."
        greetings[15]="\"I was gonna take over the world this moring but I overslept. Postponed. Again.\" – Suburban Men"
        greetings[16]="\"Keep the dream alive: Hit the snooze button.\" – Punit Ghadge"
        greetings[17]="Life is full of stress and troubles. If you want to have a good day, don't get off your bed. Keep sleeping until you die and stop life happening to you!"
        greetings[18]="\"Morning comes whether you set the alarm or not.\" – Ursula Le Guin"
        greetings[19]="\"Morning is wonderful. Its only drawback is that it comes at such an inconvenient time of day.\" – Glen Cook"
        greetings[20]="\"My alarm clock is clearly jealous of my amazing relationship with my bed.\" – Unknown"
        greetings[21]="Smile right when you wake up because soon enough, you'll realize it's not weekend yet. Good morning!"
        greetings[22]="\"The brain is a wonderful organ; it starts working the moment you get up in the morning and does not stop until you get into the office.\" – Robert Frost"
        greetings[23]="\"There are two ways of waking up in the morning. One is to say, 'Good morning, God,' and the other is to say, 'Good God, morning'!\" – Fulton J. Sheen"
        greetings[24]="The saddest part of the morning is waking up realizing its not a holiday. Gonna spend the whole day with the same old routine. Good morning!"
        greetings[25]="Wake up and welcome one more unproductive, leisurely day that comes with nothing for you but leaves with a promise of another similar one."
        greetings[26]="\"When reality and your dreams collide, typically it's just your alarm clock going off.\" – Crystal Woods"

        xdotool sleep 0.1 type "${greetings[$(( RANDOM % 24))]}"
    ;;
    80)
        hour=$(date +%H)

        if [[ $( xdotool getactivewindow getwindowname) =~  ^Write:.*Thunderbird$ ]]; then

            if [ "$hour" -gt 21 ]; then
                xdotool key Alt_L+9
            elif [ "$hour" -gt 12 ]; then
                xdotool key Alt_L+8
            else 
                xdotool key Alt_L+7
            fi

        else

            if [ "$hour" -gt 21 ]; then
                msg="Boa noite,"
            elif [ "$hour" -gt 12 ]; then
                msg="Boa tarde,"
            else 
                msg="Bom dia,"
            fi

            xdotool key Return
            xdotool key Tab
            xdotool type "$msg"
            xdotool key Return
            xdotool key Return
            xdotool key Return
            xdotool key Return

            xdotool key Tab
            xdotool type "Cumprimentos,"
            xdotool key Return
            xdotool key Tab
            xdotool type "Filipe"
            xdotool key Return
            xdotool key Up
            xdotool key Up
            xdotool key Up
            xdotool key Up
            xdotool key Tab
        fi

    ;;
    81)
        # xdotool type --clearmodifiers --delay 30 "$(/usr/games/fortune -n 100 bofh-excuses)" 
        xdotool type --clearmodifiers --delay 30 "$(/usr/bin/date +%c)" 
        xdotool key Return
        xdotool type --clearmodifiers --delay 30 "========================" 
        xdotool key Return
    ;;

    ####################
    # 7th row
    82) # mute unmute video
        WID=$(xdotool search --onlyvisible --name "Microsoft Teams" )
        if [ "$WID" ]; then
            xdotool windowactivate --sync "$WID" key Control_L+Shift_L+o
        fi
    ;;
    57) # accept call
        audio stop
        sleep 2
        WID=$(xdotool search --onlyvisible --name "Microsoft Teams Notification" )
        if [ "$WID" ]; then
            desktop=$(xdotool get_desktop)
            xdotool set_desktop "$(xdotool get_desktop_for_window "$WID")"

            xdotool windowactivate --sync "$WID" key Control_L+Shift_L+a

            xdotool set_desktop "$desktop"
        fi
    ;;
    83) # close windows to close call, there is no shortcut to terminate a call,
        # one way is to close the window
        WID=$(xdotool search --onlyvisible --name "Microsoft Teams" )
        if [ "$WID" ]; then
            desktop=$(xdotool get_desktop)
            xdotool set_desktop "$(xdotool get_desktop_for_window "$WID")"
            
            xdotool windowactivate --sync "$WID" key Alt_L+F4 
            sleep 1
            xdotool windowactivate --sync "$WID"

            xdotool set_desktop "$desktop"
        fi
        sleep 2
        audio play
    ;;
    96) # mute unmute mike
        # WID=$(xdotool search --onlyvisible --name "Microsoft Teams$" )
        # if [ $WID ]; then
        #     xdotool windowactivate --sync $WID key Control_L+Shift_L+m 
        #     echo "xdotool windowactivate --sync $WID key Control_L+Shift_L+m" 
        #     # sendTeams $WID "/mute"
        # fi

        pactl set-source-mute @DEFAULT_SOURCE@ toggle
    ;;
    *)
        echo "unknown action to do"
esac
