myDir = File.dirname(__FILE__);
require "#{myDir}/../../build-options.rb"

Rakish.Project(
    :includes=> [ Rakish::RubydocModule ],
 	:name=>'subdir3',
 	:dependsUpon=> [
 	]
) do |s|

	log.debug("init subdir3 test !!");
	
    task :test do |t|
        log.debug("executing subdir3 test");
    end

end


