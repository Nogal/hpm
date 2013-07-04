#!/bin/bash

ARGS=("$@")
mirror=$ARGS

function testmirror() {
echo $mirror
pingTest=`ping -c4 $mirror &>/dev/null`

if [ $? ==  0 ]; then
    echo "true"
    return 10
else
    echo "false"
    return 20
fi
}

testmirror $mirror

