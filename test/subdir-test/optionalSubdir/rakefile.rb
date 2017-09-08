myDir = File.dirname(__FILE__);
require "#{myDir}/../../build-options.rb"

Rakish.Project(
    :includes=> [ Rakish::RubydocModule ],
 	:name=>'optionalSubdir',
 	:dependsUpon=> [
 	]
) do |s|

	log.debug("init optionalSubdir test !!");
	
    task :test do |t|
        log.debug("executing optionalSubdir test");
    end

end


