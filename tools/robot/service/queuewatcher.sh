#!/bin/sh
su - builder -c "/home/builder/Projects/eterbuild/robot/queuewatcher.sh $1 >/var/log/queuebuild.log 2>&1 &"
sleep 2
