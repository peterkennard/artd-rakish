myDir = File.dirname(__FILE__);
require "#{myDir}/../build-options.rb"

Rakish.Project(
    :includes=> [ Rakish::RubydocModule ],
 	:name=>'subdir-test',
 	:dependsUpon=> [
 	    'subdir1',
 	    'subdir2',
 	    'subdir3'
 	]
) do |s|

	log.debug("init subdir test !!");
	
    task :test => [ ':subdir1:test', ':subdir2:test', ':subdir3:test' ] do |t|
        log.debug("executing subdir test");
    end

end


