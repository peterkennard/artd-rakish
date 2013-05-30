myPath = File.dirname(File.expand_path(__FILE__));
require "#{myPath}/RakishProject.rb"

module Rakish


class InvalidConfigError < Exception
	def initialize(cfg, msg)
		super("Invalid Configuration \"#{cfg}\": #{msg}.");
	end
end


module CTools

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

	@@doNothingAction_ = lambda do |t|
		puts("attempting to compile #{t.source}");
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
			puts("unrecognized source file type \"#{File.name(source)}\"");
			return(nil);				
		end

		if(Rake::Task.task_defined? obj)
			puts("Warning: task already defined for #{obj}")
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

	def initDependsTask(project)
		puts("init depends");
	end

end

module CppProjectConfig

    def self.included(base)
	    base.addModInit(base,self.instance_method(:initializer));
    end

    attr_reader :ctools
	attr_reader :cppDefines

 	def initializer(pnt)
		@cppIPaths_=[]
		@cppDefines={}
		if(pnt != nil)
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
			@cppIPaths_ << File.expand_path(ip);
		end	
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
end

class CppProject < Rakish::Project
    include CppProjectConfig

	task :autogen 		=> [ :includes, :vcproj ];
	task :compile 		=> [ :includes ];
	task :depends		=> [ :includes ];


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


	def setupCppConfig(&b)
		@configurator_ = b;	
	end

	def initialize(args={},&block)
        super(args,&block);
		loaded = LoadableModule.load("#{MAKEDIR}/WindowsCppTools.rb");
    end


	def resolveCompileTasks()

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

		if(tsk) 
			raked=[]
			objs.each do |obj|
				obj = obj.ext('.raked');
				raked << obj if File.exist?(obj)
			end
			tsk.enhance(raked);
		end

		@objs ||= [];
		@objs += objs;
		return(objs)
	end

	# called after initializers on all projects and before rake
	# starts executing tasks
	def preBuild()
        super;

		@buildConfig = resolveConfiguration(CPP_CONFIG());
		resolveCompileTasks();

		cd @projectDir, :verbose=>verbose? do		
            ns = Rake.application.in_namespace(@myNamespace) do
				puts("pre building #{@myNamespace}");
				if(@projectId)
                    ensureDirectoryTask(vcprojDir);
					tsk = task :vcproj=>[vcprojDir] do |t|
                        require "#{Rakish::MAKEDIR}/VcprojBuilder.rb"
                        VcprojBuilder.onVcprojTask(self);
                    end
					
					tsk.config = self;
                    tsk = task :vcprojclean do |t|
                        require "#{Rakish::MAKEDIR}/VcprojBuilder.rb"
                        VcprojBuilder.onVcprojCleanTask(self);
                    end
					tsk.config = self;
					export(:vcproj);
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

	class ResolvedConfig < BuildConfig
		include CppProjectConfig

		attr_reader :configName

		def initialize(pnt, cfgName, tools)
			super(pnt);
			@configName = cfgName;
			@ctools = tools;
			tools.ensureConfigOptions(self);
		end
	end

	# for a specifc named configuraton, resolves the configration and loads it with the
	# the project's specified values.
	 
	def resolveConfiguration(config)
		
		if(ret = (@resolvedConfigs||={})[config]) 
			return ret;
		end

		tools = CTools.loadConfiguredTools(config);
		ret = @resolvedConfigs[config] = ResolvedConfig.new(self,config,tools);

		if(defined? @configurator_)
			@configurator_.call(ret);
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

class XCppProject < Project
	include Rakish::Util

	# initialize "static" class variables

	task :autogen 		=> [ :includes, :vcproj ];
	task :cleanautogen 	=> [ :cleanincludes, :cleandepends, :vcprojclean ];
	task :depends		=> [ :includes ];
	task :build   		=> [ :includes ];
	task :compile 		=> [ :includes ];
	task :default		=> [ :build ];


    def initializeProject(args)
        addIncludePaths [
            "#{@INCDIR}"
        ];
        ensureDirectoryTask(OBJDIR());
        ensureDirectoryTask(OBJPATH());
    end


protected  #### compile target configuration

public

private
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


protected

############## link configurations

	class LinkConfig # nodoc: all
		include LinkTargetMod

		attr_accessor :baseName
		attr_reader	  :isLibrary
		attr_accessor :SHARED_LIBRARY

		def initialize(cfg,lib,&b)
			@isLibrary = lib;
			init_LinkTarget(cfg)
		end
		alias :superResolve :resolve
		def resolve
			superResolve
		end
	end

public

	def libraryConfig(&b)

		config = LinkConfig.new(self,true,&b);
		config.baseName = moduleName();
		config.addObjs(@objs);
		yield config;
		targ = tools.createLibraryTarget(config);
		tsk = task "#{config.baseName}.lib.resolve" do |t|
			config.resolve
		end
		ensureDirectoryTask(LIBDIR());
        task :build => [ :compile, config.LIBDIR(), tsk, targ ];
		task :clean do
			addCleanFiles(targ.name);
		end
	end

	def exeConfig(&b)

		config = LinkConfig.new(self,false,&b);
		config.baseName = moduleName();
		config.addObjs(@objs);
		yield config;
		tsk = task "#{config.baseName}.exe.resolve" do |t|
			config.resolve
		end
		targ = tools.createExeTarget(config);
        task :build => [ :compile, tsk, targ ];
		addCleanFiles(targ.name);
	end
end
end # false 

