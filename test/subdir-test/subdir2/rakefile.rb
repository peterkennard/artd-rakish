myDir = File.dirname(__FILE__);
require "#{myDir}/../../build-options.rb"

Rakish.Project(
    :includes=> [ Rakish::RubydocModule ],
 	:name=>'subdir2',
 	:dependsUpon=> [
 	]
) do |s|

	log.debug("init subdir2 test !!");
	
    task :test do |t|
        log.debug("executing subdi2 test");
    end

end


