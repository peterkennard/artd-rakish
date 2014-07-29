myDir = File.dirname(__FILE__);
unless defined? MAKEDIR
    MAKEDIR=File.expand_path("#{myDir}");
end
require "#{MAKEDIR}/CppProjects.rb";
require "#{MAKEDIR}/JavaProjects.rb";

include Rakish::Util

module Rakish

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

class TestConfig < BuildConfig
    include BuildConfigMod
end

module BaDaBoom

    def printStuff
        log.debug("ba da boom!");
    end

end

module BaDaBing

    def printStuff2
        log.debug("ba da bing!");
    end

end

config = RakishProject(:name=>'project1', :includes=>[BaDaBing,BaDaBoom,BaDaBing]) do |c|
	c.printStuff();
	c.printStuff2();
	c.set(:mysym, 121)
end

config2 = RakishProject(:name=>'project2', :config=>config, :includes=>[BaDaBoom,BaDaBing,BaDaBing]) do |c|
	c.printStuff();
	c.printStuff2();
	log.debug "### new symbol is #{c.get(:mysym)}"
end


task :artdRakishTest => [] do |t|
    log.debug("test complete");
end

end # module Rakish

