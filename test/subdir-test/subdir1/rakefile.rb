myDir = File.dirname(__FILE__);
require "#{myDir}/../../build-options.rb"

Rakish.Project(
    :includes=> [ Rakish::RubydocModule ],
 	:name=>'subdir1',
 	:dependsUpon=> [
 	]
) do |s|

	log.debug("init subdir1 test !!");
	
    task :test do |t|
        log.debug("executing subdir1 test");
    end

end


