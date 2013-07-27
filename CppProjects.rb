myPath = File.dirname(File.expand_path(__FILE__));
require "#{myPath}/RakishProject.rb"

module Rakish


class InvalidConfigError < Exception
	def initialize(cfg, msg)
		super("Invalid Configuration \"#{cfg}\": #{msg}.");
	end
end


module CTools
	include Rakish::Logger
	include Rakish::Util

	VALID_PLATFORMS = { 
		:Win32 => {
			:module => "#{MAKEDIR}/WindowsCppTools.rb",
		},
		:Win64 => {
			:module => "#{MAKEDIR}/WindowsCppTools.rb",
		},
		:iOS => {
			:module => "#{MAKEDIR}/IOSCTools.rb",
		},
		:Linux32 => {
			:module => "#{MAKEDIR}/GCCCTools.rb",
		},
		:Linux64 => {
			:module => "#{MAKEDIR}/GCCCTools.rb",
		},
	};

	# parses and validates an unknown string configuration name 
	# of the format [TargetPlatform]-[Compiler]-(items specific to compiler type)
	# and loads if possible an instance of a set of configured "CTools" 
	# for the specified "CPP_CONFIG" configuration.
	def self.loadConfiguredTools(strCfg)
		
		splitcfgs = strCfg.split('-');
		platform  = VALID_PLATFORMS[splitcfgs[0].to_sym];
			
		unless platform
			raise InvalidConfigError.new(strCfg, "unrecognized platform \"#{splitcfgs[0]}\"");
		end
		factory = LoadableModule.load(platform[:module]);
		factory.getConfiguredTools(splitcfgs,strCfg);

	end

	def writeLinkref(cfg,baseName,targetName)
					
		defpath = "#{cfg.LIBDIR}/#{baseName}-#{cfg.CPP_CONFIG}.linkref"
		reltarget = getRelativePath(targetName,cfg.LIBDIR);
		File.open(defpath,'w') do |f|
			f.puts("libs = [\'#{reltarget}\']")
		end
	end

	# real bodge for now need to clean this up somehow.
	def loadLinkref(libdir,cfg,baseName)
		cd libdir, :verbose=>false do
			libdef = File.expand_path("#{baseName}-#{cfg}.linkref");
			begin
				libpaths=nil
				libs=nil
				eval(File.new(libdef).read)
				if(libpaths)
					libpaths.collect! do |lp|
						File.expand_path(lp)
					end
				end
				if(libs)
					libs.collect! do |lp|
						File.expand_path(lp)
					end
				end
				return({libpaths: libpaths, libs: libs});
			rescue => e
				log.debug("failed to load #{libdef} #{e}");
			end
			{}
		end
	end

    # given a list of dependencies will write out a '.raked' format dependencies file 
    # for the target task
	def updateDependsFile(task, outName, dependencies)
				
		srcfile = task.source
		tempfile = "#{outName}.temp";
				
		File.open(tempfile,'w') do |out|			
			if(dependencies.size > 0)
				out.puts "t = Rake::Task[\'#{task.name}\'];"
				out.puts 'if(t)'
				out.puts ' t.enhance ['
				out.puts " \'#{srcfile}\',"
				dependencies.each do |f|
					out.puts " \'#{f}\',"
				end
				out.puts ' ]'
				out.puts 'end'
			end
		end
				
        # only touch file if new file differs from old one
		if(textFilesDiffer(outName,tempfile)) 
            # @#$#@$#@ messed up. set time of new file ahead by one second.
            # seems rake time resolution is low enough that the comparison often says 
            # times are equal between depends files and depends.rb.
            mv(tempfile, outName, :force=>true);
            time = Time.at(Time.new.to_f + 1.0);
            File.utime(time,time,outName);
		else
			rm(tempfile, :force=>true);
		end	
	end


	## Overidables for specific toolsets to use or supply

	# override to make sure options such as cppDefines, system library paths,
	# system include paths and the like are enforced as needed for this toolset
	def ensureConfigOptions(cfg)
	end
	
	def systemIncludePaths
		[]
	end

	@@doNothingAction_ = lambda do |t|
		log.debug("attempting to compile #{t.source} into\n    #{t}\n    in #{File.expand_path('.')}");
	end

	# return the approriate compile action to creat an object files from
	# a source file with the specified suffix.
	# nil if not action is available in this toolset. 
	def getCompileActionForSuffix(suff)
		@@doNothingAction_
	end

	def createCompileTask(source,obj,cfg)

		action = getCompileActionForSuffix(File.extname(source).downcase);

		unless action
			log.debug("unrecognized source file type \"#{File.name(source)}\"");
			return(nil);				
		end

		if(Rake::Task.task_defined? obj)
			log.debug("Warning: task already defined for #{obj}")
			return(nil);
		end

		tsk = Rake::FileTask.define_task obj
		tsk.enhance(tsk.sources=[source], &action)
		tsk.config = cfg;
		tsk;				
	end

    def createCompileTasks(files,cfg)                
        # format object files name
	                                 
        mapstr = "#{cfg.OBJPATH()}/%n#{OBJEXT()}";

        objs=FileList[];
        files.each do |source|
            obj = source.pathmap(mapstr);                                                         
            task = createCompileTask(source,obj,cfg);
            objs << obj if task;  # will be the same as task.name
        end
        objs
    end
	
	def initCompileTask(cfg)
		cfg.project.addCleanFiles("#{cfg.OBJPATH()}/*#{OBJEXT()}");
		Rake::Task.define_task :compile => [:includes,
											cfg.OBJPATH(),
											:depends]
	end	

	def initDependsTask(cfg) # :nodoc:		
               
		# create dependencies file by concatenating all .raked files				
		tsk = file "#{cfg.OBJPATH()}/depends.rb" => [ :includes, cfg.OBJPATH() ] do |t|
			cd(cfg.OBJPATH(),:verbose=>false) do					
				File.open('depends.rb','w') do |out|
					out.puts("# puts \"loading #{t.name}\"");
				end
				t.prerequisites.each do |dep|
					next unless (dep.pathmap('%x') == '.raked')
					system "cat \'#{dep}\' >> depends.rb"
				end
			end
		end
		# build and import the consolidated dependencies file
		task :depends => [ "#{cfg.OBJPATH()}/depends.rb" ] do |t|
			load("#{cfg.OBJPATH()}/depends.rb")
		end		
		task :cleandepends do
			depname = "#{cfg.OBJPATH()}/depends.rb";
			deleteFiles("#{cfg.OBJPATH()}/*.raked");

			# if there is no task defined for the 'raked' file the create a dummy
			# that dos nothing so at least it knows how to build it :)
						
			tsk.prerequisites.each do |dep|
				next unless (dep.pathmap('%x') == '.raked')
				next if(Rake::Task::task_defined?(dep))
				file dep # a do nothing task
			end
			
			# same here create a dummy file with nothing in it
			if File.exist? depname
				File.open(depname,'w') do |out|
					out.puts("");
				end
			end
		end
		tsk
	end

	def createLinkTask(objs,cfg)
		log.debug("creating link task");
		false
	end

