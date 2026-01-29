#!/bin/sh

if [ "$XYMSRV" = "" ]
then 
   echo Executing with xymon wrapper:
   echo xymoncmd $0 $@
   exit 
fi

if command -v curl >/dev/null 2>&1; then
   clienttest=`echo $XYMONCLIENTHOME/bin/xymon-curl.sh \\\$XYMSRV \\"ping\\" | $XYMONCLIENTHOME/bin/xymoncmd /bin/bash`
   echo "curl found"
   if expr "$clienttest" : "xymond [0-9]" >/dev/null; then 
      CLIENTEXEC=xymon-curl.sh
      echo "Xymon server reachable ($clienttest) so using '$CLIENTEXEC'"
   else
      echo "Xymon server NOT reachable"
   fi
fi
if test -x $CLIENTEXEC ; then
   clienttest=`echo $XYMONCLIENTHOME/bin/xymon-wget.sh \\\$XYMSRV \\"ping\\" | $XYMONCLIENTHOME/bin/xymoncmd /bin/bash`
   echo "wget found"
   if expr "$clienttest" : "xymond [0-9]" >/dev/null; then
      CLIENTEXEC=xymon-wget.sh
      echo "Xymon server reachable ($clienttest) so using '$CLIENTEXEC'"
   else
      echo "Xymon server NOT reachable"
   fi
fi 

if test -z "$CLIENTEXEC"; then
   echo "No working curl or wget found so using binary"
   CLIENTEXEC=xymon.bin
fi

echo

if file $XYMONCLIENTHOME/bin/xymon | grep -q executable ; then
   echo $XYMONCLIENTHOME/bin/xymon is an executable so moving it to $XYMONCLIENTHOME/bin/xymon.bin
   echo "  Executing: mv $XYMONCLIENTHOME/bin/xymon $XYMONCLIENTHOME/bin/xymon.bin"
   mv $XYMONCLIENTHOME/bin/xymon $XYMONCLIENTHOME/bin/xymon.bin
fi

echo Creating symlink 
echo "   Executing: ln -sf $XYMONCLIENTHOME/bin/$CLIENTEXEC $XYMONCLIENTHOME/bin/xymon"
ln -sf $XYMONCLIENTHOME/bin/$CLIENTEXEC $XYMONCLIENTHOME/bin/xymon

