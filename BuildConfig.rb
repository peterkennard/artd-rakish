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
 				cfg.CONFIG = pnt.CONFIG
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
	attr_accessor 	:BUILDDIR

	def OBJDIR
		@OBJDIR||=(@parent_ ? @parent_.OBJDIR : nil)
	end

	def configureTools()
		if(defined? self.CONFIG)
            require File.join(MAKEDIR,'PlatformTools.rb');
            @@tools_ ||= PlatformTools.getConfiguredTools(self.CONFIG,self);
            @@objx_ = @@tools_.OBJEXT
            @@libx_ = @@tools_.LIBEXT
            @@dllx_ = @@tools_.DLLEXT
            @@dllx_ = @@tools_.EXEEXT
		end
	end

	def OBJEXT
		@@objx_
	end
	def LIBEXT
		@@libx_
	end
	def DLLEXT
		@@dllx_
	end
	def EXEEXT
		@@dllx_
	end
	def tools
		@@tools_
	end

	attr_accessor 	:verbose
	def verbose?
		@verbose ||= (@parent_ ? @parent_.verbose? : nil)
	end
end


class BuildConfig < Module
    include Util

    @@_inits = {};

    def initialize(pnt=nil)

        # puts("initalizing #{self}");

        # initalize the included "config" modules from parent config
        self.class.ancestors.reverse_each do |ancestor|
            inits = @@_inits[ancestor.hash];
            if(inits != nil)
                inits.each do |init|
            #        puts("   --> init for #{self} for #{init}");
                    init.bind(self).call(pnt);
                end
            end
        end
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

	attr_property :CONFIG
	attr_property :thirdPartyPath

	def initialize(&b)

		if @@gcfg
			raise("Exeption !! You can only initialize one GlobalConfig !!!")
		end

		@@gcfg = self

		super(nil) {}

		enableNewFields() do |cfg|

			enableNewFields(&b);

			enableNewFields(&@initGlobalPaths) if @initGlobalPaths;

			config = nil;
			if(HOSTTYPE =~ /Macosx/)
				defaultConfig = "iOS-gcc-fat-Debug";
			else
				defaultConfig = "Win32-VC8-MD-Debug";
			end

			@BUILDDIR ||= "#{MAKEDIR}/../rakebuild";
			@BUILDDIR = File.expand_path(@BUILDDIR);

			# set defaults if not set above
			@LIBDIR = "#{@BUILDDIR}/lib"
			@BINDIR = "#{@BUILDDIR}/bin"
			@INCDIR = "#{@BUILDDIR}/include"

			# get config from command line
			cfg.CONFIG ||= ENV['CONFIG'];
			cfg.CONFIG ||= defaultConfig

			cfg.thirdPartyPath ||= File.join(MAKEDIR,'../../third-party');
			cfg.thirdPartyPath = File.expand_path(cfg.thirdPartyPath);

		end

		puts("host is #{HOSTTYPE()}") if self.verbose?

		configureTools();

		task :includes => [ @BUILDDIR, @INCDIR ]

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




# require("#{Rakish::MAKEDIR}/RakishProjects.rb");

