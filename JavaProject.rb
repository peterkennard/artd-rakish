myPath = File.dirname(File.expand_path(__FILE__));
require "#{myPath}/RakishProjects.rb"

module Rakish

class JavaProject < Project
	def initialize(args={},&block)
	    super(args,&block);
	end
end


end # Rakish

# global  alias for Rakish::JavaProject.new()
def JavaProject(args={},&block)
	Rakish::JavaProject.new(args,&block)
end
