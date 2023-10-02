#!/bin/sh

l="$1"
lt="$2"
[ -n "$l" ] || exit
[ -n "$lt" ] || exit
docker images | grep "$l" | sed -e 's|[[:space:]].*||' | while read dname ; do
    newname="$(echo "$dname" | sed -e "s|$l|$lt|")"
    echo "$dname -> $newname"
    [ -n "$force" ] || continue
    docker tag $dname:latest $newname:latest
    docker rmi $dname:latest
done
