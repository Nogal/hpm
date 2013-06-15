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

def help_page()
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

def hpkgmv(package_name, source, dest)
    FileUtils.cd("/opt/hpkg/tmp/#{package_name}/")
    FileUtils.mv(source, dest)
end

def check_file( file, string )
    # Check whether or not the string is within the contents of the file
    File.open( file ) do |io|
    io.each {|line| line.chomp! ; return true if line.include? string}
    end
end    

def localinstall(packages)
    # For each package, open the control file and read the pertinent information.
    packages.each do|a|
        f = File.open("/opt/hpkg/tmp/#{a}/#{a}.control", "r")
        data = f.read 
        f.close
        source = data
        dest = data
        pkgver = data
        source = source.match(/(?<=BIN_FILE: ).+$/)
        dest = dest.match(/(?<=BIN_PATH: ).+$/)
        pkgver = pkgver.match(/(?<=PKGVER: ).+$/)

        #Query the database
        db_file = File.open("/etc/hpkg/pkdb/inpk.pkdb", "r")
        if check_file(db_file, pkgver[0]) == true
            puts "Package already installed"

        else
            puts "Installing: #{a}"

            # Move BIN_FILE to BIN_PATH from .control file. 
            hpkgmv(a, source[0], dest[0])
            puts "Moving: #{a} from #{source} to #{dest}"
        end
        db_file.close
    end
end

# Get argument values and set them to the variables:
ARGV
action = ARGV.shift
packages = ARGV    

# Decide which course of action to take
case action
    when "install"; install(packages)
    when "remove"; remove(packages)
    when "source-install"; sourceinstall(packages)
    when "local-install"; localinstall(packages)
    when "clean"; clean
    when "update"; update
    when "upgrade"; upgrade
    else help_page
end