end

module CppProjectConfig

    def self.included(base)
	    base.addModInit(base,self.instance_method(:initializer));
    end

	APP = :APP;
	DLL = :DLL;
	LIB = :LIB;

    attr_reader :ctools
	attr_reader :cppDefines
	attr_reader :targetType
	attr_reader :thirdPartyLibs

#	attr_reader	:cflags  had this in old one for added VC flags.

 	def initializer(pnt)
		@addedIncludePaths_=[]
		@cppDefines={}
		@incPaths_=nil;
		if(pnt != nil)
			@targetType = pnt.targetType;
			@cppDefines.merge!(pnt.cppDefines);
			@ctools = pnt.ctools;
		end
 	end

	def INCDIR
		@INCDIR||=@parent_?@parent_.INCDIR():"#{BUILDDIR()}/include";
	end
	def BINDIR
		@BINDIR||=@parent_?@parent_.BINDIR():"#{BUILDDIR()}/bin";
	end
	def LIBDIR
		@LIBDIR||=@parent_?@parent_.LIBDIR():"#{BUILDDIR()}/lib";
	end

	def vcprojDir
		@vcprojDir||=@parent_?@parent_.vcprojDir():"#{BUILDDIR()}/vcproj";
	end

	def addIncludePaths(*defs)	
		defs.flatten!()
		defs.each do |ip|
			@addedIncludePaths_ << File.expand_path(ip);
		end	
		@incPaths_=nil
	end	

	def addedIncludePaths
		@addedIncludePaths_
	end

	def cppDefine(*args)
		args.flatten!()
		args.each do |c|
			spl = c.split('=',2);
			# no value is nil, XXX= will have a value of empty string "" 
			@cppDefines[spl[0]] = spl[1];
		end
	end

	def cppUndefine(*args)
		args.flatten!()
		args.each do |c|
			@cppDefines.delete(c)
		end
	end

	def addSourceFiles(*args)
		opts = (Hash === args.last) ? args.pop : {}
		@sourceFiles ||= FileSet.new;
		@sourceFiles.include(args);
	end

	#returns include path "set" with parent's entries after this ones entries
	# followed by the system include paths from the currently configured tools
	def includePaths()
		unless @incPaths_
			s=FileSet.new;
			ips=[];
			pnt=self
			s.add(project.projectDir); # covers for implicit './'
			begin
				pnt.addedIncludePaths.each do |ip|
					ips << ip if s.add?(ip)
				end
				pnt = pnt.parent
			end until !pnt
			if(ctools) 
				ctools.systemIncludePaths.each do |ip|
					ips << ip if s.add?(ip)
				end
			end
			@incPaths_ = ips;
		end
		@incPaths_
	end

	def addThirdPartyLibs(*args)		
        @thirdPartyLibs||=[]
		@thirdPartyLibs << args
	end

