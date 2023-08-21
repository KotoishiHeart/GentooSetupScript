#!/bin/bash

mkdir -p /usr/local/firestorm/
cd /usr/local/firestorm/
git clone https://vcs.firestormviewer.org/fs-build-variables
export AUTOBUILD_VARIABLES_FILE=/usr/local/firestorm/fs-build-variables/variables

if [ -d ./phoenix-firestorm ]; then
	git clone https://vcs.firestormviewer.org/phoenix-firestorm
	cd ./phoenix-firestorm
else
	git reset --hard HEAD
	git fetch
	LOCAL_HASH=`git rev-parse HEAD`
	REMOTE_HASH=`git rev-parse origin/master`
	if [ "$LOCAL_HASH" = "$REMOTE_HASH" ]; then
		exit
	else
		git pull
	fi
fi
CORES=`grep cpu.cores /proc/cpuinfo | sort -u | sed 's/[^0-9]//g'`
JOBS=`bc <<< "scale=0; 10*((1.4*${CORES})+0.5)/10;"`
curl https://download.airanyumi.net/firestorm-viewer/patches/program_backup_place_change.patch | patch -N -u -p1
autobuild installables edit fmodstudio platform=linux64 hash=d4d484327c9be53d479c807332de4f06 url=https://download.airanyumi.net/firestorm-viewer/fmodstudio-2.02.16-linux64-232100740.tar.bz2
autobuild configure -A 64 -c ReleaseFS_open -- --fmodstudio --no-opensim --avx2 --package --clean --ninja --btype Release --jobs ${JOBS} --chan 'Master'
if [ ! -e ./build-linux-x86_64/build.ninja ]; then
	exit
fi
autobuild build -A 64 -c ReleaseFS_open -- --no-configure --ninja --jobs ${JOBS}
ls ./phoenix-firestorm/build-linux-x86_64/newview/.Firestorm-x86_64-*.touched >/dev/null 2>&1
if [ $? -ne 0 ]; then
	exit
else
	PACKAGE_FILE=`find . -name 'Phoenix*.tar.xz'`
	cp $PACKAGE_FILE ../
fi
