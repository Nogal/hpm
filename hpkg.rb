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
    FileUtils::Verbose.rm_rf(Dir.glob("/opt/hpkg/tmp/*"))
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
    puts `tar -C /opt/hpkg/tmp/ -xjf #{packageName}.hpkg`
end

def queue_check(database, databaseIndex, deplist, pkgver)
    # check the dependency list of each file, for each
    # dependency, check if it is installed, if not, add
    # it to the list of files to be installed.
 
    checkCounter = databaseIndex
    7.times do
        if database[checkCounter] != nil
            if database[checkCounter].include? "DEPLIST="
                deplist = database[checkCounter].scan(/DEPLIST=(.+$)/)
                deplist = deplist.join
                deplist = deplist.split
            end
        end
        if database[checkCounter] != nil
            if database[checkCounter].include? "PKGVER="
                if not database[checkCounter].include? "HPKGVER="
                    pkgver = database[checkCounter].scan(/PKGVER=(.+$)/)
                end
            end
        end
        checkCounter = checkCounter + 1
    end
    if deplist.empty? == false
        deplist.each do |dependency|
                # I think there is an error in this part... it doens't feel
                # right.
            if is_installed(dependency, pkgver) == false
                if not packages.include?(dependency)
                    packages.unshift(dependency)
                    package_queue(packages)
                end
            end
        end
    end
end

def package_queue(packages)
    # Resolve the dependencies. Check each package to be installed's in the
    # database for the list of dependencies. For each dependency, check whether 
    # or not it is installed. If not, add it to the start of the list of 
    # packages to be installed. Each time a new package is added to the list, 
    # double check the list to ensure all missing dependencies are to be installed.
    packages.each do |packageName|
        # Open the control file and read the pertinent information.
        database = IO.readlines("/etc/hpkg/pkginfo/hpkgDatabase.info")
        deplist = []
        pkgver = nil

        database.each_with_index do |line, databaseIndex|
            if line.include? "HPKGNAME=#{packageName}"
                queue_check(database, databaseIndex, deplist, pkgver)
            end
        end
    end
end

def is_installed(packageName, pkgver)
    #Query the database to check if the package is already installed on the system.
    dbFile = File.open("/etc/hpkg/pkdb/inpk.pkdb", "r")
    if checkFile(dbFile, "#{packageName}.#{pkgver}") == true
        return true
    else
        return false
    end
end

