myPath = File.dirname(File.expand_path(__FILE__));
require "#{myPath}/RakishProject.rb"

include Rake::DSL

module Rakish

    # :nodoc: legacy only looked at in the
	MAKEDIR = File.dirname(File.expand_path(__FILE__)); # :nodoc:

	# C++ build module
    # Not really part of public distributioin - too littered with local stuff
    # specific to my main builds  This needs to be converted to work in a more configurable way
    # for multiple platforms
module CTools
	include Rakish::Logger
	include Rakish::Util

	# parses and validates an unknown string configuration name 
	# of the format [TargetPlatform]-[Compiler]-(items specific to compiler type)
	# and loads if possible an instance of a set of configured "CTools" 
	# for the specified "nativeConfigName" configuration.

	def self.loadToolchain(moduleName,configName,args={})
        begin
            require moduleName;
            moduleName = moduleName.pathmap('%n');
            mod = Rakish.const_get(moduleName.to_s);
            mod.getConfiguredTools(configName,args);
        rescue
            log.debug("unrecognized toolchain module \"#{moduleName}\"");
        end
	end

	def writeLinkref(cfg,baseName,targetName)
					
		defpath = "#{cfg.nativeLibDir}/#{baseName}-#{cfg.nativeConfigName}.linkref"
		reltarget = getRelativePath(targetName,cfg.nativeLibDir);
		File.open(defpath,'w') do |f|
			f.puts("libs = [\'#{reltarget}\']")
		end
	end

	# real bodge for now need to clean this up somehow.
	def loadLinkref(libdir,config,cfgName,baseName)
		cd libdir, :verbose=>false do
			libdef = File.expand_path("#{baseName}-#{cfgName}.linkref");
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
				log.debug("#{config.projectFile},failed to load #{libdef} #{e}");
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

		if(!File.exists?(outName) || textFilesDiffer(outName,tempfile))
            # @#$#@$#@ messed up. set time of new file ahead by one second.
            # seems rake time resolution is low enough that the comparison often says 
            # times are equal between depends files and depends.rb.
            FileUtils.mv(tempfile, outName, :force=>true);
            time = Time.at(Time.new.to_f + 1.0);
            File.utime(time,time,outName);
            task.config.dependencyFilesUpdated = true;
		else
			FileUtils.rm(tempfile, :force=>true);
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
			log.debug("unrecognized source file type \"#{source.pathmap('%f')}\"");
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
	                                 
        mapstr = "#{cfg.moduleConfiguredObjDir()}/%n#{objExt()}";

        objs=FileList[];
        files.each do |source|
            obj = source.pathmap(mapstr);                                                         
            task = createCompileTask(source,obj,cfg);
            objs << obj if task;  # will be the same as task.name
        end
        objs
    end
	
	def initCompileTask(cfg)
		cfg.project.addCleanFiles("#{cfg.moduleConfiguredObjDir()}/*#{objExt()}");
		Rake::Task.define_task :compile => [:includes,
											cfg.moduleConfiguredObjDir(),
											:depends]
	end	

 	def initDependsTask(cfg) # :nodoc:
               
		# create dependencies file by concatenating all .raked files				
		tsk = file "#{cfg.moduleConfiguredObjDir()}/depends.rb" => [ :includes, cfg.moduleConfiguredObjDir() ] do |t|
			cd(cfg.moduleConfiguredObjDir(),:verbose=>false) do
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
		task :depends => [ "#{cfg.moduleConfiguredObjDir()}/depends.rb" ] do |t|
			load("#{cfg.moduleConfiguredObjDir()}/depends.rb")
		end		
		task :cleandepends do
			depname = "#{cfg.moduleConfiguredObjDir()}/depends.rb";
			deleteFiles("#{cfg.moduleConfiguredObjDir()}/*.raked");

			# if there is no task defined for the 'raked' file then create a dummy
			# that dos nothing so the prerequisites resolve - this is the case where the
			# actual dependencies are built by compiling.
						
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

    attr_reader :ctools
	attr_reader :cppDefines
	attr_reader :targetType
	attr_reader :thirdPartyLibs

	def cpp
	    self
	end

