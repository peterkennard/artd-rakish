
myDir = File.dirname(File.expand_path(__FILE__));
require "#{myDir}/Rakish.rb"

module Rakish


module BuildConfigMod
	include PropertyBagMod
	include Rake::DSL

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
	
			
	def init_BuildConfig(pnt)

		return if(defined? @__BCfgInit__)
		@__BCfgInit__ = true;
		init_PropertyBag(pnt);
	
		enableNewFields do |cfg|
			if(pnt) 
				cfg.CONFIG = pnt.CONFIG
			end
		end	
	end
		
	def configureTools()	
		require File.join(MAKEDIR,'PlatformTools.rb');		
		@@tools_ ||= PlatformTools.getConfiguredTools(self.CONFIG,self);
		@@objx_ = @@tools_.OBJEXT
		@@libx_ = @@tools_.LIBEXT
		@@dllx_ = @@tools_.DLLEXT
		@@dllx_ = @@tools_.EXEEXT
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

module CppConfigMod
	include BuildConfigMod

	attr_accessor   :INCDIR 
	
	def addedIncPaths(from)
		ips=[]
		s=FileSet.new;
		if(from) # bodge for ignoring implicit './' 
			s.add(from.myDir)
		end
		@iPaths_.each do |ip|
			ips << ip if s.add?(ip)
		end
		if(@parent_ && @parent_ != from) 
			@parent_.addedIncPaths(from).each do |ip|
				ips << ip if s.add?(ip)
			end
		end
		ips;
	end
	
	#accessor returns "set" with parent's entries after this ones entries
	def incPaths				
		unless defined? @bcIp_
			@bcIp_ = addedIncPaths(nil)
		end
		@bcIp_
	end
	
	attr_reader	:defines
	attr_reader	:cflags

	def init_CppConfig(*args)

		return if(defined? @__CppcfgInit__)
		@__CppcfgInit__ = true;
	
		init_BuildConfig(*args)
		pnt = self.parent
		
		enableNewFields do |cfg|
			if(pnt = parent) 
				cfg.CONFIG = pnt.CONFIG
			end
		end	
			
		@defines={}
		@iPaths_=[]
		@cflags=[]
				
		if(pnt = parent)
		
		# puts("#{__FILE__}(#{__LINE__}) : #{self.class}")

			@defines.merge!(pnt.defines)
			@cflags.concat(pnt.cflags)
			@verbose = pnt.verbose?
			@INCDIR = pnt.INCDIR
			@BUILDDIR = pnt.BUILDDIR
		end		
	end

	def cppDefine(*args)
		args.flatten!()
		args.each do |c|
			spl = c.split('=',2);
			# no value is nil, XXX= will have a value of empty string "" 
			@defines[spl[0]] = spl[1];
		end
	end

	def cppUndefine(*args)
		args.flatten!()
		args.each do |c|
			@defines.delete(c)
		end
	end
	
	def addIncludePaths(*defs)	
		defs.flatten!()
		defs.each do |ip|
			@iPaths_ << File.expand_path(ip);
		end	
	end	
end
	
class CppConfig < Module
	include CppConfigMod
	def initialize(pnt=nil)
		init_CppConfig(pnt)
	end
end
	
module LinkConfigMod
	include BuildConfigMod
	
	attr_reader 	:libpaths
		
	def init_LinkConfig(*args)

		init_BuildConfig(*args)

		if(pnt = self.parent)
			@libpaths=[]
			@LIBDIR||=pnt.LIBDIR
			@BINDIR||=pnt.BINDIR
		else
			@libpaths=[]
		end
	end

	def addLibPaths(*lp)
		@libpaths|=lp
	end				
end

module LinkTargetMod 	
	include LinkConfigMod

	def objs
		@objs
	end
	
	def init_LinkTarget(pnt=nil)
		init_LinkConfig(pnt)
		@objs ||=[]
		@libs ||=[]
	end
	
	def addLibs(*l)
		@libs|=l
	end

	def addObjs(*o)
		@objs |= o.flatten;
	end	
	
	def addLinkrefs(dir,list)
		
        cd(dir, :verbose=>false) do
			(list||[]).flatten.each do |libdef|
				libdef = File.expand_path("#{libdef}-#{CONFIG()}.linkref");
				begin
					libpaths=nil
					libs=nil
					eval(File.new(libdef).read)
					if(libpaths)
						libpaths.collect! do |lp|
							File.expand_path(lp)
						end
						addLibPaths(libpaths)
					end
					if(libs)
						libs.collect! do |lp|
							File.expand_path(lp)
						end
						addLibs(libs)
					end
				end
			end
		end
	end
	
	def resolve						
		@resolved_=true

		lpathset = FileSet.new
		lpaths = [];

		(@libpaths||[]).flatten.each do |lp|
			lpaths << lp if lpathset.add?(lp)
		end
        
        addLinkrefs("#{thirdPartyPath}/lib", @thirdPartyLibs);
        addLinkrefs(LIBDIR(),@projectLibs);

		libset = FileSet.new;				
		libs = [];

		(@libs || []).flatten.each do |l|
			libs << l if libset.add?(l)
		end
		
		libset = FileSet.new;				

		# $(LIB_FILES) $(THIRD_PARTY_LIB_FILES) 
		# $(SPECIFIC_LIBS) 
		# $(EXTRA_LIBS_WINDOWS) 
		# $(SDK_LIBS)

		@libs||=[]
		libs=[]

		@libs.flatten.each do |lib|
			if(lib.pathmap("%X") === '.linkref')
				puts("###### LINKREF lib #{lib}")
				next
			end
