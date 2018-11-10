myDir = File.dirname(__FILE__);
require "#{myDir}/../../build-options.rb"

Rakish.Project(
    :includes=> [ Rakish::RubydocModule ],
 	:name=>'subdir1',
 	:dependsUpon=> [
 	]
) do |s|

	log.debug("init #{projectName} test !!");
	
    task :test do |t|
        log.debug("executing #{projectName} test");
    end

end


