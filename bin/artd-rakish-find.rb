#!/usr/bin/env ruby

args = ARGV;

if(args[0] === 'exec-rake.bat')
    puts File.expand_path("#{ENV['ARTD_TOOLS']}exec-rake.bat");
elsif(args[0] === 'call-rake.xml')
    puts "#{File.expand_path(File.dirname(__FILE__))}/artd-rakish-bin/call-rake.xml";
end
