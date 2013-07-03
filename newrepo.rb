#!/usr/bin/env ruby

#Not sure if this works, but you can try it.


puts "Enter the URL for your desired repository."

repo = gets
repo = repo.chomp

open('/etc/hpkg/pkdb/mirrors.pkdb', 'a') { |repository| repository.puts "#{repo}" }

puts "Updating..."

system("sleep 2")

system("hpkg update")



