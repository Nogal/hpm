#!/usr/bin/env ruby 

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

require 'fileutils'

def helpPage()
    # A friendly little help page. 

    puts "Usage"
    puts "    hpkg (options) {package}"
    puts ""
    puts "Options include:"
    puts "    install           :       install selected binary package(s) from repository"
    puts "    source-install    :       install selected package(s) from source"
    puts "    local-install     :       install selected local package(s)"
    puts "    remove            :       remove selected package(s)"
    puts "    clean             :       clean the cache"
    puts "    update            :       update the cache (CURRENTLY UNAVAILABLE)"
    puts "    upgrade           :       upgrade current packages (CURRENTLY UNAVAILABLE)"
    puts "    help              :       view this help page" 
    puts ""
    return 0
end

def clean()
    puts "Cleaning Cache: "
    FileUtils::Verbose.rm_rf("/opt/hpkg/tmp/*")
    puts "Cache Cleaned"
end

def hpkgmv(packageName, source, dest)
    FileUtils.cd("/opt/hpkg/tmp/#{packageName}/")
    FileUtils.mv(source, dest)
end

def gethpkg(packageName, mirror)
    puts `wget -c -0 /opt/hpkg/tmp/#{packageName}.hpkg #{mirror}/#{packageName}`
end

def checkFile( file, string )
    # Check whether or not the string is within the contents of the file
    File.open( file ) do |io|
    io.each {|line| line.chomp! ; return true if line.include? string}
    end
end    

def exthpkg(packageName)
    puts `tar -xf /opt/hpkg/tmp/#{packageName}.hpkg`
end

def install(packageName)
    # Open the control file and read the pertinent information.
    f = File.open("/opt/hpkg/tmp/#{packageName}/#{packageName}.control", "r")
    data = f.read 
    f.close
    binfile = data.match(/(?<=BIN_FILE: ).+$/)
    binpath = data.match(/(?<=BIN_PATH: ).+$/)
    conscript = data.match(/(?<=CONSCRIPT: ).+$/)
    tempdeplist = data.match(/(?<=DEPLIST: ).+$/)
    deplist = tempdeplist.split
    pkgver = data.match(/(?<=PKGVER: ).+$/)
    desktopentry = "/opt/hpkg/tmp/#{packageName}/#{packageName}.desktop"
    # mirror = # hmmm.
    
    # CHECK MIRROR STATUS ..... somehow

    #Query the database
    puts "Querying Database..."
    dbFile = File.open("/etc/hpkg/pkdb/inpk.pkdb", "r")
    if checkFile(dbFile, "#{packageName}.#{pkgver}") == true 
        puts "Package already installed"
    else
        puts "List of dependencies to be installed: "
        puts deplist

        proceed = gets
        proceed = proceed.chomp

        if proceed == "Y" || proceed == "y"
            puts "Beginning Installation"
            gethpkg(packageName, mirror)
            exthpkg(packageName)
            deplist.each {|dependency| install(dependency)}   ####   THIS NEEDS TO BE INTEGRATED INTO THE REST

        hpkgmv(packageName, binfile, binpath)
        puts `#{conscript}`

        puts "Registering packgages in database"
        open('/etc/hpkg/pkdb/inpk.pkdb', 'a') { |database| 
               database.puts "#{packageName}.#{pkgver}" }
               
        FileUtils.mv(desktopentry, "/usr/share/applications/")
        FileUtils.mv("/opt/hpkg/tmp/#{packageName}.control", "/etc/hpkg/controls/")  
        else
            puts "Aborting Installation"
        end
    end
    dbFile.close
end

def localinstall(packageName)
    # Open the control file and read the pertinent information.
    f = File.open("/opt/hpkg/tmp/#{packageName}/#{packageName}.control", "r")
    data = f.read 
    f.close
    binfile = data.match(/(?<=BIN_FILE: ).+$/)
    binpath = data.match(/(?<=BIN_PATH: ).+$/)
    conscript = data.match(/(?<=CONSCRIPT: ).+$/)
    tempdeplist = data.match(/(?<=DEPLIST: ).+$/)
    deplist = tempdeplist.split
    pkgver = data.match(/(?<=PKGVER: ).+$/)
    desktopentry = "/opt/hpkg/tmp/#{packageName}/#{packageName}.desktop"

    #Query the database
    puts "Querying Database..."
    dbFile = File.open("/etc/hpkg/pkdb/inpk.pkdb", "r")
    if checkFile(dbFile, "#{packageName}.#{pkgver}") == true 
        puts "Package already installed"

    else
        puts "List of dependencies to install:"
        puts deplist
        puts "Proceed with package installation? "
        proceed = gets
        proceed = proceed.chomp

        if proceed == "Y" || proceed == "y"
            puts "Beginning Installation: "
            deplist.each {|dependency| install(dependency)}   ####   THIS NEEDS TO BE INTEGRATED INTO THE REST

            # Move BIN_FILE to BIN_PATH from .control file. 
            hpkgmv(a, binfile, binpath)
            puts "Moving: #{packageName} from #{binfile} to #{binpath}"
                
            # Run the control script
            puts `#{conscript}`

            # Register packages within the database
            puts "Registering packages in database"
            open('/etc/hpkg/pkdb/inpk.pkdb', 'a') { |database| 
                    database.puts "#{packageName}.#{pkgver}" }
                
            FileUtils.mv(desktopentry, "/usr/share/applications/")
            FileUtils.mv("/opt/hpkg/tmp/#{packageName}.control", "/etc/hpkg/controls/")  
           
        else
            puts "Aborting Installation"
        end
    end
    dbFile.close
end

# Get argument values and set them to the variables:
ARGV
action = ARGV.shift
packages = ARGV    

# Decide which course of action to take
case action
    when "install"; packages.each {|package| install(package)}
    when "remove"; packages.each {|package| remove(package)}
    when "source-install"; packages.each {|package| sourceinstall(package)}
    when "local-install"; packages.each {|package| localinstall(package)}
    when "clean"; clean
    when "update"; update
    when "upgrade"; upgrade
    else helpPage
end
