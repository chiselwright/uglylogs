#!/usr/bin/bash
# this file should (almost definitely) be run
# by the "uglymug" user

# variables - your flexible friend
if [ "$HOSTNAME" = "chiztop.herlpacker.co.uk" ]; then
	# chisel developing/testing
	LOG_DIR=/home/chisel/Development/SourceForge/UglyCODE
	PROCESSFILEDIR=/home/chisel/Development/SourceForge/UglyLogs/data/archives
	SENDLOG_DIR=/home/chisel/Development/SourceForge/UglyLogs/bin
else
	# default live locations
	LOG_DIR=/export/home/uglymug/game/logs
	PROCESSFILEDIR=/export/home/uglymug/uglylog/UglyLogs/data/archives
	SENDLOG_DIR=/export/home/uglymug/uglylog/UglyLogs/bin
fi

SENDLOGS=sendlogs
LOGFILE=uglymug.log

# set DEBUG to "false" to hide debugging messages
DEBUG=false
#DEBUG=

# commands/binaries
GZIP="gzip --best"

# does $SENDLOG_DIR exist?
if [ ! -d $SENDLOG_DIR ]; then
	echo "$SENDLOG_DIR doesn't exist. aborting."
	exit
fi

# does the specified logfile exist?
if [ ! -f ${LOG_DIR}/${LOGFILE} ]; then
	echo "${LOGFILE} can't be found in ${LOG_DIR}"
	exit
fi

# does the target directory exist?
if [ ! -d ${PROCESSFILEDIR} ]; then
	echo "target directory ${PROCESSFILEDIR} doesn't exist! aborting."
	exit
fi

# mv the file onto home territory
mv ${LOG_DIR}/${LOGFILE} ${PROCESSFILEDIR}

# check that we have a copy of the file
if [ ! -f ${PROCESSFILEDIR}/${LOGFILE} ]; then
	echo "${PROCESSFILEDIR}/${LOGFILE} doesn't exist!"
	echo "looks like 'mv' failed. aborting."
	exit
fi

# change to the directory
cd $SENDLOG_DIR
# run the script - use NICE!!!!
nice ./${SENDLOGS}

# archive the script
ARCHIVENAME=${PROCESSFILEDIR}/${LOGFILE}_`date +%Y%m%d_%H%M%S`
mv ${PROCESSFILEDIR}/${LOGFILE} ${ARCHIVENAME}

# if the file exists - compress it
if [ -f $ARCHIVENAME ]; then
	$GZIP ${ARCHIVENAME}
else
	echo "failed to compress $ARCHIVENAME. this isn't fatal. it's just a little irritating"
fi
