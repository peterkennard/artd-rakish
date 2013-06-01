myDir = File.dirname(File.expand_path(__FILE__));
require "#{myDir}/Rakish.rb"

module Rakish
	
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
				libdef = File.expand_path("#{libdef}-#{CPP_CONFIG()}.linkref");
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
		init_LinkConfig(pnt) # left to do 
	end
	
public
	
	def debug=(d)
		@debug=d 
	end
end


# global singleton default RakishProject configuration
class GlobalConfig < Module

	attr_property :CPP_CONFIG
	attr_property :thirdPartyPath
	
	def initialize(&b)	

		## stuff from old gnu makefiles
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
end

end # module Rakish
