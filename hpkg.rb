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
    # A friendly little help page. This displays to the user whenever a
    # user chooses the "help" commmand, or any invalid command.
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
    # Cleans the cache by removing all files from /opt/hpkg/tmp/
    puts "Cleaning Cache: "
    FileUtils::Verbose.rm_rf("/opt/hpkg/tmp/*")
    puts "Cache Cleaned"
end

def test_mirror()
    # Verifies connectivity to the mirrors chosen by the user. The list of 
    # mirrors is stored in /etc/hpkg/mirrors/mirror.lst, with each mirror
    # on their own line. Checks each mirror for a valid ping.
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
    # Move the package from the source (BIN_FILE from the .control file) 
    # to its destination (BIN_PATH from the .control file)
    FileUtils.cd("/opt/hpkg/tmp/#{packageName}/")
    FileUtils.mv("/opt/hpkg/tmp/#{packageName}/#{source}", dest)
end

def gethpkg(packageName, mirror)
    # Download the package from the mirror
    puts `wget -c -0 /opt/hpkg/tmp/#{packageName}.hpkg #{mirror}/#{packageName}`
end

def checkFile( db_file, package )
    # Check whether or not the database contains the version of the package 
    # requested by the user. If so, return "true"
    File.open( db_file ) do |io|
    io.each {|line| line.chomp! ; return true if line.include? package}
    end
end

def exthpkg(packageName)
    # Extract the contents from the packaeg.
    puts `tar -C /opt/hpkg/tmp/ -xf #{packageName}.hpkg`
end

def package_queue(packages)
    # Resolve the dependencies. Check each package to be installed's control
    # file for the list of dependencies. For each dependency, check whether 
    # or not it is installed. If not, add it to the start of the list of 
    # packages to be installed. Each time a new package is added to the list, 
    # double check the list to ensure all missing dependencies are to be installed.
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
    #Query the database to check if the package is already installed on the system.
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

def update()
    #              ######   THIS IS IN PROTOTYPE FORM     #########
    # Build  a master local database which contains packgae information
    # available for a "show" type command as well as information for
    # the dependency resolution of the install process.
    
    mirrors = []
    mirrorfile = File.open("/etc/hpkg/mirrors/mirror.lst", "r")
    mirrorfile.each_line {|line| mirrors.push line }
    mirrorfile.close
   
    newDatabase = IO.readlines("/etc/hpkg/pkginfo/newDatabase.info")
    hpkgDatabase = [] 
    newDatabaseInfo = []

    mirrors.each do |mirror|
        mirror.chomp
        puts `wget -c -0 /etc/hpkg/pkginfo/newDatabaseInfo.info #{mirror}/package_database/package_database.info`
        newDatabaseInfo = IO.readlines("/etc/hpkg/pkginfo/newDatabaseInfo.info")

        newDatabaseInfo.each do |line|
            i = newDatabaseInfo.index(line)
            line.chomp
            if line.include? "HPKGNAME="
                nameinfo = line
                i = i + 1
                versioninfo = newDatabaseInfo[i]
                versioninfo = versioninfo.chomp
                i = i + 1
                archinfo = newDatabaseInfo[i]
                archinfo = archinfo.chomp
                i = i + 1
                depinfo = newDatabaseInfo[i]
                depinfo = depinfo.chomp
                i = i + 1
                hashinfo = newDatabaseInfo[i]
                hashinfo = hashinfo.chmop
                i = i + 1
                summaryinfo = newDatabaseInfo[i]
                summaryinfo = summaryinfo.chomp

                if hpkgDatabase.include? nameinfo
                    # do some tricky shit
                else
                    hpkgDatabase.push(nameinfo, versioninfo, archinfo, depinfo, summaryinfo)
                end
            end
        end
    end
end

def sourceinstall(packageName)
    # Do some mirror magic...

    `wget -c -O /opt/hpkg/tmp/#{packageName}.hpkgbuild #{mirror}/source/#{packageName}.hpkgbuild`
    `sh /opt/hpkg/tmp/#{packageName}.hkpgbuild`
