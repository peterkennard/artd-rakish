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


@@projectClassHash = {};

def self.newProject(cfg=nil, opts=nil, &b)

    # get list of modules to include, eliminate duplicates, and sort it.
    included = (opts||{})[:includes]||[];
    if included.length > 1
        included = Set.new(included).to_a();
        included.sort! do |a,b|
            a.to_s <=> b.to_s
        end
    end

    # if we already have created a class for the specific included set use it
    unless projClass = @@projectClassHash[included]
        # otherwise create a new class and include the requested modules
        log.debug("Creating new project class including [#{included.join(',')}]");
        projClass = Class.new(TestConfig) do
            included.each do |i|
                include i;
            end
        end
        @@projectClassHash[included] = projClass;
    end
    # create new instance and pass initializer block to it.
    ret = duhClass.new(cfg,opts,&b);
    ret;
end




config = newProject(nil,:includes=>[BaDaBing,BaDaBoom,BaDaBing]) do |c|
	c.printStuff();
	c.printStuff2();
	c.set(:mysym, 121)
end

config2 = newProject(config, :includes=>[BaDaBoom,BaDaBing,BaDaBing]) do |c|
	c.printStuff();
	c.printStuff2();
	log.debug "### new symbol is #{c.get(:mysym)}"
end


task :artdRakishTest => [] do |t|
    log.debug("test complete");
end

end # module Rakish

