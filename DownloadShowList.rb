#!/usr/bin/env ruby

# This file is part of the TVShows source code.
# http://github.com/mattprice/TVShows

# TVShows is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

requires = [
	'open-uri',
	File.join(File.dirname(__FILE__), 'TVShowsScript/TVShowsConstants.rb'),
	File.join(File.dirname(__FILE__), 'TVShowsScript/lib/plist.rb')
]

def die(message)
	time = Time.new
	$stderr.puts "#{time.strftime("%m/%d/%y %H:%M:%S")}\tTVShows Error: #{message}"
	exit(-1)
end
def printError(message)
	time = Time.new
	$stderr.puts "#{time.strftime("%m/%d/%y %H:%M:%S")}\tTVShows Error: #{message}"
end
def printException(exception)
	time = Time.new
	$stderr.puts "#{time.strftime("%m/%d/%y %H:%M:%S")}\tTVShows Error: #{exception.inspect}\n\t#{exception.backtrace.join("\n\t")}"
end

requires.each { |r|
	begin
		die("Could not load #{r}") unless require r
	rescue => e
		printException(e)
	end
}

exit(2) if ( ARGV.length != 2 )

begin

	path = ARGV[0]
	version = ARGV[1]

	shows = {
		"Shows" => [],
		"Version" => version
	}

	data = nil
	3.times { |n|
		begin
			data = open("http://showrss.karmorra.info/?cs=feeds")
			break
		rescue Exception, Timeout::Error => e
			printError("Failed to download the list, retrying...")
		end
	}
	
	raise "Data is nil." if data.nil?	
	
	data.read.scan(/option value=\"(.*?)\">(.*?)</i).each { |show|
		shows["Shows"] << {
			"ExactName"		=> CGI::escape(show[1].gsub("%2B", "+")),
			"HumanName"		=> show[1],
			"Subscribed"	=> false,
			"Links"	      => "http://showrss.karmorra.info/feeds/" + show[0] + ".rss"	
		}
	}

	# Merge
	if (File.exists?(path)) then
		begin
			knownShows = Plist::parse_xml(path)
		rescue => e
			printException(e)
			exit(1)
		end
		
		if !knownShows.nil? then
			showsToAdd = []
			shows["Shows"].each { |show|
				if (!knownShows["Shows"].find{|ks| ks["ExactName"] == show["ExactName"]}) then
					showsToAdd << show
				end
			}
		
			knownShows["Shows"] += showsToAdd
			knownShows["Version"] = version
			shows = knownShows
		end
	end

	shows["Shows"] = shows["Shows"].sort_by{ |x| x["HumanName"].sub(/^(the)\s/i, '').downcase }
	shows.save_plist(path)

rescue Exception, Timeout::Error => e
	printException(e) 
	exit(1)
end

exit(0)