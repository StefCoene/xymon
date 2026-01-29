#!/bin/sh

# This has the same functionality as the xymon binary but uses wget for communication.
# There is also a wget variant.

# First parameter is XYMSRV
if test -z "$1"
then
   echo Xymon curl client
   echo Usage: $0  RECIPIENT DATA
   echo RECIPIENT: IP-address, hostname or URL
   echo DATA: Message to send, or "-" to read from stdin
   exit
else
   XYMSRV=$1
fi

# Second parameter is the message to be sent
if test -z "$2"
then
   echo Xymon curl client
   echo Usage: $0 RECIPIENT DATA
   echo RECIPIENT: IP-address, hostname or URL
   echo DATA: Message to send, or "-" to read from stdin
   exit
else
   messageOption=$2
fi

# If XYMSRV=0.0.0.0, use XYMSERVERS
if test "$XYMSRV" = "0.0.0.0"
then
   if test -z "$XYMSERVERS"
   then
      echo Abort: XYMSERVERS variable not set
      exit
   fi
else
   XYMSERVERS=$XYMSRV
fi

# If the messageOption is - or @, read the message from STDIN
if test "$messageOption" = "-" -o "$messageOption" = "@"
then
   message=$(cat -)
else
   message=$messageOption
fi

# Make sure some basic config is set
if test -z "$XYMONMSGURL" ; then
   XYMONMSGURL=/xymon-msg
fi
if test -z "$XYMONMSGURLPROTO" ; then
   XYMONMSGURLPROTO=https
fi
if test -z "$XYMONMSGURLPORT" ; then
   XYMONMSGURLPORT=443
fi

## Loop the servers in XYMSRV and sent the message with curl
for XYM in $XYMSERVERS
do
   # Assemble the URL to be used
   URL=$XYMONMSGURLPROTO://$XYM:$XYMONMSGURLPORT$XYMONMSGURL

   # Sent message line bij line if - is specified as command line option
   if test "$messageOption" = "-"
   then
      # Set IFS to newline so we can read the message line by line
      IFS='
'
      for line in $message
      do
         curl \
            --config $XYMONHOME/etc/curl.cfg \
            $URL \
            --data-binary "$line"
      done
   else
      # If we receive a file as message, we simply post this file
      if test -f "$message"
      then
         curl \
            --config $XYMONHOME/etc/curl.cfg \
            $URL \
            --data-binary @$message
      else
         echo "$message" | curl \
            --config $XYMONHOME/etc/curl.cfg \
            $URL \
            --data-binary @-
      fi
   fi
done
