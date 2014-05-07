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
require 'io/console'

def helpPage()
    # A friendly little help page. This displays to the user whenever a
    # user chooses the "help" commmand, or any invalid command.
    puts "Usage"
    puts " hpm (options) {package}"
    puts ""
    puts "Options include:"
    puts " install        :   install selected binary package(s) from repository"
    puts " source-instal  :   install selected package(s) from source"
    puts " local-install  :   install selected local package(s)"
    puts " remove         :   remove selected package(s)"
    puts " clean          :   clean the cache"
    puts " update         :   update the cache" 
    puts " upgrade        :   upgrade current packages"
    puts " help           :   view this help page"
    puts ""
    return 0
end

def clean()
    # Cleans the cache by removing all files from /opt/hpm/tmp/
    puts "Cleaning Cache: "
    FileUtils::Verbose.rm_rf(Dir.glob("/opt/hpm/tmp/*"))
    puts "Cache Cleaned"
end

def test_mirror()
    # Verifies connectivity to the mirrors chosen by the user. The list of 
    # mirrors is stored in /etc/hpm/mirrors/mirror.lst, with each mirror
    # on their own line. Checks each mirror for a valid ping.
    f = File.open("/etc/hpm/mirrors/mirror.lst", "r")
    f.each_line { |line|

    tempstatus = `bash /bin/hpm/resources/testmirror.sh #{line}` 
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

def hpacmv(packageName, source, dest)
    # Move the package from the source (BIN_FILE from the .control file) 
    # to its destination (BIN_PATH from the .control file)
    FileUtils.cd("/opt/hpm/tmp/#{packageName}/")
    FileUtils.mv("/opt/hpm/tmp/#{packageName}/#{source}", dest)
end

def gethpac(packageName, current, total, failcount)
    if not failcount >= 3
        # Download the package from the mirror
        databaseFile = File.open("/etc/hpm/pkginfo/hpmDatabase.info", "r")
        database = databaseFile.readlines
        databaseFile.close
        blocks = find_block(database)
        mirror = nil
        blocks.each_with_index do |block, index|
            i = block[0]
            endBlock = block[1]
            packageTest = block[2].scan(/HPMNAME=(.+$)/)
            packageTest = packageTest.join
            if packageTest = packageName
                while i <= endBlock
                    if not database[i] == nil
                        if database[i].include? "MIRROR="
                            mirror = database[i].scan(/MIRROR=(.+$)/)
                            mirror = mirror.join
                        end
                    end
                i += 1
                end
            end
        end
    
        puts "(#{current}/#{total}) Getting #{packageName}..."
        io = IO.popen("wget -c -O /opt/hpm/tmp/#{packageName}.hpac #{mirror}/#{packageName}.hpac 2>&1", "r") do |pipe|
            pipe.each do |line|
                if line.include?("%")
                    percent = line.scan(/^.+( 100(?:\.0{1,2})? | 0*?\.\d{1,2} | \d{1,2}(?:\.\d{1,2})?%).+$/)
                    percent = percent.join
                    print "\r#{percent} complete"
                end
            end
        print "\r             "
        puts "\r100% complete"
        end
    
        sha512check = `sha512sum /opt/hpm/tmp/#{packageName}.hpac`
        sha512check = sha512check.scan(/(.+)\  .+$/)
        sha512check = sha512check.join
        sha512check = sha512check.chomp
        sha512verify = nil
        blocks.each do |block|
            nameCheck = block[2].scan(/HPMNAME=(.+$)/)
            nameCheck = nameCheck.join
            if nameCheck == packageName
                i = block[0]
                endBlock = block[1]
                while i <= endBlock
                    if not database[i] == nil
                        if database[i].include?("SHA512SUM")
                            sha512verify = database[i].scan(/SHA512SUM=(.+$)/) 
                            sha512verify = sha512verify.join
                            sha512verify = sha512verify.chomp
                        end
                    end
                i += 1
                end
            end
        end
    
        if not sha512check.eql? sha512verify
            failcount += 1
            puts "Bad sha512sum: #{packageName}\nRetrying..."
            FileUtils.rm("/opt/hpm/tmp/#{packageName}.hpac")
            gethpac(packageName, current, total, failcount)
        end
    else
        puts "Failed to download package."
        exit
    end
end

def checkFile( db_file, package )
    # Check whether or not the database contains the version of the package 
    # requested by the user. If so, return "true"
    File.open( db_file ) do |io|
        io.each {|line| line.chomp! ; return true if line.include? "HPMNAME=#{package}"}
    end
end

def exthpac(packageName)
    # Extract the contents from the packaeg.
    puts "Extracting #{packageName}..."
    puts `tar -C /opt/hpm/tmp/ -xjf /opt/hpm/tmp/#{packageName}.hpac`
end

def find_block(database)
    # Find a unique block for a package within the repository database
    # and return the start and endpoints of said block.
    
    blocklist = []
    namelist = []
    database.each_with_index do |line, databaseIndex|
        if not line == nil
            if line.include? "HPMNAME="
                pkgname = line.chomp
                blocklist.push(databaseIndex)
                namelist.push(pkgname)
            end
        end
    end

    newlist = Array.new 

    blocklist.each_index do |databaseIndex|
        newlist << blocklist.slice(databaseIndex, 2)
        newlist[databaseIndex].push namelist[databaseIndex]
    end

    newlist.each_index do |index|
        if newlist[index].length == 2
            newlist[index].insert(1, database.length)
        elsif newlist[index].length == 3
            newlist[index][1] = newlist[index][1] - 1
        end
    end

    return newlist
end

def queue_check(database, packageName, packages)
    # check the dependency list of each file, for each
    # dependency, check if it is installed, if not, add
    # it to the list of files to be installed.
    deplist = Array.new
    package_list = Array.new
    pkgver = nil

    packages.each do | package |
        package_list.push package[0]
    end
 
    blocks = find_block(database)
    blocks.each_with_index do |block, index|
        checkPackage = block[2].scan(/HPMNAME=(.+$)/)
        checkPackage = checkPackage.join
        if package_list.include?(checkPackage)
            i = blocks[index][0]
            endBlock = blocks[index][1]
            while i <= endBlock
                if database[i] != nil
                    if database[i].include? "DEPLIST="
                        newdeps = database[i].scan(/DEPLIST=(.+$)/)
                        newdeps = newdeps.join
                        newdeps = newdeps.split(" ")
                        if not deplist.include?(newdeps)
                            deplist += newdeps
                        end
                    end
                end
            i += 1
            end
        end
        if deplist.empty? == false
            deplist.each do |dependency, pkgver|
                blocks.each_with_index do |block, index|
                    namecheck = block[2].scan(/HPMNAME=(.+$)/)
                    namecheck = namecheck.join
                    if dependency == namecheck
                        i = block[0]
                        endBlock = block[1]
                        while i <= endBlock
                            if database[i] != nil
                                if database[i].include? "PKGVER="
                                    if not database[i].include? "HPMVER="
                                        pkgver = database[i].scan(/PKGVER=(.+$)/)
                                        pkgver = pkgver.join
                                        if not is_installed(dependency)
                                            depbool = 0
                                            packages.each do |package|
                                                if package[0] == dependency
                                                    depbool = 1
                                                end
                                            end
                                            if depbool == 0
                                                packages.unshift([dependency, "automatic", packageName])
                                                package_queue(packages)
                                            end
                                        end
                                    end
                                end
                            end
                        i += 1
                        end
                    end
                end
            end
        end
    end
end

def dependant_add(package_name, dependency)
    installed_packages = Array.new
    f = File.open('/etc/hpm/pkdb/inpk.pkdb', 'r')
    f.each_line { |line| installed_packages.push line }
    f.close

    blocks = find_block(installed_packages)
    blocks.each do |block|
        i = block[0]
        end_block = block[1]

        while i <= end_block
            if not installed_packages[i] == nil
                if installed_packages[i].include?("HPMNAME=")
                    current_package = installed_packages[i].scan(/HPMNAME=(.+$)/)
                    current_package = current_package.join
                    if current_package == dependency 
                        n = i
                        while n <= end_block
                            if not installed_packages[n] == nil
                                if installed_packages[n].include?("DEPENDANT=")
                                    dependants = installed_packages[n].scan(/DEPENDANT=(.+$)/)
                                    dependants = dependants.flatten
                                    if not dependants.include?(package_name)
                                        dependants.push(package_name)
                                        dependants = dependants.join(" ")
                                        installed_packages[n] = "DEPENDANT=#{dependants}"
                                    end
                                end
                            end
                            n += 1
                        end
                    end
                end
            end
            i += 1 
        end
    end
    f = File.open("/etc/hpm/pkdb/inpk.pkdb", "w")
    f.puts installed_packages
    f.close
end

def package_queue(packages)
    # Resolve the dependencies. Check each package to be installed's in the
    # database for the list of dependencies. For each dependency, check whether 
    # or not it is installed. If not, add it to the start of the list of 
    # packages to be installed. Each time a new package is added to the list, 
    # double check the list to ensure all missing dependencies are to be installed.
    packages.each do | package |
        packageName = package[0]
        # Open the control file and read the pertinent information.
        database = IO.readlines("/etc/hpm/pkginfo/hpmDatabase.info")

        queue_check(database, packageName, packages)
    end
end

def is_installed(packageName)
    #Query the database to check if the package is already installed on the system.
    dbFile = File.open("/etc/hpm/pkdb/inpk.pkdb", "r")
    if checkFile(dbFile, packageName) == true
        dbFile.close
        return true
    else
        dbFile.close
        return false
    end
end

def log_installinfo(packageName, binfile, binpath, desktopentry)
    # Create a list of files and directories installed by the package.
    # eliminate the extra information, and write it to a file to be
    # called during the remove function and upgrade functions. 

    uninstallInfo = []
    baseUninstallInfo = `tar -tf /opt/hpm/tmp/#{packageName}.hpac`
    baseUninstallInfo = baseUninstallInfo.lines
    baseUninstallInfo.each do |entry|
        entry.chomp
        entry = entry.scan(/#{packageName}\/(.+$)/)
        entry = entry.join
        uninstallInfo.push(entry)
    end
    uninstallInfo.delete(binfile)
    i = 0
    endFile = uninstallInfo.length + 1
    confbool = 0
    while i <= endFile
        if not uninstallInfo[i] == nil
            if uninstallInfo[i].include? ".conscript"
                uninstallInfo.delete(uninstallInfo[i]) 
            end
        end
        if not uninstallInfo[i] == nil
            if uninstallInfo[i].include? ".desktop"
                uninstallInfo.delete(uninstallInfo[i]) 
            end
        end
        if not uninstallInfo[i] == nil
            if uninstallInfo[i].include? ".hpac"
                uninstallInfo.delete(uninstallInfo[i]) 
            end
        end
        if not uninstallInfo[i] == nil
            if uninstallInfo[i].include? ".conflist"
		        confbool = 1
                uninstallInfo.delete(uninstallInfo[i]) 
            end
	    end
        i += 1
    end

    if not desktopentry == nil
        uninstallDesktop = desktopentry.scan(/\/opt\/hpm\/tmp\/#{packageName}\/(.+$)/)
        uninstallDesktop = uninstallDesktop.join
    end
    uninstallInfo.delete("#{packageName}.control")

    uninstallInfo.push("usr/share/applications/#{uninstallDesktop}")
    uninstallInfo.push("etc/hpm/controls/#{packageName}.control")

    if not binfile == "" || binfile == "N/A"
        uninstallBinpath = binpath.reverse
        uninstallBinpath = uninstallBinpath.chop
        uninstallBinpath = uninstallBinpath.reverse
        uninstallBinfile = "#{uninstallBinpath}/#{binfile}"
        uninstallInfo.push(uninstallBinfile)
    end

    fileList = Array.new
    uFile = File.open("/etc/hpm/pkdb/uinfo/#{packageName}.uinfo", "w")
    uninstallInfo.each do |line|
        line = line.chomp
        if not line == "#{packageName}.desktop"
            uFile.puts line
        end
        if not line == nil
            dirCheck = line.length - 1
            if not dirCheck == line.rindex("/")
                if not line == "#{packageName}.desktop"
                    fileList.push(line)
                end
            end
        end
    end
    uFile.close

    md5List = Array.new
    fileList.each do |file|
        md5info = `md5sum /#{file}`
        md5info = md5info.scan(/(.+)\ .+$/)
        md5info = md5info.join
        md5info = file + " -- " +md5info
        md5List.push(md5info)
    end

    upgradeFile = File.open("/etc/hpm/pkdb/upinfo/#{packageName}.upinfo", "w")
    md5List.each do |line|
        upgradeFile.puts line
    end
    upgradeFile.close

    return confbool
end

def version_check(updateBlocks, installedPackageName, installedPackageVersion)
    # Check if the installed version is the same as the version available in 
    # the master repository database, if not, add the package to a list 
    # to be installed during the "upgrade" function.

    updateBlocks.each_index do |index|
        i = updateBlocks[index][0]
        endBlock = updateBlocks[index][1]
        checkPackageName = updateBlocks[index][2].scan(/HPMNAME=(.+$)/)
        checkPackageName = checkPackageName.join
        if checkPackageName == installedPackageName
            while i <= endBlock
                if not $hpmDatabase[i] == nil
                    if $hpmDatabase[i].include? "PKGVER="
                        if not $hpmDatabase[i].include? "HPMVER="
                            repoCheckVersion = $hpmDatabase[i].scan(/PKGVER=(.+$)/)
                            repoCheckVersion = repoCheckVersion.join
                            repoCheckVersion = repoCheckVersion.scan(/\d+/)
                            repoCheckVersion = repoCheckVersion.join
                            installedPackageVersion = installedPackageVersion.scan(/\d+/)  
                            installedPackageVersion = installedPackageVersion.join
                            if repoCheckVersion != installedPackageVersion
                                if not $updateDatabase.include?(installedPackageName)
                                    $updateDatabase.push(installedPackageName)
                                end
                            end
                        end
                    end
                end
                i += 1
            end
        end
    end
end

def database_check(hpmBlock, databaseData, hpmversioninfo, nameinfo)
    # Check the new repository's database versus the master list. If the new
    # repository has a version of the package greater than the version in
    # the master list, replace that block in the master database with the
    # block from the new list. 

    newBlocks = find_block(databaseData)
    newBlocks.each_index do |newBlockIndex|
        i = newBlocks[newBlockIndex][0]
        endBlock = newBlocks[newBlockIndex][1]
        while i <= endBlock
            if not databaseData[i] == nil
                if databaseData[i].include?("HPMVER=")
                    checkVersion = hpmversioninfo.scan(/HPMVER=(.+$)/)
                    checkVersion = checkVersion.join
                    hpmBlock.each_with_index do |block, hpmIndex|
                        if block[2] == nameinfo
                            n = hpmBlock[hpmIndex][0] 
                            hpmStartBlock = hpmBlock[hpmIndex][0] 
                            hpmEndBlock = hpmBlock[hpmIndex][1] 
                            while n <= hpmEndBlock
                                if not $hpmDatabase[n] == nil
                                    if $hpmDatabase[n].include?("HPMVER=")
                                        hpmCheckVersion = $hpmDatabase[n].scan(/HPMVER=(.+$)/)
                                        hpmCheckVersion = hpmCheckVersion.join
                                    end
                                end
                                n += 1
                            end
                            if checkVersion > hpmCheckVersion
                                $hpmDatabase.slice!(hpmStartBlock..hpmEndBlock)
                                $hpmDatabase += databaseData
                            end
                        end
                    end
                    databaseData.clear
                end
            end
        i += 1
        end
    end
end

def update()
    #              ######   THIS IS IN PROTOTYPE FORM     #########
    # Build  a master local database which contains packgae information
    # available for a "show" type command as well as information for
    # the dependency resolution of the install process.

    mirrors = []
    mirrorfile = File.open("/etc/hpm/mirrors/mirror.lst", "r")
    mirrorfile.each_line {|line| mirrors.push line.chomp }
    mirrorfile.close
   
    databaseData = []
    newDatabase = []
    nameinfo = nil
    mirrorinfo = nil
    hpmversioninfo = nil
    versioninfo = nil
    depinfo = nil
    hashinfo = nil
    summaryinfo = nil

    $hpmDatabase = [] 
    mirrors.each do |mirror|
        mirror.chomp
        puts `wget -q -c -O /etc/hpm/pkginfo/newDatabase.info #{mirror}/package_database/package_database.info`
        newDatabase = IO.readlines("/etc/hpm/pkginfo/newDatabase.info")
        newDatabase = newDatabase.compact
    
        newBlocks = find_block(newDatabase)
        newBlocks.each_index do |newBlockIndex|
            startBlock = newBlocks[newBlockIndex][0]
            endBlock = newBlocks[newBlockIndex][1]

            nameinfo = newBlocks[newBlockIndex][2]
            mirrorinfo = "MIRROR=" + mirror

            i = startBlock 
            while i <= endBlock
                if not newDatabase[i] == nil
                    if newDatabase[i].include? "HPMVER="
                        hpmversioninfo = newDatabase[i]
                        hpmversioninfo = hpmversioninfo.chomp
                    end
                    if newDatabase[i].include? "PKGVER="
                        if not newDatabase[i].include? "HPMVER="
                            versioninfo = newDatabase[i]
                            versioninfo = versioninfo.chomp
                        end
                    end
                    if newDatabase[i].include? "DEPLIST="
                        depinfo = newDatabase[i]
                        depinfo = depinfo.chomp
                    end
                    if newDatabase[i].include? "SHA512SUM="
                        hashinfo = newDatabase[i]
                        hashinfo = hashinfo.chomp
                    end
                    if newDatabase[i].include? "SUMMARY="
                        summaryinfo = newDatabase[i]
                        summaryinfo = summaryinfo.chomp
                    end
                end
                i = i + 1
            end

            databaseData = [nameinfo, hpmversioninfo, versioninfo, mirrorinfo,\
                    depinfo, hashinfo, summaryinfo, "\n"]

    
            # ok kids... here's where things get complicated.
            # check if the current database entry includes the package, if so, 
            # check if the new database entry's package is at a newer version.
            # If so, delete that entry and enter a new one, if not, do nothing. 
            # once the database is ready, push it out to file.

            if $hpmDatabase.empty?
                $hpmDatabase += databaseData
            else
                hpmBlocks = find_block($hpmDatabase)
                if not hpmBlocks == nil
                    if $hpmDatabase.include? nameinfo
                        database_check(hpmBlocks, databaseData, hpmversioninfo, nameinfo)
                    else
                        $hpmDatabase += databaseData
                    end
                end
            end
        end
        FileUtils.rm("/etc/hpm/pkginfo/newDatabase.info")
    end
    hpmDatabaseFile = File.open("/etc/hpm/pkginfo/hpmDatabase.info", "w")
    hpmDatabaseFile.puts  $hpmDatabase
    hpmDatabaseFile.close

    # Create a flatfile naming all of the available packages for later use with 
    # bash completion.

    pkglist = Array.new
    pkgblocks = find_block($hpmDatabase)
    pkgblocks.each do |block|
        pkg_name = block[2]
        pkg_name = pkg_name.scan(/HPMNAME=(.+$)/)
        pkg_name = pkg_name.join
        pkglist.push(pkg_name)
    end

    pkgfile = File.open("/etc/hpm/pkdb/complist", "w")
    pkglist.each do | package |
        pkgfile.puts(package)
    end
    pkgfile.close


    # Check if the current version is the same as the version available from the repo,
    # if not, add it to a file which can be called to in the upgrade function
    
    $updateDatabase = []

    pkdbFile = File.open("/etc/hpm/pkdb/inpk.pkdb", "r")
    pkdbFile.each_with_index do |line, pkdbIndex|
        line.chomp!
        installedPackageName = line.scan(/(.+)\/\//)
        installedPackageName = installedPackageName.join
        installedPackageVersion = line.scan(/.+\/\/(.+$)/)
        installedPackageVersion = installedPackageVersion.join
        updateBlocks = find_block($hpmDatabase)
        $hpmDatabase.each_index do |index|
            if not $hpmDatabase[index] == nil
                if $hpmDatabase[index].include? installedPackageName
                    version_check(updateBlocks, installedPackageName, installedPackageVersion)
                end
            end
        end
    end
    updateDatabaseFile = File.open("/etc/hpm/pkginfo/updateDatabase.info", "w")
    updateDatabaseFile.puts $updateDatabase
    updateDatabaseFile.close

end

def sourceinstall(source_link, direct_link, repo_fetch)
    build_location = nil
    if direct_link == nil && repo_fetch == nil
        build_location = ARGV[0]
    elsif direct_link != nil && repo_fetch == nil
        build_script = direct_link.scan(/^.+\/(.+$)/)
        build_script = build_script.join
        puts `wget -q -c -O /opt/hpm/build/tmp/#{build_script} #{direct_link}`
        build_location = "/opt/hpm/build/tmp/#{build_script}"
    end
    if source_link == nil
        source_link = ARGV[1]
    else
        source_file = source_link.scan(/^.+\/(.+$)/)
        source_file = source_file.join
        puts `wget -q -c -O /opt/hpm/build/tmp/#{source_file} #{source_link}`
    end
    puts "Running the buildscript..."
    Dir.chdir("/opt/hpm/build/tmp/")
    puts `chmod +x #{build_location}`
    puts `#{build_location}`
    packageName = build_script.scan(/(^.+)\..+$/)
    packageName = packageName.join
    package = Array.new
    package[0] = packageName
    package[1] = "manual"
    package[2] = Array.new
    conflist = nil
    if Dir.exists? "/opt/hpm/tmp/#{packageName}"
        FileUtils.rm_rf(Dir.glob("/opt/hpm/tmp/#{packageName}*"))
    end
    FileUtils.mv("/opt/hpm/build/tmp/#{packageName}.hpac", "/opt/hpm/tmp/")
    exthpac(packageName)
    install(package, conflist)
end

def handleconfig(packageName, file)
    puts "It looks like the author of #{packageName} has included a new" \
        " version of the configuration file located at:\n/#{file}"
    puts "\nWould you like to continue using your configuration, or the new one? (c/n)"
    STDOUT.flush
    decision = STDIN.gets.chomp
    if decision == "C" || decision == "c" 
        FileUtils.mv("/opt/hpm/tmp/#{packageName}/#{file}", \
            "/opt/hpm/tmp/#{packageName}/#{file}.new")
    elsif decision == "N" || decision == "n"
        FileUtils.mv("/#{file}", "/#{file}.old")
    end
end

def register_package(package)
    package_name = package[0]
    install_type = package[1]
    dependants = package[2]

    open('/etc/hpm/pkdb/inpk.pkdb', 'a') { |database|
        database.puts "HPMNAME=#{package_name}" 
        database.puts "INST_TYPE=#{install_type}" 
        database.puts "DEPENDANT=#{dependants}" 
    }
end

def install(package, conflist)
    # Open the .control file # to obtain the  necessary information for the 
    # package, move the exectuable to the correct path, run the control 
    # script, and register the package # in the local database.

    # Open the control file and read the pertinent information.

    packageName = package[0]
    puts "Installing #{packageName}..."
    data = []        
    f = File.open("/opt/hpm/tmp/#{packageName}/#{packageName}.control", "r")
    f.each_line {|line| data.push line }
    f.close
    binfile = nil
    binpath = nil
    conscript = nil
    pkgver = nil
    conffile = nil
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
        elsif line.include? "DEPLIST="
            deplist = line.scan(/DEPLIST=(.+$)/)
            deplist.flatten!
            deplist.each do | dependency |
                dependant_add(packageName, dependency)
            end
        end
    end

    if not binfile == "N/A"
        desktopentry = "/opt/hpm/tmp/#{packageName}/#{packageName}.desktop"
    end

    # Move BIN_FILE to BIN_PATH from .control file.
    if not binfile == "N/A"
        puts "Moving: #{binfile} from /opt/hpm/tmp/#{packageName}/#{binfile} to #{binpath}"
        hpacmv(packageName, binfile, binpath)
    end

    # if it is an update, check for config files and ask if they should be
    # updated.
    if conflist != nil
        conflist.each do |file|
            file = file.scan(/\/(.+$)/)
            file = file.join
            if File.exists?("/opt/hpm/tmp/#{packageName}/#{file}")
                handleconfig(packageName, file)
            end 
        end
    end 


    # move the directories to their correct locations.
    directories = Array.new
    dirList = Array.new
    directories = `ls -pm /opt/hpm/tmp/#{packageName}`    
    directories = directories.split(/, /)
    directories[-1] = directories[-1].chomp!
    directories.each do |check|
        dirCheck = check.length - 1
        if dirCheck == check.rindex("/")
            dirList.push(check)
        end
    end
    dirList.each do |directory|
        puts `cp -HanT /opt/hpm/tmp/#{packageName}/#{directory} /#{directory}`
    end

    # Run the control script
    if conscript != nil
        puts "Running control script..."
        FileUtils.cd("/opt/hpm/tmp/#{packageName}/")
        puts `chmod +x /opt/hpm/tmp/#{packageName}/#{conscript}`
        puts `/opt/hpm/tmp/#{packageName}/#{conscript}`
    end

    # Register package within the database
    register_package(package)       

    # Register packages within the database
    if not binfile == "N/A"
        FileUtils.mv(desktopentry, "/usr/share/applications/")
    end
    FileUtils.mv("/opt/hpm/tmp/#{packageName}/#{packageName}.control", "/etc/hpm/controls/")

    # And save information to uninstall with:
    confbool = log_installinfo(packageName, binfile, binpath, desktopentry)
    if confbool == 1 
    	FileUtils.cp("/opt/hpm/tmp/#{packageName}/#{packageName}.conflist", "/etc/hpm/conflist/")
    end

    # And make the program executable.
    if not binfile == "N/A" || binfile == ""	
        puts `chmod +x #{binpath}/#{binfile}`
    end
end

def dependant_check(packages, new_dependant_list, pkglist, depbool, dependant_list, trigger_package, depcheck_list)
    # Check if a program being uninstalled has other programs relying on it.
    # If so, warn the user about running the program.
    
    if depbool == 0
        packages.each do | package |
            pkglist.unshift(package[0])
        end
    else
        new_dependant_list.each do |dependant|
            pkglist.unshift(dependant)
#            puts "pkglist: #{pkglist.inspect}"
#            puts "dependant_list: #{dependant_list.inspect}"
#            puts "new_dependant_list: #{new_dependant_list.inspect}"
        end
    end
    f = File.open("/etc/hpm/pkdb/inpk.pkdb", "r")
    installed_db = f.readlines
    f.close
    working_db = installed_db.flatten
    working_db.each do |entry|
        entry.chomp!
    end
    installed_blocks = find_block(installed_db)
    pkglist.each do |current|
        pkglist.delete(current)
        installed_blocks.each do |block|
            if block[2].include?(current)
                i = block[0]
                end_block = block[1]
                while i <= end_block
                    if not working_db[i] == nil
                        if working_db[i].include?("DEPENDANT=")
		                    new_dependant_list = Array.new	
                            new_dependant_list = working_db[i].scan(/DEPENDANT=(.+$)/)
                            if not dependant_list == nil
                                new_dependant_list = new_dependant_list.join
                                new_dependant_list = new_dependant_list.split(" ")
                                if not new_dependant_list.empty?
                                    if depbool == 0
                                        trigger_package = current
                                        depbool = 1
                                    end 
                                    new_dependant_list.each do |item|
                                        if not dependant_list.include?(item)
                                            new_item = Array.new
                                            new_item.push(item, 0)
                                            dependant_list.push(item)
                                            depcheck_list.push(new_item)
                                        end
                                    end
                                end
                                packages.each do |package|
                                    if dependant_list.include?(package[0])
                                        dependant_list.delete(package[0])
                                    end
                                end
                                depcheck_list.each do |depcheck|
                                    if depcheck[1] = 0
                                        depcheck[1] = 1
                                        dependant_check(packages, new_dependant_list, pkglist, depbool, dependant_list, trigger_package, depcheck_list)
                                    end
                                end

                                dependant_display = dependant_list.join(", ")
                                if not dependant_list.empty?
                                    puts "---WARNING---"
                                    puts "Removing #{trigger_package} may cause other software on your system to stop working."
                                    puts ""
                                    puts "The following applications may be affected:"
                                    puts dependant_display 
                                    puts "Are you sure you want to continue? (N/y)"
                                    STDOUT.flush
                                    decision = STDIN.gets.chomp
                                    if not decision == "Y" || decision == "y" || decision == "yes"
                                        exit    
                                    end
                                end
                            end
                        end
                    end
                i += 1
                end
            end
        end
    end
end

def removeinfo(package, bupdate)
    # Read the uninstall data for the package to be removed. Remove the
    # files which were installed, then check the directories in which they
    # were installed to. If thoso directories are empty, remove those too.

    uninstallInfo = []
    dirList = []
    fileList = []
    packageName = package[0]
    f = File.open("/etc/hpm/pkdb/uinfo/#{packageName}.uinfo", "r")
    f.each_line {|line| uninstallInfo.push line }
    f.close
    if bupdate == 1
        return uninstallInfo
    else
        uninstallInfo.each do |entry|
            entry.chop!
            dirCheck = entry.length - 1
            if dirCheck == entry.rindex("/")
                dirList.push(entry)
            else
                fileList.push(entry)
            end
        end
    
        remove(packageName, dirList, fileList)
    end
end

def remove(package, dirList, fileList)
    packageName = package

    # Delete all the files
    fileList.each do |file|
        file = "/#{file}"
        puts "Removing: #{file}"
        if File.exists?(file)
            FileUtils.rm(file)
        end
    end

    # Delete all of the now empty directories
    dirList.each do |directory|
        if Dir["/\/#{directory}/*"].empty? then
            directory = "/#{directory}"
            puts "Removing: #{directory}"
            FileUtils.rmdir(directory)
        end
    end
    
    # Delete the uinfo file and database entry
    FileUtils.rm("/etc/hpm/pkdb/uinfo/#{packageName}.uinfo")
    dbFile = File.open("/etc/hpm/pkdb/inpk.pkdb", "r")
    new_database = dbFile.readlines
    dbFile.close
    blocks = find_block(new_database)
    blocks.each do |block|
        if block[2].include? packageName
            start_block = block[0]
            end_block = block[1]
            new_database.slice!(start_block..end_block)
        end
    end
    dbFile = File.open("/etc/hpm/pkdb/inpk.pkdb", "w")
    new_database.each do |line|
        if line.include?(packageName) 
            if line.include?("DEPENDANT=") 
                dependant_list = line.scan(/DEPENDANT=(.+$)/)
                dependant_list = dependant_list.join
                dependant_list = dependant_list.split(" ")
                dependant_list.each do | item |
                    if item == packageName
                        dependant_list.delete(item)
                    end
                end
                if dependant_list.empty?
                    dependant_list = nil
                else
                    dependant_list = dependant_list.join(" ")
                end 
                line = "DEPENDANT=#{dependant_list}"
            end
        end
        dbFile.puts line
    end
    dbFile.close

     
end

def upgrade()

    packages = []
    upgradeFile = File.open("/etc/hpm/pkginfo/updateDatabase.info", "r")
    upgradeFile.each_line {|line| packages.push line }
    upgradeFile.close
    totalPackages = packages.length

    packages.each_with_index do |packageName, index|
        count = index + 1
        packageName = packageName.chomp
        uninstallInfo = []
        dirList = []
        fileList = []
        uninstallInfo = removeinfo(packageName, 1)
        uninstallInfo.each do |entry|
            entry.chop!
            dirCheck = entry.length - 1
            if dirCheck == entry.rindex("/")
                dirList.push(entry)
            else
                fileList.push(entry)
            end
        end

        if File.exists?("/etc/hpm/conflist/#{packageName}.conflist")
            configInfo = []
            configFile = File.open("/etc/hpm/conflist/#{packageName}.conflist")
            configFile.each_line {|line| configInfo.push line }
            configFile.close

            fileList.each do |file|
                configInfo.each do |configData|
                    configData = configData.chomp!
                    if configData == "/#{file}"
                        fileList.delete(file)
                    end
                end
            end
        end
    
        bupdate = 1
        gethpac(packageName, count, totalPackages)
        remove(packageName, dirList, fileList)
        exthpac(packageName)
        install(packageName, configInfo)
    end
end

def repoinstall(packages, totalPackages, bupdate)
    # Install a package from a mirror. Check for connectivity to the
    # mirror, if so, download the package, extract it. Install package.

    # mirror = # hmmm.
    
    # CHECK MIRROR STATUS ..... somehow

    # Get the required packages and extract them, then install them.
    
    databaseFile = File.open("/etc/hpm/pkginfo/hpmDatabase.info", "r")
    database = databaseFile.readlines
    databaseFile.close
    blocks = find_block(database)
    pkgver = nil

    packages.each_with_index do |package, pkg_index|
        packageName = package[0]
        blocks.each do |block|
            if block[2].include? packageName
                i = block[0]
                endBlock = block[1]
                while i <= endBlock
                    if not database[i] == nil
                        if database[i].include?("PKGVER=")
                            if not database[i].include?("HPMVER=")
                                pkgver = database[i].scan(/PKGVER=(.+$)/)
                                pkgver = pkgver.join
                            end
                        end
                    end
                i += 1
                end
            end
        end
        if is_installed(packageName)
            puts "#{packageName} is already at the newest version."
            packages.delete_at(pkg_index)
        else
            count = pkg_index + 1
            failcount = 0
            gethpac(packageName, count, totalPackages, failcount)
        end
    end

    if bupdate == 0
        conflist = nil
        packages.each_index do |pkg_index|
            packageName = packages[pkg_index][0]
            exthpac(packageName)
        end

        packages.each_index do |pkg_index|
            install(packages[pkg_index], conflist)
        end
    end
end

def localinstall(packages)
    # Install a package from a local sourc. Extract it. Clean Input, and
    # install the package. 

    packages.each do |package|
        puts "Copying #{package[0]} to /opt/hpm/tmp/..."
        FileUtils.cp("#{package[0]}", "/opt/hpm/tmp/")
    end

    packages.each do |package|
        packageName = package[0]
        if packageName.include? ".hpac"
            packageName = packageName.chomp('.hpac')
        end
        exthpac(packageName)
    end

    packages.each do |package|
        packageName = package[0]
        if package[0].include? ".hpac"
            package[0] = package[0].chomp('.hpac')
        end
            conflist = nil
            install(package, conflist)
    end
end

def makepkg(package_folder, output_file)
    move = true
    Dir.chdir(package_folder)
    package_folder = Dir.pwd
    Dir.chdir("../")
    if output_file == nil 
        move = false
        output_file = "#{package_folder}.hpac"
    end
    package_folder = package_folder.scan(/^.+\/(.+$)/)
    package_folder = package_folder.join
    dirCheck = output_file.length - 1
    if Dir.exists?(output_file)
        if dirCheck == output_file.rindex("/")
            output_file = "#{output_file}#{package_folder}.hpac" 
        else    
            output_file = "#{output_file}/#{package_folder}.hpac" 
        end
    end
    output_location = output_file.scan(/(^.+\/).+$/)
    output_location = output_location.join
    if output_lotation = package_folder
        move = false
    end
    
    output_file = output_file.scan(/^.+\/(.+$)/)
    output_file = output_file.join
    package_folder = "#{package_folder}/*"
    puts `tar -cjf #{output_file} #{package_folder}`
    if move == true
        FileUtils.mv(output_file, output_location)
    end
end


def get_summary(package)
    databaseFile = File.open("/etc/hpm/pkginfo/hpmDatabase.info", "r")
    database = databaseFile.readlines
    databaseFile.close

    blocks = find_block(database)
    blocks.each do |block|
        if block[2].include?(package)
            i = block[0]
            end_block = block[1]
            while i <= end_block
                if not database[i] == nil
                    if database[i].include?('SUMMARY=')
                        summary = database[i].scan(/SUMMARY=(.+$)/)
                        puts summary
                    end
                end
                i += 1
            end
        end
    end
    exit
end

def list_installed()
    databaseFile = File.open("/etc/hpm/pkdb/inpk.pkdb", "r")
    database = databaseFile.readlines
    databaseFile.close

    blocks = find_block(database)
    blocks.each do |block|
        package_name = block[2].scan(/HPMNAME=(.+$)/)
        puts package_name
    end
end
        
# Get input from the user by means of arguments passed along with the program.
# The first argument following the command is considered the action in the
# program. All subsequent arguments are considered to be packages.
arg_delete_list = Array.new
output_file = nil
source_link = nil
get_build = nil
repo_fetch = nil
ARGV
ARGV.each_with_index do |argument, index|
    next_index = index + 1
    if  argument == "-o" || argument == "--output-file"
        output_file = ARGV[next_index]
        arg_delete_list.push(argument)
        arg_delete_list.push(output_file)
    elsif  argument == "-s" || argument == "--source-link"
        source_link = ARGV[next_index]
        arg_delete_list.push(argument)
        arg_delete_list.push(source_link)
    elsif  argument == "-d" || argument == "--direct-link"
        get_build = ARGV[next_index]
        arg_delete_list.push(argument)
        arg_delete_list.push(get_build)
    elsif  argument == "-r" || argument == "--repo-fetch"
        repo_fetch = ARGV[next_index]
        arg_delete_list.push(argument)
        arg_delete_list.push(repo_fetch)
    elsif  argument == "-q" || argument == "--get-summary"
        paul = ARGV[next_index]
        pete = get_summary(paul)
    end 
end

arg_delete_list.each do |delete_item|
    ARGV.delete(delete_item)
end

action = ARGV.shift
packagelist = ARGV
packages = Array.new
packagelist.each_with_index do |package, i|
    # but basically what's going on is that we're creating a list of
    # packages which are to be installed, and we need to figure out three
    # things about each package, its name, whether it was installed manually
    # or via dependency resolution, and which packages that depend on it 
    # ("dependant") not that which it depends on ("dependency") If a program
    # is manually installed, the dependant list is unimportant, however for 
    # automatic entries this must be logged.
    package = package.dup
    packages[i] = Array.new
    packages[i].push(package) # [0]
    packages[i].push('manual') # [1]
end

def empty_fail(packages)
	if packages.empty?
		helpPage
    	exit
	end
end

packageDisplay = Array.new
# Decide which course of action to take
case action
    when "install"
        empty_fail(packages)
        if not packageDisplay == ""
            package_queue(packages)
            packages.each do | package |
                packageDisplay.push(package[0])
            end
            packageDisplay = packageDisplay * ", "
            puts "Packages to be installed:\n\n#{packageDisplay}\n"
            puts "\nProceed with installation? (y/n)"
            STDOUT.flush
            decision = STDIN.gets.chomp
            if decision == "Y" || decision == "y" || decision == "yes"
                totalPackages = packages.length
                bupdate = 0
                repoinstall(packages, totalPackages, bupdate)
            else
                puts "Aborting Installation"
            end
        else 
            helpPage()
        end
    when "remove"
        empty_fail(packages)
        dependant_list = Array.new
        depcheck_list = Array.new
        new_dependant_list = Array.new
        pkglist = Array.new
        trigger_package = nil
        depbool = 0
        dependant_check(packages, new_dependant_list, pkglist, depbool, dependant_list, trigger_package, depcheck_list)
        packages.each do | package |
            if is_installed(package[0])
                removeinfo(package, 0)
            else
                puts "#{package[0]} is not currently installed."
            end
        end
    when "source-install"
        sourceinstall(source_link, get_build, repo_fetch)
    when "local-install"
        empty_fail
        if not packageDisplay == ""
            package_queue(packages)
            packages.each do | package |
                packageDisplay.push(package[0])
            end
            packageDisplay = packageDisplay * ", "
            puts "Packages to be installed:\n\n#{packageDisplay}\n"
            puts "\nProceed with installation? (y/n)"
            STDOUT.flush
            decision = STDIN.gets.chomp
            if decision == "Y" || decision == "y" || decision == "yes"
                localinstall(packages)
            else
                puts "Aborting Installation"
            end
        else
            helpPage
        end
    when "list-installed"; list_installed
    when "clean"; clean
    when "update"; update
    when "upgrade"; upgrade
    when "makepkg"
        packages.each {|package|makepkg(package[0], output_file)}
    else helpPage
end