#	attr_reader	:cflags  had this in old one for added VC flags.

 	addInitBlock do |pnt,opts|
		@addedIncludePaths_=[]
		@cppDefines={}
		@incPaths_=nil;

		if(pnt != nil)
			@targetType = pnt.targetType;
			@cppDefines.merge!(pnt.cppDefines);
			@ctools = pnt.ctools;
		end
 	end

   # set toolchain for a cpp configuration
   # if ther is only one non hash argument and it is a module the module is used as a pre-loaded toolchain
   # otherwise the first argument is considered a module name of the tools module to load
   # the second argument is the configuration name assigned to it, and subsequent hash argument are the 
   # initialization arguments for creating the toolchain instance.
   #
    def setToolchain(ctools,*args)
        if(ctools.is_a?(CTools)) 
		@ctools = ctools;
	else	
		configName = args[0];
		hash = args.last;		
		hash = {} unless hash.is_a?(Hash)
		@ctools = CTools.loadToolchain(ctools,configName,hash);
	end
    end

    # temporary include directory built for compiling
    # where generated include files or links to the project sources
    # are created
	def INCDIR
		@INCDIR||=getAnyAbove(:INCDIR)||"#{buildDir()}/include";
	end

	def binDir
		@binDir||=(getAnyAbove(:binDir)||"#{buildDir()}/bin/#{nativeConfigName}");
	end

	def nativeLibDir
		@nativeLibDir||=getAnyAbove(:nativeLibDir)||"#{buildDir()}/lib";
	end

	def vcprojDir
		@vcprojDir||=getAnyAbove(:vcprojDir)||"#{buildDir()}/vcproj";
	end

    # add include paths in order to the current list of include paths.
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

    # define or re-define a preprocessor value
	def cppDefine(*args)
		args.flatten!()
		args.each do |c|
			spl = c.split('=',2);
			# no value is nil, XXX= will have a value of empty string "" 
			@cppDefines[spl[0]] = spl[1];
		end
	end

    # test if name is defined or not.
	def cppDefined(name)
	    @cppDefines.has_key?(name);
	end

    # only define the value if it is not already defined
	def cppDefineIfNot(*args)
		args.flatten!()
		args.each do |c|
			spl = c.split('=',2);
			# no value is nil, XXX= will have a value of empty string ""
	        @cppDefines[spl[0]] = spl[1] unless @cppDefines.has_key?(spl[0]);
		end
	end

    # undefine the values in the arguments
	def cppUndefine(*args)
		args.flatten!()
		args.each do |c|
			@cppDefines.delete(c)
		end
	end

	def addSourceFiles(*args)
		opts = (Hash === args.last) ? args.pop : {}
		@cppSourceFiles ||= FileSet.new;
		@cppSourceFiles.include(args);
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