end

class CppProject < Rakish::Project
    include CppProjectConfig

	task :autogen 		=> [ :cleandepends, :includes, :vcproj ];
	task :cleanautogen 	=> [ :cleanincludes, :cleandepends, :vcprojclean ];
	task :compile 		=> [ :includes ];
	task :depends		=> [ :includes ];
	task :build 		=> [ :compile ];


	# Create a new project
	#
	# <b>named args:</b>
	#
	#   :name        => name of this project, defaults to parent directory name
	#   :package     => package name for this project defaults to nothing
	#   :config      => explicit parent configuration, defaults to the GlobalConfig
	#   :dependsUpon => array of project directories or specific rakefile paths this project
	#                   depends upon
	#   :id          => uuid to assign to project in "uuid string format"
	#                    '2CD0548E-6945-4b77-83B9-D0993009CD75'
	#
	# &block is always yielded to in the directory of the projects file, and the
	# Rake namespace of the new project, and called in this instance's context


	def initialize(args={},&block)
		super(args,&block);
		addIncludePaths( [ OBJPATH(),INCDIR() ] );
	end


	def resolveConfiguredTasks()

		cfg = @buildConfig
		tools = cfg.ctools;

        objs = tools.createCompileTasks(getSourceFiles(),cfg);

		unless tsk = Rake.application.lookup("#{@myNamespace}:compile")
			tsk = tools.initCompileTask(self)
		end
		tsk.enhance(objs)

 		unless tsk = Rake.application.lookup("#{@OBJDIR}/depends.rb")
            tsk = tools.initDependsTask(self)
 		end

		raked=[]
		objs.each do |obj|
			obj = obj.ext('.raked');
			raked << obj if File.exist?(obj)
		end
		tsk.enhance(raked);

		@objs = objs;
		ensureDirectoryTask(OBJPATH());

		## link tasks
		tsk = tools.createLinkTask(objs,cfg);
		if(tsk)
			ensureDirectoryTask(cfg.LIBDIR);
			ensureDirectoryTask(cfg.BINDIR);
			task :build => [ :compile, cfg.LIBDIR, cfg.BINDIR, tsk ].flatten
		end

	end

	@@vcprojAction_ = lambda do |t|
        require "#{Rakish::MAKEDIR}/VcprojBuilder.rb"
        VcprojBuilder.onVcprojTask(t.config);
	end

	@@vcprojCleanAction_ = lambda do |t|
        require "#{Rakish::MAKEDIR}/VcprojBuilder.rb"
        VcprojBuilder.onVcprojCleanTask(t.config);
	end

	# called after initializers on all projects and before rake
	# starts executing tasks

	def preBuild()
        super;
		cd @projectDir, :verbose=>verbose? do		
            ns = Rake.application.in_namespace(@myNamespace) do
				puts("pre building #{@myNamespace}");
				@buildConfig = resolveConfiguration(CPP_CONFIG());
				resolveConfiguredTasks();
				if(@projectId)
                    ensureDirectoryTask(vcprojDir);
					tsk = task :vcproj=>[vcprojDir], &@@vcprojAction_;
					tsk.config = self;
					export(:vcproj);

                    tsk = task :vcprojclean, &@@vcprojCleanAction_;
					tsk.config = self;
					export(:vcprojclean);
                end
            end # ns
        end # cd
	end

	@@linkIncludeAction_ = lambda do |t|
		config = t.config;
		# if(config.verbose?)
			puts "generating #{t.name} from #{t.source}"
		# end

		destfile = t.name;
		srcpath = config.getRelativePath(t.source,File.dirname(t.name));
		fname = File.basename(t.name);
		File.open(destfile,'w') do |file|
			file.puts("/* #{fname} - generated file - do not alter */");
			file.puts("#include \"#{srcpath}\"");
		end
	end


	# add tasks to ':includes' to place links to or copy source files to
	# the specified 'stub' directory.
	#
	# Also adds removal of output files or links to task ':cleanincludes'
	#
	# <b>named args:</b>
	#   :destdir => destination directory to place output files, defaults to INCDIR/myPackage
	#
	def addPublicIncludes(*args)

		opts = (Hash === args.last) ? args.pop : {}

		files = FileSet.new(args);

		unless(destdir = opts[:destdir])
			destdir = myPackage;
		end
		destdir = File.join(INCDIR(),destdir);
		ensureDirectoryTask(destdir);
		flist = createCopyTasks(destdir,files,:config => self,&@@linkIncludeAction_)
		task :includes => flist
		task :cleanincludes do |t|
			deleteFiles(flist)
		end
	end

	# get all include files for generated projects		
	def getIncludeFiles()
		unless @allIncludeFiles_;
			files = FileSet.new();
			files.include( "#{projectDir}/*.h");
			files.include( "#{projectDir}/*.hpp");
			files.include( "#{projectDir}/*.inl");
			files.include( "#{projectDir}/*.i");
			@allIncludeFiles_ = files;
		end
		@allIncludeFiles_
	end

	def getSourceFiles()
		@sourceFiles||=FileSet.new
	end


	# define a configurator to load a configuration for a specific ( string )
	# configruation

	def setupCppConfig(args={}, &b)
		@targetType = args[:targetType];
		@cppConfigurator_ = b;	
	end

	class TargetConfig < BuildConfig
		include CppProjectConfig

		attr_reader		:configName
		attr_accessor	:targetBaseName
		attr_reader 	:libpaths
		attr_reader 	:libs
		attr_accessor   :targetName

		def initialize(pnt, cfgName, tools)
			super(pnt);
			@libpaths=[]; # ???
			@libs=[];
			@configName = cfgName;
			@ctools = tools;
			@targetBaseName = pnt.moduleName;
			tools.ensureConfigOptions(self);
		end

		def addLibPaths(*lpaths)
			@libpaths << lpaths
		end

		def addLibs(*l)
			l.flatten.each do |lib|
				lib = File.expand_path(lib) if(lib =~ /\.\//); 
				@libs << lib
			end
		end

		def targetName
			@targetName||="#{targetBaseName}-#{configName}";
		end

		def dependencyLibs
			libs=[]
			project.dependencies.each do |dep|
				ldef = ctools.loadLinkref(dep.LIBDIR,configName,dep.moduleName);
				deflibs = ldef[:libs];
				libs += deflibs if deflibs;
			end
			if(thirdPartyLibs)
				thirdPartyLibs.flatten.each do |tpl|
					ldef = ctools.loadLinkref("#{thirdPartyPath}/lib",configName,tpl);
					deflibs = ldef[:libs];
					libs += deflibs if deflibs;
				end
			end
			libs
		end

		def objectFiles
			[]
		end
	end

	# for a specifc named configuraton, resolves the configration and loads it with the
	# the project's specified values.
	 
	def resolveConfiguration(config)
		
		if(ret = (@resolvedConfigs||={})[config]) 
			return ret;
		end

		tools = CTools.loadConfiguredTools(config);
		ret = @resolvedConfigs[config] = TargetConfig.new(self,config,tools);

		if(defined? @cppConfigurator_)
			@cppConfigurator_.call(ret);
		end
		
		ret
	end

end # CppProject

end # Rakish

# global  alias for Rakish::Project.new()
def CppProject(args={},&block)
	Rakish::CppProject.new(args,&block)
end


#################################################

if false

	def acquireBuildId(dir, map=nil)
		outOfSync = false;
		rev = 'test'
		count = 0
	#	dirs.each do |dir|
			pdir = File.expand_path(dir).pathmap(map);
			drev = `svnversion -n \"#{getRelativePath(pdir)}\"`
			if(count == 0)
				rev = drev;
			end
			if(drev =~ /[^0123456789]/)
				outOfSync = true
				msg = 'is out of sync'
				if(drev =~ /M/)
					msg = 'is modified'
				end
				puts("Preparing test build ** \"#{pdir}\" #{msg}") if verbose?
			end
			if(drev != rev)
				outOfSync = true
			end
			rev = drev;
	#	end
		if(outOfSync)
			return('test')
		end
		puts("build ID is \##{rev}")
		return(rev)
	end


public

	# Gets build ID based on subversion revision of BUILD_ROOT
	# returns revision number if local copy is unmodified and
	# represents a coherant revision.  returns 'test' if the
	# local copy is modified.
	#
	# this will cache the result and if no svn updates or commits
	# have been made and the last ID is 'test' will not call svnversion
	# again (which is very slow) but will return 'test'

	def getBuildId
		unless defined? @@buildId_
			idfile = "#{@BUILDDIR}/obj/.rakishBuildId.txt"

			if File.exists? idfile
				File.open(idfile,'r') do |file|
					file.each_line do |l|
						if(l =~ /buildId = "/)
							$' =~ /"/
							@@buildId_ = $`
							break;
						end
					end
				end
				if(@@buildId_ == 'test')
					if(filetime("#{$BUILD_ROOT}/.svn") < filetime(idfile))
						return @@buildId_
					end
				end
			else
				mkdir_p("#{@BUILDDIR}/obj", :verbose=>false)
			end

			@@buildId_ = acquireBuildId($BUILD_ROOT);
			File.open(idfile,'w') do |file|
				file.puts("buildId = \"#{@@buildId_}\"")
			end
		end
		@@buildId_
	end

end # false

