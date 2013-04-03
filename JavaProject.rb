myPath = File.dirname(File.expand_path(__FILE__));
require "#{myPath}/RakishProjects.rb"

module Rakish


module JavaUtil

    JDK = "jdk path";


    def initializeJavaUtil()
#        puts(" JavaUtil initializing in #{self}");
    end

    def self.included(other)
#        puts(" JavaUtil included by #{other}");
    end

end

class JavaProject < Project
	include JavaUtil

	def initialize(args={},&block)
        initializeJavaUtil();
        super(args,&block);
	end
end


end # Rakish

# global  alias for Rakish::JavaProject.new()
def JavaProject(args={},&block)
	Rakish::JavaProject.new(args,&block)
end
