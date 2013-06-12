#!/bin/sh 
 
#The MIT License (MIT) 
 
#Copyright (c) <2013> <Brian Manderville; HighWater OS> 
 
#Permission is hereby granted, free of charge, to any person obtaining a copy 
#of this software and associated documentation files (the "Software"), to deal 
#in the Software without restriction, including without limitation the rights 
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
#copies of the Software, and to permit persons to whom the Software is 
#furnished to do so, subject to the following conditions 
 
#The above copyright notice and this permission notice shall be included in 
#all copies or substantial portions of the Software. 
 
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
#THE SOFTWARE. 
 
 
#Okay, brian2040 here... 
#This is basically what I've managed to cobble together so far 
#With my extremely inexperienced bash scripting, I have written functions 
#That can install, source install, local install, and clean cache's 
#What I need to do is link them together, and be able to call on them this way. 
#Yes, the code is shit. But it's good shit. 
 

# Get user input for both what function is to be called as well as which 
# packages are to be quereied

ARGS=("$@")      
function_name=$ARGS[0]   
package_name=${ARGS[@]:1}   

case $function_name in
    'install') installpkg ;;
    'remove')  remove  ;;
    'source-install') sourceinstall ;;
    'local-install') localinstall ;;
    'clean') clean ;;
    'update') update ;;
    'upgrade') upgrade ;;
    *) help_page ;;
esac

function help_page ()
{
    # A friendly little help page. 

    echo "Usage:"
    echo "    hpkg (options) {package}"
    echo 
    echo "Options include:"
    echo "    install           :       install selected binary package(s) from repository"
    echo "    source-install    :       install selected package(s) from source"
    echo "    local-install     :       install selected local package(s)"
    echo "    remove            :       remove selected package(s)"
    echo "    clean             :       clean the cache"
    echo "    update            :       update the cache (CURRENTLY UNAVAILABLE)"
    echo "    upgrade           :       upgrade current packages (CURRENTLY UNAVAILABLE)"
    echo "    help              :       view this help page"
    }
    
function installpkg () { 
     
    # $package_name=$@ 
    $iftbe=0 
    $binfile= `sh /opt/hpkg/tmp/$package_name/$package_name\.control BIN_FILE` 
    $binpath= `sh /opt/hpkg/tmp/$package_name/$package_name\.control BIN_PATH` 
    $conscript= `sh /opt/hpkg/tmp/$package_name/$package_name\.control CONSCRIPT ` 
    $hpkgmv= `cd /opt/hpkg/tmp/$package_name/ ; mv ` 
    $gethpkg= `wget -c -O /opt/hpkg/tmp/$package_name\.hpkg $mirror1\/$package_name` 
    $exthpkg= `tar -xf /opt/hpkg/tmp/$package_name\.hpkg` 
    $deplist= `sh /opt/hpkg/tmp/$package_name/$package_name\.control DEPLIST` 
    $desktopentry= `echo /opt/hpkg/tmp/$package_name/$package_name\.desktop` 
    $pkgver= `sh /opt/hpkg/tmp/$package_name/$package_name\.control PKGVER` 
     
    #So I like variables. Fuck me, right? 
         
    echo "Checking Mirror Status..." 
    while [ $iftbe -ne 1 ]; do 
        ping -c 4 $mirror 
        if [ $? -eq 0 ]; then 
                echo "Mirror connected"; 
                say connected 
                    iftbe=1 
                else 
                    echo "Unable to connect. Try updating your mirrors or checking your internet connection." 
                fi 
            done 
    echo "Querying Database..." 
    cat /etc/hpkg/pkdb/inpk.pkdb | if grep $package_name\.$pkgver == true then echo "Package already installed." 
    else 
    echo"List of dependencies to install" 
    echo $deplist 
 
    read -p "Proceed with package installation? " -n 1 -r 
 
    if [[ $REPLY =~ ^[Yy]$ ]] 
     
    then 
    echo "Beginning Installation." 
    $gethpkg 
    $exthpkg 
    hpkg install $deplist 
    $hpkgmv $binfile $binpath 
    $conscript             
    echo "Registering packages in database" 
    echo $package_name\.$pkgver >> /etc/hpkg/pkdb/inpk.pkdb 
    mv $desktopentry /usr/share/applications/ 
    mv /opt/hpkg/tmp/$package_name\.control /etc/hpkg/controls/ 
    sleep 2 #Yes, you're sleeping so you look more productive than you are. 
     
    echo "Package installed." 
     
    else 
        echo "Installation Aborted." 
         
    fi     
        } 
         
