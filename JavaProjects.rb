myPath = File.dirname(File.expand_path(__FILE__));
require "#{myPath}/RakishProject.rb"

module Rakish


module JavaProjectConfig

    attr_reader :outputClasspath

    def self.included(base)
        base.addModInit(base,self.instance_method(:initializer));
    end
 	def initializer(pnt)
		@classPaths_= Set.new;
 	end

    def addClassPaths(*defs)
        defs.flatten!()
        defs.each do |ip|
            @classPaths_.add(File.expand_path(ip));
        end
    end
end

class JavaProject < Project
    include JavaProjectConfig

    def initialize(args={},&block)

        super(args,&block);

    end

    def javacTask

        Rakish.log.info "javaC task";
        puts("#{__FILE__}(#{__LINE__}) : autogen in artd-bml-rpc #{jdk_}");
        puts "BUILDDIR = #{BUILDDIR()}"
        puts "outputClasspath = #{outputClasspath}"
    end


    def javac()

        cmdline = "\"#{jdk_}/bin/javac.exe\" -help";
        puts cmdline
     #   system( cmdline );

    end

    # output directory common to all configurations
    def outputClasspath
        @outputClasspath||="#{BUILDDIR()}/production/#{moduleName()}";
    end

end




end # Rakish

# global  alias for Rakish::JavaProject.new()
def JavaProject(args={},&block)
	Rakish::JavaProject.new(args,&block)
end
