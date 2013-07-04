#!/usr/bin/env ruby

#The MIT License (MIT)

#Copyright (c) <2013> <Brian Manderville; Brian McCoskey; Descent|OS>

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
    puts " hpkg (options) {package}"
    puts ""
    puts "Options include:"
    puts " install : install selected binary package(s) from repository"
    puts " source-install : install selected package(s) from source"
    puts " local-install : install selected local package(s)"
    puts " remove : remove selected package(s)"
    puts " clean : clean the cache"
    puts " update : update the cache (CURRENTLY UNAVAILABLE)"
    puts " upgrade : upgrade current packages (CURRENTLY UNAVAILABLE)"
    puts " help : view this help page"
    puts ""
    return 0
end

def clean()
    puts "Cleaning Cache: "
    FileUtils::Verbose.rm_rf("/opt/hpkg/tmp/*")
    puts "Cache Cleaned"
end

def test_mirror()
    f = File.open("/etc/hpkg/mirrors/mirror.lst", "r")
    f.each_line { |line|

    tempstatus = `bash /bin/hpkg/resources/testmirror.sh #{line}` 
    status = tempstatus.split

    if status[-1] == "true" 
        puts "Connected to #{line}"
    elsif status[-1] == "false" 
        puts "Error Connecting to #{line}"
    else
        puts "Fail!"
    end
    } 
    f.close
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

def package_queue(packages)
    packages.each do |packageName|
        # Open the control file and read the pertinent information.
        f = File.open("/opt/hpkg/tmp/#{packageName}/#{packageName}.control", "r")
        data = f.read
        f.close
        tempdeplist = data.match(/(?<=DEPLIST: ).+$/)
        deplist = tempdeplist.split
        pkgver = data.match(/(?<=PKGVER: ).+$/)
    
        if deplist.empty? == false
            deplist.each {|dependency|
               if is_installed(packageName, pkgver) == false
                    if !packages.include?(dependency)
                        packages = dependency + packages
                        package_queue(packages)
                    end
                end
            }
        end
    end
end

def is_installed(packageName, pkgver)
    #Query the database
    puts "Checking #{packageName}..."
    dbFile = File.open("/etc/hpkg/pkdb/inpk.pkdb", "r")
    if checkFile(dbFile, "#{packageName}.#{pkgver}") == true
        puts "Package already installed"
        return true
    else
        puts "#{packageName} is to be installed."
        return false
    end
end

def sourceinstall(packageName)
    # Do some mirror magic...

    `wget -c -O /opt/hpkg/tmp/#{packageName}.hpkgbuild #{mirror}/source/#{packageName}.hpkgbuild`
    `sh /opt/hpkg/tmp/#{packageName}.hkpgbuild`
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

    # Get the required packages and extract them
    gethpkg(packageName, mirror)
    exthpkg(packageName)

    puts "Installing #{packageName}..."
    # Move BIN_FILE to BIN_PATH from .control file.
    hpkgmv(packageName, binfile, binpath)
    puts "Moving: #{packageName} from #{binfile} to #{binpath}"

    # Run the control script
    puts `#{conscript}`

    puts "Registering packgages in database"
    open('/etc/hpkg/pkdb/inpk.pkdb', 'a') { |database|
           database.puts "#{packageName}.#{pkgver}" }
           
    # Register packages within the database
    FileUtils.mv(desktopentry, "/usr/share/applications/")
    FileUtils.mv("/opt/hpkg/tmp/#{packageName}.control", "/etc/hpkg/controls/")
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

    puts "Installing #{packagName}..."

    # Move BIN_FILE to BIN_PATH from .control file.
    hpkgmv(packageName, binfile, binpath)
    puts "Moving: #{packageName} from #{binfile} to #{binpath}"
        
    # Run the control script
    puts `#{conscript}`

    # Register packages within the database
    puts "Registering packages in database"
    open('/etc/hpkg/pkdb/inpk.pkdb', 'a') { |database|
            database.puts "#{packageName}.#{pkgver}" }
        
    FileUtils.mv(desktopentry, "/usr/share/applications/")
    FileUtils.mv("/opt/hpkg/tmp/#{packageName}.control", "/etc/hpkg/controls/")
    dbFile.close
end

# Get argument values and set them to the variables:
ARGV
action = ARGV.shift
packages = ARGV

# Decide which course of action to take
case action
    when "install"
        package_queue(packages)
        puts "List of packages to be installed: "
        puts packages
        puts "Proceed with installation? "
        proceed = gets
        proceed = proceed.chomp
        if proceed == "Y" || proceed == "y"
            packages.each {|package| install(package)}
        else
            puts "Aborting Installation"
        end
    when "remove"; packages.each {|package| remove(package)}
    when "source-install"; packages.each {|package| sourceinstall(package)}
    when "local-install"
        package_queue(packages)
        puts "List of packages to be installed: "
        puts packages
        puts "Proceed with installation? "
        proceed = gets
        proceed = proceed.chomp
        if proceed == "Y" || proceed == "y"
        packages.each {|package| localinstall(package)}
        else
            puts "Aborting Installation"
        end
    when "clean"; clean
    when "update"; update
    when "upgrade"; upgrade
    when "testmirror"; test_mirror
    else helpPage
end
