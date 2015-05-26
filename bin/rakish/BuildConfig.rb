myDir = File.dirname(File.expand_path(__FILE__));
require "#{myDir}/Rakish.rb"

module Rakish

class InvalidConfigError < Exception
	def initialize(cfg, msg)
		super("Invalid Configuration \"#{cfg}\": #{msg}.");
	end
end

module BuildConfigMod
	include PropertyBagMod
	include Rake::DSL

 	addInitBlock do |pnt,opts|

 		init_PropertyBag(pnt);
 	#	log.debug("initializing BuildConfig #{pnt}")
 		enableNewFields do |cfg|
			if(pnt)
 				cfg.CPP_CONFIG = getInherited(:CPP_CONFIG);
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

	attr_accessor 	:LIBDIR
	attr_accessor 	:BINDIR
 	attr_property	:thirdPartyPath
	attr_property   :CPP_CONFIG


	def BUILDDIR
		@BUILDDIR||=getInherited(:BUILDDIR);
	end

	def OBJDIR
		@OBJDIR||=getInherited(:OBJDIR);
	end

	def BINDIR
        @BINDIR||=getInherited(:BINDIR)||"#{BUILDDIR()}/bin";
	end

	attr_accessor 	:verbose

	def verbose?
		@verbose ||= getInherited(:verbose);
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
    include BuildConfigMod

end


# global singleton default RakishProject configuration
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

   	def BUILDDIR=(val)
   	    @BUILDDIR=val;
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

			cfg.thirdPartyPath ||= File.join(ENV['ARTD_TOOLS'],'../.');
			cfg.thirdPartyPath = File.expand_path(cfg.thirdPartyPath);

			@BUILDDIR ||= ENV['RakishBuildRoot']||"#{Rake.original_dir}/build";
			@BUILDDIR = File.expand_path(@BUILDDIR);

			config = nil;
			if(HOSTTYPE =~ /Macosx/)
				defaultConfig = "iOS-gcc-fat-Debug";
			else
				defaultConfig = "Win32-VC10-MD-Debug";
			end


			# set defaults if not set above
			@LIBDIR ||= "#{@BUILDDIR}/lib"
			@BINDIR ||= "#{@BUILDDIR}/bin"
			@INCDIR ||= "#{@BUILDDIR}/include"

			# get config from command line
			cfg.CPP_CONFIG ||= ENV['CPP_CONFIG'];
			cfg.CPP_CONFIG ||= defaultConfig

		end

		puts("host is #{HOSTTYPE()}") if self.verbose?

        ensureDirectoryTask(@BUILDDIR);

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


end # module Rakish

# Convenience method for Rakish::GlobalConfig.initInstance(&block)
def InitBuildConfig(opts={},&block)
	Rakish::GlobalConfig.new(opts,&block)
end


# Convenience method for Rakish::ProjectConfig.new(&block)
def ProjectConfig(&block)
#	Rakish::ProjectConfig.new(&block)
end