module CppProjectModule
    include CppProjectConfig

    addInitBlock do
        t = task :preBuild do
            doCppPreBuild
        end
        @cppCompileTaskInitialized = false;
    end

	VCProjBuildAction_ = lambda do |t|
        require "#{Rakish::MAKEDIR}/VcprojBuilder.rb"
        VcprojBuilder.onVcprojTask(t.config);
	end

	VCProjCleanAction_ = lambda do |t|
        require "#{Rakish::MAKEDIR}/VcprojBuilder.rb"
        VcprojBuilder.onVcprojCleanTask(t.config);
	end

	LinkIncludeAction_ = lambda do |t|
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

	def outputsNativeLibrary
		true
	end
	
	# called after initializers on all projects and before rake
	# starts executing tasks

	def doCppPreBuild()
        addIncludePaths( [ moduleConfiguredObjDir(),buildIncludeDir() ] );
        @cppBuildConfig = resolveConfiguration(nativeConfigName());
        resolveConfiguredTasks();
        if(@projectId)
            ensureDirectoryTask(vcprojDir);
            tsk = task :vcproj=>[vcprojDir], &VCProjBuildAction_;
            tsk.config = self;
            export(:vcproj);

            tsk = task :vcprojclean, &VCProjCleanAction_;
            tsk.config = self;
            export(:vcprojclean);
        end
	end

    def self.doUpdateDepends(t)
        cfg = t.config;
        if(cfg.dependencyFilesUpdated)
            tools = cfg.ctools
            objs = t.sources;
            cd(cfg.moduleConfiguredObjDir(),:verbose=>false) do
                File.open('depends.rb','w') do |out|
                    out.puts("# puts \"loading #{t.name}\"");
                end
                objs.each do |obj|
                    raked = obj.pathmap('%n.raked');
                    if(File.exists?(raked))
                        system "cat \'#{raked}\' >> depends.rb"
                    end
                end
           end
        end
    end

	UpdateDependsAction_ = lambda do |t|
        doUpdateDepends(t);
    end

	def resolveConfiguredTasks()

		cfg = @cppBuildConfig
		tools = cfg.ctools;

        objs = tools.createCompileTasks(getSourceFiles(),cfg);

		unless compileTsk = Rake.application.lookup("#{@myNamespace}:compile") && @cppCompileTaskInitialized
			cppCompileTaskInitialized = true;
			compileTsk = tools.initCompileTask(self);
		end
		compileTsk.enhance(objs)


		updateDepTsk = Rake::Task.define_unique_task &UpdateDependsAction_;
		updateDepTsk.config = cfg;
		updateDepTsk.sources = objs;
		compileTsk.enhance(updateDepTsk);

		unless tsk = Rake.application.lookup("#{@moduleObjDir}/depends.rb")
            tsk = tools.initDependsTask(self)
 		end

		raked=[]
		objs.each do |obj|
			obj = obj.ext('.raked');
			raked << obj if File.exist?(obj)
		end
		tsk.enhance(raked);

		@objs = objs;
		ensureDirectoryTask(moduleConfiguredObjDir());

		## link tasks
		tsk = tools.createLinkTask(objs,@cppBuildConfig);
		if(tsk)
			outdir = tsk[:linkTask].name.pathmap('%d');
			ensureDirectoryTask(outdir);
			ensureDirectoryTask(cfg.binDir);
			task :build => [ :compile, outdir, cfg.binDir, tsk[:setupTasks], tsk[:linkTask] ].flatten

		end

	end

	# add tasks to ':includes' to place links to or copy source files to
	# the specified 'stub' directory.
	#
	# Also adds removal of output files or links to task ':cleanincludes'
	#
	# <b>named args:</b>
	#   :destdir => destination directory to place output files, defaults to buildIncludeDir/myPackage
	#
	def addPublicIncludes(*args)

		opts = (Hash === args.last) ? args.pop : {}

		files = FileSet.new(args);

		unless(destdir = opts[:destdir])
			destdir = myPackage;
		end
		destdir = File.join(buildIncludeDir(),destdir || '');
		ensureDirectoryTask(destdir);
		flist = createCopyTasks(destdir,files,:config => self,&LinkIncludeAction_)
		task :includes => flist
		task :cleanincludes do |t|
			deleteFiles(flist)
		end
	end


    # asd a project local include directory so files will be listed
    def addLocalIncludeDir(idir)
        @cppLocalIncludeDirs_ ||= [];
        @cppLocalIncludeDirs_ << idir;
    end

	# get all include files for generated projects
	def getIncludeFiles()
		unless @allIncludeFiles_;
			files = FileSet.new();
            (@cppLocalIncludeDirs_||=['.']).each do |dir|
                dir = "#{projectDir}/#{dir}";
                files.include( "#{dir}/*.h");
                files.include( "#{dir}/*.hpp");
                files.include( "#{dir}/*.inl");
                files.include( "#{dir}/*.i");
			@cppAllIncludeFiles_ = files;
			end
		end
		@cppAllIncludeFiles_
	end

	def getSourceFiles()
		@cppSourceFiles||=FileSet.new
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
		attr_accessor   :dependencyFilesUpdated

		def initialize(pnt, cfgName, tools)
			super(pnt);
			@libpaths=[]; # ???
			@libs=[];
			@configName = cfgName;
			@ctools = tools;
			@targetBaseName = pnt.moduleName;
			# @manifestFile = pnt.manifestFile;
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
			@targetName||="#{targetBaseName}";
		end

		def dependencyLibs

			libs=[]
			project.dependencies.each do |dep|
				if(defined? dep.outputsNativeLibrary)
					if(dep.nativeLibDir)
						ldef = ctools.loadLinkref(dep.nativeLibDir,self,configName,dep.moduleName);
						if(ldef != nil)
							deflibs = ldef[:libs];
							libs += deflibs if deflibs;
						end
                    end
				end
			end

			if(thirdPartyLibs)
				thirdPartyLibs.flatten.each do |tpl|
					libpath = NIL;
					if(File.path_is_absolute?(tpl))
					    libpath = tpl.pathmap('%d');
					    tpl = tpl.pathmap('%f');
					else
					    puts("adding lib #{tpl}");
					    libpath = "#{thirdPartyPath}/lib";
					end
					
					ldef = ctools.loadLinkref(libpath,self,configName,tpl);
                    if(ldef != nil)
                        deflibs = ldef[:libs];
                        libs += deflibs if deflibs;
					end
				end
			end
			libs
		end

		def objectFiles
			[]
		end

        def setManifest(file)
            @manifestFile = File.expand_path(file);
        end
        def manifestFile
            @manifestFile
        end

	end

	# for a specifc named configuraton, resolves the configration and loads it with the
	# the project's specified values.

	def resolveConfiguration(config)

		if(ret = (@resolvedConfigs||={})[config])
			return ret;
		end
        tools = ctools;
		ret = @resolvedConfigs[config] = TargetConfig.new(self,config,tools);

		if(defined? @cppConfigurator_)
			@cppConfigurator_.call(ret);
		end
		ret
	end

