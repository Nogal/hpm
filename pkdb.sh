#!/bin/sh

#This is the interface script to interact with the very, very simple database for HybridPacKaGe Manager called PKDB

#The MIT License (MIT)

#Copyright (c) <2013> <Brian Manderville ; Brian McCoskey; Descent|OS>

#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:

#The above copyright notice and this permission notice shall be included in
#all copies or substantial portions of the Software.

#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#THE SOFTWARE.

echo "Welcome to PKDB."
#Bwahaha

case $1 in

	-q) echo "What Package are you looking for?"
			read package
				cat /etc/hpkg/pkdb/inpk.pkdb | if grep $package == true then echo "`$package` is installed." else echo "Package not found in database." ;; #Does this even work?
		;;
		-d|--dump)
			cat /etc/hpkg/pkdb/inpk.pkdb ;;
-v|--version)
	echo "0.0.1" #Obviously
	
;;
	-h|--help)
		echo " "
        echo "-q : Queries the database for a certain package."
		echo "-d : Dumps database contents. Can be utilized with a redirect: pkdb -d > pkdb.txt"
		echo "-v : Displays version number."
		echo "-h : Displays help dialogue."
		echo "-l : Displays MIT License."
;;
		-l|-license)
			echo `cat /etc/hpkg/mit.txt` ;;
			
			
esac

