#!/bin/bash

#Set your HTLL Username and Password here
username='subv32'
password=''
htllApiKey=""

messagefile=/tmp/irc-message.log # Used to communicate between the bridges
pidfile=/tmp/irc-bridge.pid # Used to communicate between the bridges
ircConfig=/tmp/ircbot.conf # Don't touch
logfile=/tmp/ircbot.log # IRC log
nick="astupidbot"  #Nickname of the IRC Bot
botpass="" # Bot nickserv password
supportedChannelToShoutbox="HTLL" # Channel we bridge Shoutbox => IRC (currently only support 1)
channels="test HTLL" # Channels we join / bridge IRC => Shoutbox
server=irc.propwn.uk.to # IRC Server
serverpass="" # IRC password


