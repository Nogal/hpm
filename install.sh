#!/bin/sh


#The MIT License (MIT)
#
#Copyright (c) <2013> <Brian Manderville, Brian McCoskey, Descent|OS>
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in
#all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#THE SOFTWARE.
#
#
#

#This script is used to install hpkg onto Unix-like Operating Systems.

#These bangs are for other unix platforms. Just uncomment them and comment out #!/bin/sh in order to port it to a different architecture.

# #!/usr/bin/sh (HP-UX)
# #!/bin/ksh (AIX)

if UID=0 then

echo "This script will proceed after 5 seconds... If you do not wish to proceed, hit Control + C before the countdown ends. Good luck."
sleep 1
echo "5"
sleep 1
echo "4"
sleep 1
echo "3"
sleep 1
echo "2"
sleep 1
echo "1"
sleep 1
echo "0"
sleep 1

echo "Installation proceeding."

mkdir -p /etc/hpkg/controls
mkdir -p /etc/hpkg/mirrors
mkdir -p /etc/hpkg/pkdb/uinfo
mkdir -p /etc/hpkg/pkginfo
mkdir -p /opt/hpkg/tmp

wget -c -O /tmp/hpkg.tar.gz http://www.descentos.net/repository/hpkg-current.tar.gz

tar -xzf /tmp/hpkg.tar.gz

mv /tmp/hpkg/opt/hpkg /opt/hpkg
mv /tmp/hpkg/etc/hpkg /etc/hpkg
mv /tmp/hpkg/bin/hpkg /usr/bin
mv /tmp/hpkg/bin/pkdb /usr/bin

cat /etc/hpkg/mirrorchoices.txt

echo " "
echo " "
echo " "
echo "Here are your choices to for your main mirror. These mirrors are for the base HighwaterOS repositories, all of them are the same, but the locations are different."
sleep 2
echo " "
echo " "
echo "Please input your mirror URL. Mirrors are sorted by Architectures and Operating Systems"
echo " "

read choice

echo $choice > /etc/hpkg/mirrors/mirrors.txt

sleep 2

echo "Mirror selected."

hpkg update

echo "Installing HPKG base packages."

complete -W install\ remove\ source-install\ local-install\ clean\ update\ upgrade hpkg
hpkg install hpkg_meta

echo "Cleaning up..."

rm -rf /tmp/hpkg.tar.gz
rm -rf /tmp/hpkg

sleep 3

echo "HPKG installed."

else

echo "ERROR!"
echo "SCRIPT MUST BE RAN AS ROOT!"
echo "User is not root. Exiting."

fi

