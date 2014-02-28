#!/bin/sh
readonly PATH_TO_FILES='/some/path'
echo $PATH_TO_FILES

func()
{
	readonly local PF='/some/path'
	echo $PF
	# Can't override local readonly
	#PF=2
	#echo $PF
	# Can't override global readonly var
	local PATH_TO_FILES
	PATH_TO_FILES=e
}

func

