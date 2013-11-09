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

#This script is used to install hpm onto Unix-like Operating Systems.

#These bangs are for other unix platforms. Just uncomment them and comment out #!/bin/sh in order to port it to a different architecture.

# #!/usr/bin/sh (HP-UX)
# #!/bin/ksh (AIX)

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

mkdir -p /etc/hpm/controls
mkdir -p /etc/hpm/conflist
mkdir -p /etc/hpm/mirrors
mkdir -p /etc/hpm/pkdb/uinfo
mkdir -p /etc/hpm/pkdb/upinfo
mkdir -p /etc/hpm/pkginfo
mkdir -p /opt/hpm/build/tmp
mkdir -p /opt/hpm/tmp
touch /etc/hpm/mirrors/mirror.lst
touch /etc/hpm/pkdb/inpk.pkdb

#wget -c -O /tmp/hpm.tar.gz http://www.descentos.net/repository/hpm-current.tar.gz
wget -c -O /tmp/hpm.tar.gz ftp://nogal-laptop/hpm.tar.gz

cd /tmp/
tar -xzf /tmp/hpm.tar.gz

mv /tmp/hpm/hpm /usr/bin/hpm
mv /tmp/hpm/mirrors.txt /etc/hpm/mirrors

cat /etc/hpm/mirrors/mirrors.txt

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

echo $choice > /etc/hpm/mirrors/mirrors.txt

sleep 2

echo "Mirror selected."

hpm update

echo "Installing HPM base packages."

mv /tmp/hpm/compgen /etc/bash_completion.d/hpm

echo "Cleaning up..."

rm /tmp/hpm.tar.gz
rm -rf /tmp/hpm

sleep 3

echo "HPM installed."
