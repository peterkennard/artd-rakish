myDir = File.dirname(File.expand_path(__FILE__));
require "#{myDir}/Rakish.rb"

module Rakish

class InvalidConfigError < Exception # :nodoc:
	def initialize(cfg, msg)
		super("Invalid Configuration \"#{cfg}\": #{msg}.");
	end
end

module BuildConfigModule
	include PropertyBagMod
	include Rake::DSL

 	addInitBlock do |pnt,opts|

 		init_PropertyBag(pnt);
 	#	log.debug("initializing BuildConfig #{pnt}")
 		enableNewFields do |cfg|
			if(pnt)
 				cfg.nativeConfigName = getAnyAbove(:nativeConfigName);
 			end
 		end
 	end


	# constants
	SUPPORTED_HOST_TYPES = [ 'Win64', 'Win32', 'Linux32', 'Linux64', 'Macosx64' ];

	begin
		# get per process/machine constants
		USERNAME = (ENV['USERNAME']||ENV['LOGNAME']);
		def USERNAME
			USERNAME
		end

		os = ENV['OS'];
		if(os =~ /Windows/)
			arch = ENV['PROCESSOR_ARCHITEW6432']
			if(arch =~ /AMD64/)
				HOSTTYPE = 'Win64';
			else
				HOSTTYPE = 'Win32';
			end
			BASEHOSTTYPE = 'Windows';
		else
			uname = %x[uname]
			if(uname =~ /Darwin/)
				htype = 'Macosx'
			else
				htype = 'Linux'
			end
			arch = %x[arch]
			if(arch =~ /x86_64/)
				HOSTTYPE = "#{htype}64"
			else
				HOSTTYPE = "#{htype}32"
			end
			BASEHOSTTYPE = 'Linux'
		end
		def HOSTTYPE
			HOSTTYPE
		end
		def BASEHOSTTYPE
			BASEHOSTTYPE
		end
	end

    # folder to output native libraries and "linkref" files
    # pointing to the actual libraries if not there ( windows DLL libs )
	attr_property 	:nativeLibDir

    # folder to output native object and intermediate files to for this module
	attr_property 	:moduleObjDir

    # folder to output native binary dll and so files to
	attr_property 	:binDir

 	# parsable native configuration name as configuration and
 	# used as a reference to which librarys to link with for a particular
 	# compiler and processor configuration
	attr_property   :nativeConfigName

    # suffix to append to native output binary and library files
    # defaults to the nativeConfigName
	attr_property   :nativeOutputSuffix

    # root folder for build output files
	def buildDir
		@buildDir||=getAnyAbove(:buildDir);
	end

    # folder to output native executable and dll files to.
    # defaults to (buildDir)/bin/(nativeConfigName)
	def binDir
        @binDir||=getAnyAbove(:binDir)||"#{buildDir()}/bin/#{nativeConfigName}";
    end

    # folder to output native library files and link references to.
    # defaults to (buildDir)/lib
	def nativeLibDir
		@nativeLibDir||=getAnyAbove(:nativeLibDir)||"#{buildDir()}/lib";
	end

    # folder to output native intermedite and object files to.
    # config defaults to (buildDir)/obj
    # in a project module defaults to the value set in th (configValue)/(projectName)
	def moduleObjDir
		@moduleObjDir||=getAnyAbove(:moduleObjDir)||"#{buildDir()}/obj";
	end

    # suffix to add to native output files
    # defaults to nativeConfigName
	def nativeOutputSuffix
		@nativeOutputSuffix||=nativeConfigName();
	end

    # temporary include directory built for compiling
    # where generated include files or links to the project sources
    # are created
	def buildIncludeDir
        @buildIncludeDir ||= getInherited(:buildIncludeDir)||"#{@buildDir}/include"
	end

	attr_accessor 	:verbose

	def verbose?
		@verbose ||= getAnyAbove(:verbose);
	end

end


class BuildConfig
	include Util

    # this may need to be changed as rake evolves
    def self.task(*args,&block)
        Rake::Task.define_task(*args, &block)
    end

    def initialize(pnt=nil,opts=nil)
        self.class.initializeIncluded(self,pnt,opts);
		yield self if block_given?
    end
    include BuildConfigModule

end

protected

# global singleton default Rakish.Project configuration
class GlobalConfig < BuildConfig

	@@gcfg = nil

	def globalPaths(&b)
		@initGlobalPaths = b;
	end

	def self.includeConfigType(mod)
		unless GlobalConfig.include? mod	
			include(mod);
		end
	end

   	def buildDir=(val)
   	    @buildDir=val;
   	end

	def initialize(*args, &b)

		if @@gcfg
			raise("Exeption !! You can only initialize one GlobalConfig !!!")
		end

		@@gcfg = self

		opts = (Hash === args.last) ? args.pop : {}

		ensureIncluded = opts[:include];
		if(ensureIncluded != nil) 
			ensureIncluded.each do |ei|
				GlobalConfig.includeConfigType(ei);
			end
		end

		super(nil,{}) {}

		enableNewFields() do |cfg|

			enableNewFields(&b);

			enableNewFields(&@initGlobalPaths) if @initGlobalPaths;

			@buildDir ||= ENV['RakishBuildRoot']||"#{Rake.original_dir}/build";
			@buildDir = File.expand_path(@buildDir);

			config = nil;
			if(HOSTTYPE =~ /Macosx/)
				defaultConfig = "iOS-gcc-fat-Debug";
			else
				defaultConfig = "Win32-VC10-MD-Debug";
			end


			# set defaults if not set above
			@nativeLibDir ||= "#{@buildDir}/lib"

			# get config from command line
			cfg.nativeConfigName ||= ENV['nativeConfigName'];
			cfg.nativeConfigName ||= defaultConfig
			binDir();

		end

		puts("host is #{HOSTTYPE()}") if self.verbose?

        ensureDirectoryTask(@buildDir);

		RakeFileUtils.verbose(@@gcfg.verbose?)
		if(@@gcfg.verbose?)
			puts("Global configuration initialized")
		end
	end

	# return the instance of the GlobalConfig nil if not initialized
	def GlobalConfig.instance
		@@gcfg
	end
end

public

# Declare (create) a new named configuration
#
#  named arguments:
#     :name         => Name for this configuration. This must be unique for all loaded projects,
#                      defaults to 'root'.
#     :include      => [ Array of configuration modules to include ]
#     :inheritsFrom => Parent configuration's name.
#                      Defaults to 'root' if name != 'root'

def self.Configuration(opts={},&block)
    name = opts[:name]||='root'
    me = nil;
    if(name == 'root')
        me = GlobalConfig.new(opts,&block);
    else
        return(nil); # for now.
    end
    me.name=name;
    build.registerConfiguration(me);
    me
end


end # module Rakish

