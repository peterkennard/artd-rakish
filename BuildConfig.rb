myDir = File.dirname(File.expand_path(__FILE__));
require "#{myDir}/Rakish.rb"

module Rakish

module BuildConfigMod
	include PropertyBagMod
	include Rake::DSL

    def self.included(base)
        base.addModInit(base,self.instance_method(:initializer));
    end

 	def initializer(pnt)
 		init_PropertyBag(pnt);
 		enableNewFields do |cfg|
			if(pnt)
 				cfg.CPP_CONFIG = pnt.CPP_CONFIG
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


	def BUILDDIR
		@BUILDDIR||=(@parent_ ? @parent_.BUILDDIR : nil)
	end

	def OBJDIR
		@OBJDIR||=(@parent_ ? @parent_.OBJDIR : nil)
	end

	attr_accessor 	:verbose

	def verbose?
		@verbose ||= (@parent_ ? @parent_.verbose? : nil)
	end
end


class BuildConfig
	include Util


    @@_inits = {};

    def initialize(pnt=nil)

        # puts("initalizing #{self}");

        # initalize the included "config" modules from parent config
        self.class.ancestors.reverse_each do |ancestor|
            inits = @@_inits[ancestor.hash];
            if(inits)
                inits.each do |init|
                    # puts("   --> init for #{self} for #{init}");
                    init.bind(self).call(pnt);
                end
            end
        end
		yield if block_given?
    end

    protected
    def self.addModInit(base,init)
        (@@_inits[base.hash] ||= []) << init;
    end

    include BuildConfigMod

end


# global singleton default RakishProject configuration
class GlobalConfig < BuildConfig

	@@gcfg = nil

	def globalPaths(&b)
		@initGlobalPaths = b;
	end

	attr_property :CPP_CONFIG

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

		super(nil) {}

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
			@LIBDIR = "#{@BUILDDIR}/lib"
			@BINDIR = "#{@BUILDDIR}/bin"
			@INCDIR = "#{@BUILDDIR}/include"

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
def InitBuildConfig(&block)
	Rakish::GlobalConfig.new(&block)
end


# Convenience method for Rakish::ProjectConfig.new(&block)
def ProjectConfig(&block)
#	Rakish::ProjectConfig.new(&block)
end