end

def install(packageName)
    # Open the .control file # to obtain the  necessary information for the 
    # package, move the exectuable to the correct path, run the control 
    # script, and register the package # in the local database.

    # Open the control file and read the pertinent information.
    data = []        
    f = File.open("/opt/hpkg/tmp/#{packageName}/#{packageName}.control", "r")
    f.each_line {|line| data.push line }
    f.close
    binfile = nil
    binpath = nil
    conscript = nil
    pkgver = nil
    data.each do |line|
        line.chomp
        if line.include? "BIN_FILE="
            binfile = line.scan)(/.+\=(.+$)/)
            binfile = binfile.join
        elsif line.include? "BIN_PATH="
            binpath = line.scan)(/.+\=(.+$)/)
            binpath = binpath.join
        elsif line.include? "CONSCRIPT="
            conscript = line.scan)(/.+\=(.+$)/)
            conscript = conscript.join
        elsif line.include? "PKGVER="
            pkgver = line.scan)(/.+\=(.+$)/)
            pkgver = pkgver.join
        end
    end
    desktopentry = "/opt/hpkg/tmp/#{packageName}/#{packageName}.desktop"

    puts "Installing #{packageName}..."

    # Move BIN_FILE to BIN_PATH from .control file.
    puts "Moving: #{binfile} from /opt/hpkg/tmp/#{packageName}/#{binfile} to #{binpath}"
    hpkgmv(packageName, binfile, binpath)

    # Run the control script
    puts `chmod +x #{conscript}`
    puts `#{conscript}`

    # Register package within the database
    puts "Registering packgages in database"
    open('/etc/hpkg/pkdb/inpk.pkdb', 'a') { |database|
           database.puts "#{packageName}.#{pkgver}" }
           
    # Register packages within the database
    FileUtils.mv(desktopentry, "/usr/share/applications/")
    FileUtils.mv("/opt/hpkg/tmp/#{packageName}.control", "/etc/hpkg/controls/")

    puts `chmod +x #{binpath}/#{binfile}`
end

def repoinstall(packageName)
    # Install a package from a mirror. Check for connectivity to the
    # mirror, if so, download the package, extract it. Install package.

    # mirror = # hmmm.
    
    # CHECK MIRROR STATUS ..... somehow

    # Get the required packages and extract them
    gethpkg(packageName, mirror)
    exthpkg(packageName)

    install(packageName)
end

def localinstall(packageName)
    # Install a package from a local sourc. Extract it. Clean Input, and
    # install the package. 

    FileUtils.cp("#{packageName}", "/opt/hpkg/tmp/")

    if packageName.include? ".hpkg"
        packageName = packageName.chomp('.hpkg')
    end

    exthpkg(packageName)

    install(packageName)
end

# Get input from the user by means of arguments passed along with the program.
# The first argument following the command is considered the action in the
# program. All subsequent arguments are considered to be packages.
ARGV
action = ARGV.shift
packages = ARGV

# Decide which course of action to take
case action
    when "install"
#        package_queue(packages)
        puts "List of packages to be installed: "
        puts packages
        puts "Proceed with installation? "
        STDOUT.flush
        decision = STDIN.gets.chomp
        if proceed == "Y" || proceed == "y"
            packages.each {|package| repoinstall(package)}
        else
            puts "Aborting Installation"
        end
    when "remove"; packages.each {|package| remove(package)}
    when "source-install"; packages.each {|package| sourceinstall(package)}
    when "local-install"
#        package_queue(packages)
        puts "List of packages to be installed: "
        puts packages
        puts "Proceed with installation? "
        STDOUT.flush
        decision = STDIN.gets.chomp
        if decision == "Y" || decision == "y"
        packages.each {|package| localinstall(package)}
        else
            puts "Aborting Installation"
        end
    when "clean"; clean
    when "update"; update
    when "upgrade"; upgrade
    else helpPage
end
