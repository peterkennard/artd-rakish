require 'rake'

include Rake::DSL

task :default do 
end

task :installGem do |t|
	myDir = File.dirname(__FILE__);
	
	spec = Gem::Specification::load("#{myDir}/rakish.gemspec")
	puts spec.version
	
	cd myDir do
		system("gem build rakish.gemspec");
		system("gem install --user-install rakish-#{spec.version}.gem");
	end
end


