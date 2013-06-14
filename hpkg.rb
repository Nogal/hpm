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
    cd('/opt/hpkg/tmp/#{package_name}/')
    mv(source, dest)
end

def install(packages)
#    packages.each do|a|
#        f = File.open("/opt/hpkg/tmp/#{a}/#{a}.control", "r")
#        data = f.read 
#        f.close
#        source = data
#        dest = data
#        source[0, 8] = ''
#        dest = dest.match(/BIN_FILE: /)

#GOD DAMN I FUCKING HATE DEALING WITH PARSING BULLSHIT
        puts "Installing: #{a}"
        puts "Moving: #{a} from #{source} to #{dest}"
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
    when "source-install"; source-install(packages)
    when "local-install"; local-install(packages)
    when "clean"; clean
    when "update"; update
    when "upgrade"; upgrade
    else help_page
end
