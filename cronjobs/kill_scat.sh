#!/usr/bin/bash
# this file should (almost definitely) be run
# by the "uglymug" user

# variables - your flexible friend
if [ "$HOSTNAME" = "chiztop.herlpacker.co.uk" ]; then
	# chisel developing/testing the script
	GAME_DIR=/home/chisel/Development/SourceForge/UglyCODE
	LOGFILE=${GAME_DIR}/uglymug.log
else
	# the default location for the live stuff
	GAME_DIR=/export/home/uglymug/game
	LOGFILE=${GAME_DIR}/logs/uglymug.log
fi

SCAT_BINARY=scat
SCAT_PID=scat.pid
SCAT_TIMESTAMP=scat.lastkilled

# set DEBUG to "false" to hide debugging messages
DEBUG=false
#DEBUG=

if [ "$OSTYPE" = "linux-gnu" ]; then
	PS_ARGS=aux
elif [ "$MACHTYPE" = "sparc-sun-solaris" ]; then
	PS_ARGS=-Afe
else
	PS_ARGS=aux
fi

# does scat.pid exist?
if [ ! -f ${GAME_DIR}/${SCAT_PID} ]; then
	echo "can't find $SCAT_PID in $GAME_DIR- I honestly don't know what to kill"
	exit
fi

# let's get the process-id that it claims to be running as
SCAT_ID=`cat ${GAME_DIR}/${SCAT_PID}`
${DEBUG} echo "$SCAT_BINARY claims to be running with PID=$SCAT_ID"

# do we have a process running with PID of SCAT_ID?
# grep the process list for our PID. we want whitespace
# around it so we don't match processes that 'just happen'
# to have our PID as a substring. we also 'grep out' any results
# with grep in them
PID_COUNT=`ps $PS_ARGS | grep -v grep |grep -c " $SCAT_ID "`
${DEBUG} echo "'ps | grep' gave $PID_COUNT match(es)"

if [ $PID_COUNT -eq 0 ]; then
	echo "There are no processes that match a process-id of $SCAT_PID!"
	echo "This implies that $SCAT_BINARY has kicked the bucket!"
	exit
fi

# now we extend the grep to check that it appears to be
# scat running on the process-id
PID_COUNT=`ps $PS_ARGS | grep -v grep | grep "$SCAT_BINARY " | grep -c " $SCAT_ID "`
${DEBUG} echo "'ps | grep' gave $PID_COUNT match(es)"

if [ $PID_COUNT -eq 0 ]; then
	echo "process $SCAT_ID doesn't seem to be $SCAT_BINARY!"
	echo "This implies that $SCAT_BINARY has kicked the bucket!"
	exit
fi

# now we are fairly happy that we have a process running
# with the expected process-id and also that the process with
# that id is scat
#
# let's send it the USR1 signal
kill -USR1 $SCAT_ID

# make sure the outfile is GROUP writable
chmod 0664 $LOGFILE
