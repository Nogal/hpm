#!/bin/sh

mirror=$(cat /etc/hpkg/mirrors/mirror.lst)


function testmirror () {

for i in $mirror ; do ping -c4 $i; done }

testmirror

if [ $? -eq 0 ]; then
    echo "Connected."

else

    echo "Mirror not found."
fi



