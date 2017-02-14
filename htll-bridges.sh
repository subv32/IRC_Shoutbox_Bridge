#!/bin/bash
#Globals
config="irc-shoutbox-bridge.conf.sh"
source $config 

# HTLL functions
function htll() {
	#HTLL vars
	loginUrl="https://hightechlowlife.eu/board/login/login"
	shoutyUrl="https://hightechlowlife.eu/board/chat/"
	htllApiEndPoint="https://hightechlowlife.eu/board/aigle/api/?token=$htllApiKey"
	htllApiEndPointPost="https://hightechlowlife.eu/board/aigle/api/"

	function lastTenMessages() {
		latestTen=`curl -s $htllApiEndPoint | jq '.[0,1,2,3,4,5,6,7,8,9,10]'`
		if [ $? -eq 1 ]; then 
			return 1 
		else 
			return 0 
		fi
	}
	postToChatApi() {
	#Posts the first argument past to this function or chatMessage if not null

	if [ -n "$chatMessage" ]; then
		curl -s -d "token=$htllApiKey&msg=$chatMessage" $htllApiEndPointPost
	else
		curl -s -d "token=$htllApiKey&msg=$1" $htllApiEndPointPost
	fi
	}
}

# BRIDGE IRC => SHOUTBOX
function ircToShoutbox() {
	#Variables for the bridge
	trap cleanup TERM QUIT

	function sendMessage() {
		channelname=`cat $messagefile | cut -d: -f1`
		message=`cat $messagefile | cut -d: -f2-`
		echo "PRIVMSG #$channelname :$message" >> $ircConfig
	}
	function cleanup() {
		rm $ircConfig
	}

	function ircMakeBridge() {

		echo -e "PASS $serverpass\nNICK $nick\nUSER $nick +i * :abot\n" >> $ircConfig
		first=0
		tail -f $ircConfig | nc $server 6667 | while read MESSAGE; do
			ircToShoutboxPid=$BASHPID
			echo "$ircToShoutboxPid" > $pidfile
			trap sendMessage USR1
			if [[ "$MESSAGE" == *"please choose a different nick"* ]] && ((first==0)); then  
				sleep 1
				echo -e "PRIVMSG NickServ IDENTIFY $botpass" >> $ircConfig
				for channel in $(echo -e "$channels"); do
					echo -e "JOIN #$channel" >> $ircConfig
				done
				first=1
			fi
			case "$MESSAGE" in
				PING*) echo "PONG${MESSAGE#PING}" >> $ircConfig;;
	    		*QUIT*) ;;
	    		*PART*) ;;
	    		*JOIN*) ;;
				*KICK*) 
						channelname=`echo -e "$MESSAGE" | cut -d# -f2 | cut -d' ' -f1`
						echo "KICKED FROM $channelname attempting rejoin" | tee -a $logfile
						echo "JOIN #$channelname" >> $ircConfig
						;;
				*PRIVMSG*) 
						channelname=`echo -e "$MESSAGE" | cut -d# -f2 | cut -d' ' -f1`
						if [[ "$MESSAGE" == *"$supportedChannelToShoutbox"* ]]; then 
							if [[ "$MESSAGE" != *"IRC #$supportedChannelToShoutbox||"* ]]; then 
								text=`echo -e "$MESSAGE" | grep -ioP "PRIVMSG.*$" | cut -d: -f2-`
								user=`echo -e "$MESSAGE" | cut -d! -f1`
	    	                	htll && postToChatApi "IRC #$supportedChannelToShoutbox|| $user: $text" 
	    	                	echo "IRC #$channelname | $user: $text" | tee -a $logfile
	    	                fi
						fi
						;;
	    		*NICK*) ;;
				*)
					echo -e "$MESSAGE" | tee -a $logfile;;
				esac
		done	
	}
}	

# BRIDGE SHOUTBOX => IRC
function shoutboxToIrc() {
	#Locate the Pid of the other bridge
	function getPid() {
		ircToShoutboxPid=`cat $pidfile`
	}

	#Update the message file and send the USR1 signal
	function sendToIrc() {
		if [ -z "$ircToShoutboxPid" ]; then getPid; fi
		user="$1"
		text="$2"
		if [[ "$text" != *"HTLL||"* ]] && [[ "$user" != *"HTLL||"* ]] && 
			[ -n "$user" ] && [ -n "$text" ]; then 
			echo "$supportedChannelToShoutbox: HTLL|| $user $text" > $messagefile
			echo "Attempting USR1 to: $ircToShoutboxPid"
			kill -USR1 $ircToShoutboxPid
		fi
	}
	# Strip out BBCode
	function stripBBCode() {
		uglyMessage="$1"
		text=$(echo -e "$uglyMessage" | sed -E "s/\[COLOR=#......]//")
		text=$(echo -e "$text" | sed -E "s/\[USER=(.|..|...|....)\]//")
		text=$(echo -e "$text" | sed -E "s/\[\/COLOR\]//")
		text=$(echo -e "$text" | sed -E "s/\[\/URL\]//")
		text=$(echo -e "$text" | sed -E "s/\[URL\]//")
		text=$(echo -e "$text" | sed -E "s/\[\/USER\]//")
	}
	# Create our bridge 
	function shoutboxMakeBridge() {
		firstRun=0
		lastMessageTimeStamp=""
		while :; do
			htll && lastTenMessages || echo "Failed to connect to HTLL" || sleep 10
			timestamps=`echo "$latestTen" | jq -r .date | sort`
			if ((firstRun==0)); then 
				lastMessageTimeStamp=`echo -e "$timestamps" | tail -1`
				firstRun=1
			fi
			for i in `echo -e $timestamps`; do
				if ((i>lastMessageTimeStamp)); then
					message=`echo -e "$latestTen" | jq -r "select(.date==\"$i\")"`
					user=`echo -e  "$message" | jq -r .user`
					text=`echo -e "$message" | jq -r .text`
					stripBBCode "$text"
					sendToIrc "$user" "$text"
				fi
			done
			lastMessageTimeStamp=`echo -e "$timestamps" | tail -1`
			sleep 5
		done
	}
}

function connectBoth() {
	ircToShoutbox && ircMakeBridge &
	shoutboxToIrc && shoutboxMakeBridge &
}
connectBoth 
