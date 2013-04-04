myPath = File.dirname(File.expand_path(__FILE__));
require "#{myPath}/RakishProject.rb"

module Rakish


module JavaUtil

    def self.included(other)
    end

end

class JavaProject < Project
	include JavaUtil

	def initialize(args={},&block)
        super(args,&block);
	end
end


end # Rakish

# global  alias for Rakish::JavaProject.new()
def JavaProject(args={},&block)
	Rakish::JavaProject.new(args,&block)
end
