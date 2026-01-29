#!/bin/sh

# This has the same functionality as the xymon binary but uses wget for communication.
# There is also a curl variant.

# For wget, we have to work with a temporary file to store the data.

export WGETRC=$XYMONHOME/etc/wget.cfg

# First parameter is XYMSRV
if test -z "$1"
then
   echo Xymon wget client
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
   echo Xymon wget client
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

## Loop the servers in XYMSRV and sent the message with wget
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
         echo "$line" > $XYMONHOME/tmp/wget.$$
         wget \
            --post-file=$XYMONHOME/tmp/wget.$$ \
            --quiet \
            -O - \
            $URL
         rm $XYMONHOME/tmp/wget.$$
      done
   else
      # If we receive a file as message, we simply post this file
      if test -f "$message"
      then
         wget \
            --post-file=$message \
            --quiet \
            -O - \
            $URL
      else
         echo "$message" > $XYMONHOME/tmp/wget.$$
         wget \
            --post-file=$XYMONHOME/tmp/wget.$$ \
            --quiet \
            -O - \
            $URL
         rm $XYMONHOME/tmp/wget.$$
      fi
   fi
done
