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

task :default do
end

task :buildGem do |t|
	cd myDir do
	    ENV['RAKISH_UNSIGNED']='0';
		system("gem build rakish.gemspec");
	end
end

task :buildUnsignedGem do |t|
	cd myDir do
	    ENV['RAKISH_UNSIGNED']='1';
		system("gem build rakish.gemspec");
	end
end

task :pushGem => [:buildGem] do |t|
	cd myDir do
	    ENV['RAKISH_UNSIGNED']='0';
		system("gem push rakish-#{gemspec.version}.gem");
	end
end

task :installGem => [:buildUnsignedGem] do |t|
	cd myDir do

	    ENV['RAKISH_UNSIGNED']='1';
        gemspec = Gem::Specification::load("#{myDir}/rakish.gemspec");

		userstr = OS.windows? ? "" : "--user-install"
		system("gem install --local --pre #{userstr} rakish-#{gemspec.version}.gem");
	end
end

task :cleanAll do |t|
end

# just here to handle being called from exec-rake.bat dealing with quoted empty arguments
task '' do
end