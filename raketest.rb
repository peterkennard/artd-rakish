myDir = File.dirname(__FILE__);
unless defined? MAKEDIR
    MAKEDIR=File.expand_path("#{myDir}");
end
require "#{MAKEDIR}/CppProjects.rb";
require "#{MAKEDIR}/JavaProjects.rb";

include Rakish::Util

module Rakish

    puts "FOO is #{ENV['FOO']}"

    module Mod1
        addInitBlock do
            puts("initializing Mod1");
        end
    end

    module Mod2
        addInitBlock do
            puts("initializing Mod2");
        end
    end

    module Mod1
        addInitBlock do |arg|
            puts("initializing Mod1-extension");
        end
    end

    module Mod3
        include Mod1
        include Mod2

        addInitBlock do |arg|
            puts("initializing Mod3 on #{self} XX #{arg[0]}");
            @foo = "string set by Mod3";
        end
    end

    class InitClass
        include Mod2
        include Mod1
        include Mod3

        def initialize(*args)
            self.class.initializeIncluded(self,args[0]);
            puts "initialized #{@foo}";
        end
    end

    InitClass.new("arg1","arg2");




	module Util
		def testMethod()
			log.debug("###### testing")
		end
		
		def Util.staticMethod()
			puts.debug("###### static testing")
		end
	end

	class Project
		include Util
	
		CONST1 = "a const"
	end

end

module Constants
	CONSTA = 'xxxx'
end

class MyObj < Module
	include Rakish::PropertyBagMod
	
	CONSTA = 'yyyyy'	
#	BINDIR = 'build dir'

def BINDIR
	'build dir'
end
	
	attr_property :NEWUPPER
	
	def initialize(&b)
		init_PropertyBag()
		super &b
	
	# self.instance_eval(&b)
	end
	
	def putit
		log.info("CONST == \"#{CONSTA}\"")
	end
end

def FooObj(&block)
	MyObj.new(&block).putit()
end 

class MyObj
	log.info("CONST == \"#{CONSTA}\"")
end

FooObj do 
#	puts("in init BINDIR == \"#{BINDIR}\"")
#	puts("NEWUPPER == \"#{NEWUPPER}\"")
end

module Rakish

class TestProject < Project
    include BuildConfigMod

    def TEST_CONST
        :BLAH
    end

end

end

module Rakish

module BooBoo

	addInitBlock do
        log.debug("initializing a BooBoo block");
    end

end

module BaDaBoom
    include BooBoo;

    addInitBlock do
        log.debug("initializing BaDaBoom on #{self}");
        @myString = "ba do boom";
    end

    def printStuff
        log.debug(@myString);
    end

end

module BaDaBing

    def printStuff2
        log.debug("ba da bing!");
    end

end

Rakish::TestProject.new( :name=>'project0'
) do |c|
	log.debug("test const is #{c.TEST_CONST}");
end

config = RakishProject(:name=>'project1', :extends=>TestProject, :includes=>[BaDaBing,BaDaBoom,BaDaBing,BooBoo]) do |c|



	c.printStuff();
	c.printStuff2();
	log.debug("test const is #{c.TEST_CONST}");
	c.set(:mysym, 121)
end

config2 = RakishProject(:name=>'project2', :config=>config, :includes=>[BaDaBoom,BaDaBing,BaDaBing]) do |c|
	c.printStuff();
	c.printStuff2();
	log.debug "### new symbol is #{c.get(:mysym)}"
	log.debug("test const is #{c.TEST_CONST}");
end

NewClass = Class.new

log.debug("new name is #{NewClass.new().class.name()}");

task :artdRakishTest => [] do |t|
    log.debug("test complete");
end




end


