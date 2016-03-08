require 'rake'

include Rake::DSL

module OS
  def OS.windows?
    (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
  end

  def OS.mac?
   (/darwin/ =~ RUBY_PLATFORM) != nil
  end

  def OS.unix?
    !OS.windows?
  end

  def OS.linux?
    OS.unix? and not OS.mac?
  end
end

task :default do 
end

task :installGem do |t|
	myDir = File.dirname(__FILE__);
	
	spec = Gem::Specification::load("#{myDir}/rakish.gemspec")
	# puts spec.version
	
	cd myDir do
		system("gem build rakish.gemspec");
		userstr = OS.windows? ? "" : "--user-install"
		system("gem install --local --pre #{userstr} rakish-#{spec.version}.gem");
	end
end


