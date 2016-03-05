myDir = File.dirname(__FILE__);
require "#{myDir}/../lib/rakish/CppProjects.rb";
require "rakish/JavaProjects.rb";
require "rakish/IntellijConfig.rb";
require "rakish/RubydocModule.rb";

InitBuildConfig :include=>[ Rakish::IntellijConfig, Rakish::CppProjectConfig] do |cfg|

	cfg.thirdPartyPath = File.expand_path("#{myDir}/../../third-party");
	cfg.verbose = false;
	cfg.didiRoot = File.expand_path("#{myDir}/..");
	cfg.buildDir = "#{cfg.didiRoot}/build";
	cfg.resourceDir = "#{cfg.buildDir}/Didi/production/.didi";
	cfg.demoRoot = "#{cfg.buildDir}/Didi/DidiDemos";
	cfg.java_home = ENV['JAVA_HOME'];

	if(cfg.java_home =~ /Program Files \(x86\)/)
		cfg.nativeConfigName = 'Win32-VC10-MD-Debug';
	else
		cfg.nativeConfigName = 'Win64-VC10-MD-Debug'
	end

    cfg.cppDefine('WINVER=0x0700');
	
end


include Rakish::Util

log.debug("logging with util included");

module Rakish

    log.debug "JAVA_HOME is #{ENV['JAVA_HOME']}"

    module Mod1
        addInitBlock do
            log.debug("initializing Mod1");
        end
    end

    module Mod2
        addInitBlock do
            log.debug("initializing Mod2");
        end
    end

    module Mod1
        addInitBlock do |arg|
            log.debug("initializing Mod1-extension");
        end
    end

    module Mod3
        include Mod1
        include Mod2

        addInitBlock do |arg|
            log.debug("initializing Mod3 on #{self} XX #{arg[0]}");
            @foo = "string set by Mod3";
        end
    end

    class InitClass
        include Mod2
        include Mod1
        include Mod3

        def initialize(*args)
            self.class.initializeIncluded(self,args[0]);
            log.debug "initialized #{@foo}";
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
#	binDir = 'build dir'

def binDir
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
#	puts("in init binDir == \"#{binDir}\"")
#	puts("NEWUPPER == \"#{NEWUPPER}\"")
end

#module Rakish
#
#class TestProject < Project
#    include BuildConfigModule
#
#    def TEST_CONST
#        :BLAH
#    end
#
#end
#
#end

module Rakish


#module BooBoo
#
#	addInitBlock do
#        log.debug("initializing a BooBoo block");
#    end
#
#end
#
#module BaDaBoom
#    include BooBoo;
#
#    addInitBlock do
#        log.debug("initializing BaDaBoom on #{self}");
#        @myString = "ba do boom";
#    end
#
#    def printStuff
#        log.debug(@myString);
#    end
#
#end
#
#module BaDaBing
#
#    def printStuff2
#        log.debug("ba da bing!");
#    end
#
#end
#
#Rakish::TestProject.new( :name=>'project0'
#) do |c|
#	log.debug("test const is #{c.TEST_CONST}");
#end
#
#config = RakishProject(:name=>'project1', :extends=>TestProject, :includes=>[BaDaBing,BaDaBoom,BaDaBing,BooBoo]) do |c|
#
#
#
#	c.printStuff();
#	c.printStuff2();
#	log.debug("test const is #{c.TEST_CONST}");
#	c.set(:mysym, 121)
#end
#
#config2 = RakishProject(:name=>'project2', :config=>config, :includes=>[BaDaBoom,BaDaBing,BaDaBing]) do |c|
#	c.printStuff();
#	c.printStuff2();
#	log.debug "### new symbol is #{c.get(:mysym)}"
#	log.debug("test const is #{c.TEST_CONST}");
#end
#
#NewClass = Class.new
#
#log.debug("new name is #{NewClass.new().class.name()}");

task :propertyBagTest => [] do |t|

    cf1 = BuildConfig.new do |cfg|
        cfg.enableNewFields do
            cfg.field1 = "field1"
        end
    end
    cf2 = BuildConfig.new(cf1) do |cfg|
        log.debug("#### fields enabled #{cfg.newFieldsEnabled?}")
		
		begin
		   cfg.unknown;
		rescue
		   log.debug("#### unknown field fail");
		end
		
		cfg.enableNewFields do
			cfg.unknown="value set into unknown";
			begin
			   log.debug(cfg.unknown);
			rescue
			   log.debug("#### unknown field fail");
			end
			if(cfg.newFieldsEnabled?)
			   log.debug("true fields enabled #{cfg.newFieldsEnabled?}")
			else 
			   log.debug("false fields enabled #{cfg.newFieldsEnabled?}")
			end
            cfg.field2 = "field2"
        end
        log.debug("fields enabled #{cfg.newFieldsEnabled?}")
    end

    f1 = cf2.get(:field1);

    log.debug("f1 == #{f1}");

    path = ENV["PATH"];

    path = path.split(';');

    path = path.join("\n           ");

    puts("path = #{path}");

end

RakishProject(
 	:name=>'test-project1',
 	:dependsUpon=> [
 	]
) do

    task :test do |t|
        log.debug("doing #{t.name}");
    end

end

RakishProject(
    :includes=> [ Rakish::RubydocModule ],
 	:name=>'test-project2',
 	:dependsUpon=> [
 	]
) do |s|

	log.debug(" here acccessing s");
	
    docs = s.createRubydocBuilder();

		begin
		   self.unknown;
		rescue
		   log.debug("#### unknown field fail");
		end

    export (task :rubydocs => [ docs.rubydocTask() ]);

    task :test => [ :rubydocs, ':test-project1:test' ] do |t|
        log.debug("doing #{t.name}");
        tsk = lookupTask(':test-project1:test');
        log.debug("found #{tsk}");
    end

end



#task :default => [ ':test-project2:test' ] do |t|
#    log.debug("test complete");
#end


end  # Rakish


