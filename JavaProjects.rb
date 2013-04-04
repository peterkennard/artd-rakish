myPath = File.dirname(File.expand_path(__FILE__));
require "#{myPath}/RakishProject.rb"

module Rakish


module JavaProjectConfig
    def self.included(base)
        base.addModInit(base,self.instance_method(:initializer));
    end
 	def initializer(pnt)
		@classPaths_=[]

        if(pnt = parent)
            puts("#{__FILE__}(#{__LINE__}) : #{self.class}")
        end
 	end

    def addClassPaths(*defs)
        defs.flatten!()
        defs.each do |ip|
            @classPaths_ << File.expand_path(ip);
        end
    end

end

class JavaProject < Project
	include JavaProjectConfig

	def initialize(args={},&block)
        super(args,&block);
	end
end




end # Rakish

# global  alias for Rakish::JavaProject.new()
def JavaProject(args={},&block)
	Rakish::JavaProject.new(args,&block)
end
