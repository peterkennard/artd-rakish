myDir = File.expand_path(File.dirname(__FILE__));

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

gemspec = Gem::Specification::load("#{myDir}/rakish.gemspec");

task :default do 
end

task :buildGem do |t|
	cd myDir do
		system("gem build rakish.gemspec");
	end
end

task :pushGem do |t|
	cd myDir do
		system("gem push rakish-#{gemspec.version}.gem");
	end
end

task :installGem => [ :buildGem ] do |t|
	cd myDir do
		userstr = OS.windows? ? "" : "--user-install"
		system("gem install --local --pre #{userstr} rakish-#{gemspec.version}.gem");
	end
end


