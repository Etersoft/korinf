#!/bin/sh
su - builder -c "/srv/builder/Projects/korinf/robot/watchbuilder.sh $1 >/dev/null 2>/dev/null &"