function sourceinstall () { 
    # $package_name=$@ 
    iftbe=0     
    echo "Checking connectivity" 
     
    while [ $iftbe -ne 1 ] ; do 
        ping -c 4 $mirror 
        ping -c 4 $mirror2 
        if [ $? -eq 0 ]; then 
            echo "Connected"; 
            say connected 
                iftbe=1 
                else 
                    echo "Unable to connect. Check your network connection." 
                fi 
            done 
 
            wget -c -O /opt/hpkg/tmp/$package_name\.hpkgbuild $mirror1\/source/$package_name\.hpkgbuild 
    sh /opt/hpkg/tmp/$package_name\.hpkgbuild #Kind of slackware-like, but they're install scripts! Maybe it should be packaging scripts a la AUR? 
} 
 
function localinstall () { 
# $package_name=$@ 
$binfile= `sh /opt/hpkg/tmp/$package_name/$package_name\.control BIN_FILE` 
$binpath= `sh /opt/hpkg/tmp/$package_name/$package_name\.control BIN_PATH` 
$conscript= `sh /opt/hpkg/tmp/$package_name/$package_name\.control CONSCRIPT ` 
$hpkgmv= `cd /opt/hpkg/tmp/$package_name/ ; mv ` 
$exthpkg= `tar -xf /opt/hpkg/tmp/$package_name\.hpkg` 
$deplist= `sh /opt/hpkg/tmp/$package_name/$package_name\.control DEPLIST` 
$desktopentry= `echo /opt/hpkg/tmp/$package_name/$package_name\.desktop` 
$pkgver= `sh /opt/hpkg/tmp/$package_name/$package_name\.control PKGVER` 
 
echo "Querying Database..." 
cat /etc/hpkg/pkdb/inpk.pkdb | if grep $package_name\.pkgver == true then echo "Package already installed." 
else 
echo"List of dependencies to install" 
echo $deplist 
    read -p "Proceed with package installation? " -n 1 -r 
    if [[ $REPLY =~ ^[Yy]$ ]] then 
echo "Beginning Installation." 
hpkg -install $deplist 
$hpkgmv $binfile $binpath 
$conscript 
#How I imagine people reading this code right now. t(-.-t) 
echo "Registering packages in database" 
echo $package_name\.$pkgver >> /etc/hpkg/pkdb/inpk.pkdb 
mv $desktopentry /usr/share/applications/ 
mv /opt/hpkg/tmp/$package_name\.control /etc/hpkg/controls/ 
    sleep 2 #I should buy a boat. 
    else 
        echo "Aborting Installation." 
        sleep 1 
    -e 
fi 
 
#This was actually really easy. 
 
    } 
 
#function upgrade () { 
#    } 
 
function clean () { 
    echo "Cleaning Cache" 
    rm -rfv /opt/hpkg/tmp/* 
    sleep 1 
    echo "Cache Cleaned" 
    } 
     
#Oh, I'm sorry, you thought cache's were complex? 
     
#function update { 
#     echo "Function will be implemented when a cache is implemented" 
#    #This function isn't really viable at this current moment, unfortunately. Come back later when I figure out what the hell I'm scripting 
#}  
 
function remove () { 
    # $package_name=$@ 
    $db_file= ` echo /etc/hpkg/pkdb/inpk.pkdb` 
    #And now I'm tired, and want to sleep. Too tired for regex 
        } 
     
    #Total people killed in process of reading this shit = 1 