#			lib = ensureLibSuffix(lib);
			lib = File.expand_path(lib);
#			puts("###### adding lib #{lib}")
			libs << lib if libset.add?(lib)	
		end
		
		@libs = libs;
		return
	end

	def libs()
		resolve unless defined? @resolved_
		@libs
	end

	def libpaths()
		resolve unless defined? @resolved_
		@libpaths
	end
	
	def addLibpaths(lpaths)
		@libpaths ||= []
		@libpaths << lpaths
	end
	
	def addProjectLibs(*args)
		@projectLibs ||= []
		@projectLibs << args
	end
	
	def addThirdPartyLibs(*args)		
        @thirdPartyLibs ||= []
		@thirdPartyLibs << args
	end
end

class ProjectConfig < Module
	include CppConfigMod
	include LinkConfigMod
	include Util
	
	def initialize(pnt=nil,&block)	

		begin		
		
			super() {}
			init_CppConfig(pnt)
			init_LinkConfig(pnt)
			
			enableNewFields(&block) if block_given?

			@LIBDIR ||= "#{@BUILDDIR}/lib"
			@BINDIR ||= "#{@BUILDDIR}/bin"
			@INCDIR ||= "#{@BUILDDIR}/include"
			
			ensureDirectoryTask(@INCDIR);
			task :includes => [ @BUILDDIR, @INCDIR ]

			# for now default to non-verbose if no global config is set
			RakeFileUtils.verbose(false) unless GlobalConfig.instance
			
			configureTools();
			
		rescue => e
			puts e
			# puts("#{__FILE__}(#{__LINE__}) : #{e}")
			puts e.backtrace.join("\n\t")
			raise e
		end
	end
	
public
	
	def tools=(bt)
		setTools(bt)
	end
	def debug=(d)
		@debug=d 
	end
end


# global singleton default RakishProject configuration
class GlobalConfig < Module
	include CppConfigMod
	include LinkConfigMod
	include Util
	
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

		init_CppConfig(nil)
		init_LinkConfig(nil)
		super() {}

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

#endif
#
#ifeq ($(HOSTTYPE),)
#     WARN_CONFIG := 1
#endif
#
#ifeq ($(BASEHOSTTYPE),)
#     BASEHOSTTYPE := $(BASEHOST_$(HOSTTYPE))
#endif
#			
			# ------------ validate configuration flags ------------

#ifeq ($(PLATFORM),)
#	PLATFORM := $(HOSTTYPE)
#	BASEPLATFORM := $(BASEHOSTTYPE)
#	WARN_CONFIG := 1
#endif
#ifeq ($(COMPILER),)
#	ifeq ($(BASEPLATFORM),Windows)
#		COMPILER := VC9
#		BASECOMPILER := VC
#	else
#		COMPILER := GCC3
#		BASECOMPILER := GCC
#	endif
#	WARN_CONFIG := 1
#endif
#ifeq ($(LINKAGETYPE),)
#	ifeq ($(BASECOMPILER),GCC)
#		LINKAGETYPE := Dynamic
#		BASELINKAGE := Dynamic
#	else
#		LINKAGETYPE := MDd
#		BASELINKAGE := Dynamic
#	endif
#	WARN_CONFIG := 1
#endif
#ifeq ($(DEBUGTYPE),)
#	DEBUGTYPE := Debug
#	WARN_CONFIG := 1
#endif
#
			
#ifeq ($(SDK_VERSION),)
#	SDK_VERSION := 0.9.0
#endif
#ifeq ($(VERSION),)
#	VERSION := $(SDK_VERSION)
#endif
#ifeq ($(DEBUGTYPE),Release)
#	ifeq ($(BASEPLATFORM),Windows)
#		ifeq ($(LINKAGETYPE),MD)
#			OUTPUT_SUFFIX := $(VERSION)-$(PLATFORM)-$(COMPILER)
#		else
#			OUTPUT_SUFFIX := $(VERSION)-$(PLATFORM)-$(COMPILER)-$(LINKAGETYPE)
#		endif
#	else
#		ifeq ($(LINKAGETYPE),Dynamic)
#			OUTPUT_SUFFIX := $(VERSION)-$(PLATFORM)-$(COMPILER)
#		else
#			OUTPUT_SUFFIX := $(VERSION)-$(PLATFORM)-$(COMPILER)-$(LINKAGETYPE)
#		endif
#	endif		
#else
#	OUTPUT_SUFFIX := $(PLATFORM)-$(COMPILER)-$(LINKAGETYPE)-$(DEBUGTYPE)
#endif
#UNVERSIONED_SUFFIX := $(PLATFORM)-$(COMPILER)-$(LINKAGETYPE)-$(DEBUGTYPE)
#		
						
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
	Rakish::ProjectConfig.new(&block)
end


require("#{Rakish::MAKEDIR}/RakishProjects.rb");

