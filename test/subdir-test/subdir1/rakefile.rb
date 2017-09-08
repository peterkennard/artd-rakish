myDir = File.dirname(__FILE__);
require "#{myDir}/../../build-options.rb"

Rakish.Project(
    :includes=> [ Rakish::RubydocModule ],
 	:name=>'subdir1',
 	:dependsUpon=> [
 	]
) do |s|

	log.debug("init #{moduleName} test !!");
	
    task :test do |t|
        log.debug("executing #{moduleName} test");
    end

end