def log_uninstall(packageName, binfile, binpath, desktopentry)
    # Create a list of files and directories installed by the package.
    # eliminate the extra information, and write it to a file to be
    # called during the remove function. Jezzirolk deserves some bacon.

    uninstallInfo = []
    baseUninstallInfo = `tar -tf /opt/hpkg/tmp/#{packageName}.hpkg`
    baseUninstallInfo = baseUninstallInfo.lines
    baseUninstallInfo.each do |entry|
        entry.chomp
        entry = entry.scan(/#{packageName}\/(.+$)/)
        entry = entry.join
        uninstallInfo.push(entry)
    end
    uninstallInfo.delete(binfile)
    uninstallInfo.delete("#{binfile}.control")
    uninstallInfo.delete("#{binfile}.conscript")
    uninstallInfo.delete("#{binfile}.desktop")
    uninstallInfo.delete("#{binfile}.hpkg")

    uninstallDesktop = desktopentry.scan(/\/opt\/hpkg\/tmp\/#{packageName}\/(.+$)/)
    uninstallDesktop = uninstallDesktop.join

    uninstallInfo.push("usr/share/applications/#{uninstallDesktop}")
    uninstallInfo.push("etc/hpkg/controls/#{packageName}.control")

    uninstallBinpath = binpath.reverse
    uninstallBinpath = uninstallBinpath.chop
    uninstallBinpath = uninstallBinpath.reverse
    uninstallBinfile = "#{uninstallBinpath}/#{binfile}"
    uninstallInfo.push(uninstallBinfile)

    uFile = File.open("/etc/hpkg/pkdb/uinfo/#{packageName}.uinfo", "w")
    uninstallInfo.each do |line|
        uFile.puts line
    end
    uFile.close
end

def version_check(repoIndex, installedPackageName, installedPackageVersion)
    # Check if the installed version is the same as the version available in 
    # the master repository database, if not, add the package to a list 
    # to be installed during the "upgrade" function.
    repoCheckCounter = repoIndex
    6.times do
        if not $hpkgDatabase[repoCheckCounter] == nil
            if $hpkgDatabase[repoCheckCounter].include? "PKGVER="
                if not $hpkgDatabase[repoCheckCounter].include? "HPKGVER="
                    repoCheckVersion = $hpkgDatabase[repoCheckCounter].scan(/PKGVER=(.+$)/)
                    if repoCheckVersion != installedPackageVersion
                        $updateDatabase.push(installedPackageName)
                    end
                end
            end
        end
        repoCheckCounter = repoCheckCounter + 1
    end
end

def database_check(hpkgDatabaseIndex, databaseData)
    # Check the new repository's database versus the master list. If the new
    # repository has a version of the package greater than the version in
    # the master list, replace that block in the master database with the
    # block from the new list. 
    checkCounter = hpkgDatabaseIndex
    databaseCounter = hpkgDatabaseIndex
    6.times do
        if $hpkgDatabase[checkCounter].include? "HPKGVER="
            checkVersion = ""
            checkVersion = hpkgversioninfo.scan(/HPKGVER=(.+$)/)
            checkVersion = checkVersion.join
            hpkgCheckVersion = $hpkgDatabase[checkCounter].scan(/HPKGVER=(.+$)/)
            hpkgCheckVersion = hpkgCheckVersion.join
            if checkVersion > hpkgCheckVersion
                7.times do
                    $hpkgDatabase.delete_at(databaseCounter)
                end
            end
        $hpkgDatabase.push(databaseData)
       databaseData.clear
       end
    checkCounter = checkCounter + 1
    end
end

def update()
    #              ######   THIS IS IN PROTOTYPE FORM     #########
    # Build  a master local database which contains packgae information
    # available for a "show" type command as well as information for
    # the dependency resolution of the install process.

    mirrors = []
    mirrorfile = File.open("/etc/hpkg/mirrors/mirror.lst", "r")
    mirrorfile.each_line {|line| mirrors.push line.chomp }
    mirrorfile.close
   
    databateData = []
    newDatabase = []
    nameinfo = nil
    mirrorinfo = nil
    hpkgversioninfo = nil
    versioninfo = nil
    depinfo = nil
    hashinfo = nil
    summaryinfo = nil

    mirrors.each do |mirror|
        mirror.chomp
#        puts `wget -c -0 /etc/hpkg/pkginfo/newDatabase.info #{mirror}/package_database/package_database.info`
        newDatabase = IO.readlines("/etc/hpkg/pkginfo/newDatabase.info")
        $hpkgDatabase = [] 
    
        newDatabase.each_with_index do |line, newDatabaseIndex|
            i = newDatabaseIndex + 1
            line.chomp
            if line.include? "HPKGNAME="
                nameinfo = line.chomp
                mirrorinfo = "MIRROR=" + mirror
                5.times do
                if newDatabase[i].include? "HPKGVER="
                    hpkgversioninfo = newDatabase[i]
                    hpkgversioninfo = hpkgversioninfo.chomp
                end
                if newDatabase[i].include? "PKGVER="
                    if not newDatabase[i].include? "HPKGVER="
                        versioninfo = newDatabase[i]
                        versioninfo = versioninfo.chomp
                    end
                end
                if newDatabase[i].include? "DEPLIST="
                    depinfo = newDatabase[i]
                    depinfo = depinfo.chomp
                end
                if newDatabase[i].include? "MD5SUM="
                    hashinfo = newDatabase[i]
                    hashinfo = hashinfo.chomp
                end
                if newDatabase[i].include? "SUMMARY="
                    summaryinfo = newDatabase[i]
                    summaryinfo = summaryinfo.chomp
                end
                i = i + 1
            end

            databaseData.push(nameinfo, hpkgversioninfo, versioninfo, mirrorinfo, depinfo, hashinfo, summaryinfo, "\n")
    
                # ok kids... here's where things get complicated.
                # check if the current database entry includes the package, if so, 
                # check if the new database entry's package is at a newer version.
                # If so, delete that entry and enter a new one, if not, do nothing. 
                # once the database is ready, push it out to file.
                if $hpkgDatabase.include? nameinfo
                    $hpkgDatabase.each_with_index do |dbEntry, hpkgDatabaseIndex|
                        if dbEntry.include? nameinfo
                            database_check(hpkgDatabesIndex, databaseData)
                        end
                    end
                else
                    $hpkgDatabase.push(databaseData)
                    databaseData.clear
                end
            end
        end
    end
    hpkgDatabaseFile = File.open("/etc/hpkg/pkginfo/hpkgDatabase.info", "w")
    hpkgDatabaseFile.puts  $hpkgDatabase
    hpkgDatabaseFile.close

    # Check if the current version is the same as the version available from the repo,
    # if not, add it to a file which can be called to in the upgrade function
    
    $updateDatabase = []

    pkdbFile = File.open("/etc/hpkg/pkdb/inpk.pkdb", "r")
    pkdbFile.each_with_index do |line, pkdbIndex|
        installedPackageName = line.scan(/(.+)\\/)
        installedPackageName = installedPackageName.join
        installedPackageVersion = line.scan(/.+\\(.+$)/)
        installedPackageVersion = installedPackageVersion.join
        $hpkgDatabase.each_with_index do |repoEntry, repoIndex|
            if repoEntry.include? installedPackageName
                version_check(repoIndex, installedPackageName, installedPackageVersion)
            end
        end
    end
    updateDatabaseFile = File.open("/etc/hpkg/pkginfo/updateDatabase.info", "w")
    updateDatabaseFile.puts $updateDatabase
    updateDatabaseFile.close
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
            binfile = line.scan(/BIN_FILE=(.+$)/)
            binfile = binfile.join
        elsif line.include? "BIN_PATH="
            binpath = line.scan(/BIN_PATH=(.+$)/)
            binpath = binpath.join
        elsif line.include? "CONSCRIPT="
            conscript = line.scan(/CONSCRIPT=(.+$)/)
            conscript = conscript.join
        elsif line.include? "PKGVER="
            pkgver = line.scan(/PKGVER=(.+$)/)
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
    puts `/opt/hpkg/tmp/#{packageName}/#{conscript}`

    # Register package within the database
    puts "Registering packgages in database"
    open('/etc/hpkg/pkdb/inpk.pkdb', 'a') { |database|
            database.puts "#{packageName}\\#{pkgver}" }
           
    # Register packages within the database
    FileUtils.mv(desktopentry, "/usr/share/applications/")
    FileUtils.mv("/opt/hpkg/tmp/#{packageName}/#{packageName}.control", "/etc/hpkg/controls/")

    # And save information to uninstall with:
    log_uninstall(packageName, binfile, binpath, desktopentry)

    # And make the program executable.
    puts `chmod +x #{binpath}/#{binfile}`
end

def remove(packageName)
    # Read the uninstall data for the package to be removed. Remove the
    # files which were installed, then check the directories in which they
    # were installed to. If thoso directories are empty, remove those too.

    uninstallInfo = []
    dirList = []
    fileList = []
    f = File.open("/etc/hpkg/pkdb/uinfo/#{packageName}.uinfo", "r")
    f.each_line {|line| uninstallInfo.push line }
    f.close
    uninstallInfo.each do |entry|
        entry.chop!
        dirCheck = entry.length - 1
        if dirCheck == entry.rindex("/")
            dirList.push(entry)
        else
            fileList.push(entry)
        end
    end

    puts "List of directories:"
    dirList.each do |directory|
        if Dir["/\/#{directory}/*"].empty? then
            puts "\/#{directory} is empty"
        else
            puts "\/#{directory} is not empty"
        end
    end
    puts ""
    puts "List of files:" 
    fileList.each do |file|
        puts "\/#{file}"
    end
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
        packageDisplay = packages.join(" ") 
        puts "Packages to be installed:\n#{packageDisplay}\n"
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
        packageDisplay = packages.join(" ") 
        puts "Packages to be installed:\n#{packageDisplay}\n"
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
    when "test"
        package_queue(packages)
        packageDisplay = packages.join(" ") 
        puts "Packages to be installed:\n#{packageDisplay}"
    else helpPage
end
