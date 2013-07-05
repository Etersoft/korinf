#!/bin/sh
su - builder -c "/srv/builder/Projects/korinf/robot/queuewatcher.sh $1 >/var/log/queuebuild.log 2>&1 &"
sleep 2
