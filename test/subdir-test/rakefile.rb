myDir = File.dirname(__FILE__);
require "#{myDir}/../build-options.rb"

Rakish.Project(
    :includes=> [ Rakish::RubydocModule ],
 	:name=>'subdir-test',
 	:dependsOptionallyUpon=> [
        'notPresent1',
        'optionalSubdir',
        'notPresent2'
    ],
 	:dependsUpon=> [
 	    'subdir1',
 	    'subdir2',
 	    'subdir3'
 	]
) do |s|

	log.debug("init subdir test !!");
	
    task :test => [ ':subdir1:test', ':subdir2:test', ':subdir3:test' ] do |t|
        log.debug("executing subdir test");
        dependencies.each do |dep|
            log.debug("loaded dependency #{dep.projectName}");
        end
    end


end