end

class BuildConfig
   # ensure added global project task dependencies
    task :clean
    task :autogen 		=> [ :cleandepends, :includes, :vcproj ];
    task :cleanautogen 	=> [ :cleanincludes, :cleandepends, :vcprojclean ];
    task :cleanAll      => [ :clean, :cleanautogen ];
    task :compile 		=> [ :includes ];
    task :depends		=> [ :includes ];
    task :build 		=> [ :compile ];
    task :rebuild 		=> [ :build, :autogen, :compile ];
end

# Create a new project
#
# <b>named args:</b>
#
#   :name        => name of this project, defaults to parent directory name
#   :package     => package name for this project defaults to nothing
#   :config      => explicit parent configuration, defaults to 'root'
#   :dependsUpon => array of project directories or specific rakefile paths this project
#                   depends upon
#   :id          => uuid to assign to project in "uuid string format"
#                    '2CD0548E-6945-4b77-83B9-D0993009CD75'
#
# &block is always yielded to in the directory of the projects file, and the
# Rake namespace of the new project, and called in this instance's context

CppProject = getProjectClass( :includes=>[CppProjectModule] )

end # Rakish


#################################################

if false

	def acquireBuildId(dir, map=nil) # :nodoc:
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

	def getBuildId # :nodoc:
		unless defined? @@buildId_
			idfile = "#{@buildDir}/obj/.rakishBuildId.txt"

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
				mkdir_p("#{@buildDir}/obj", :verbose=>false)
			end

			@@buildId_ = acquireBuildId($BUILD_ROOT);
			File.open(idfile,'w') do |file|
				file.puts("buildId = \"#{@@buildId_}\"")
			end
		end
		@@buildId_
	end
end # false

