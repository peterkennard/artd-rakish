##### accumulating stuff later to be organized

myPath = File.dirname(File.expand_path(__FILE__));
require "#{myPath}/Rakish.rb"
require "#{myPath}/BuildConfig.rb"

module Rakish

class Build 
	include Rakish::Util
	
	def initialize
		@startTime = Time.new

		@projects=[]
		@projectsByModule={}
		
		task :resolve do |t|
			puts "Staring build. for #{Rakish::GlobalConfig.instance.CONFIG}\""
			@projects.each do |p|
				p.preBuild
			end
		end

		task :_end_ do |t|
			onComplete();
		end

		Rake.application.top_level_tasks.insert(0,:resolve);
		Rake.application.top_level_tasks << :_end_;
	end
	
	def verbose?
		true
	end
	
	def onComplete
		dtime = Time.new.to_f - @startTime.to_f;		
		ztime = (Time.at(0).utc) + dtime;
		puts(ztime.strftime("Build complete in %H:%M:%S:%3N"))	
	end
	
	def registerProject(p)
		pname = p.moduleName;
		if(@projectsByModule[pname]) 
			raise("Error: project \"#{pname}\" already registered") 
		end
		@projects << p;
		@projectsByModule[pname]=p;
	end


	def loadProjects(*args)
	# load other project rakefiles from a project into the interpreter unless they have already been loaded
	# selects namespace appropriately

		rakefiles = FileSet.new(args);
		
			namespace ':' do
			path = ''
			dir = File.expand_path(pwd)
			begin
				rakefiles.each do |path|
				
					projdir = nil;
				
					if(File.directory?(path))
						projdir = path;
						path = File.join(projdir,'rakefile.rb');
					else
						projdir = File.dirname(path);
					end

					cd(projdir,:verbose=>false) do
						if(require(path)) 
						#	puts "project #{path} loaded" if verbose?
						end
					end	
				end
			rescue => e
				cd dir
				puts "failure loading #{path}" 
				if(verbose?)
					puts e
					puts e.backtrace.join("\n\t")
				end
				raise e			
			end
		end
	end
end

# --------------------------------------------------------------------------
# Rakish singleton methods.
#
class << self
	# Current Build
	def build
	  @application ||= Rakish::Build.new
	end
end

class Project < ProjectConfig
	include Rakish::Util

	# initialize "static" class variables 

	@@globalTargets = [
		:default,
		:autogen,
		:cleanautogen,
		:includes,
		:cleanincludes,
		:depends,
		:cleandepends,
		:build,
		:compile,
		:clean,
		:vcproj,
		:vcprojclean
	];

	# this may need to be changed as rake evolves
	def Project.task(*args,&block)
		Rake::Task.define_task(*args, &block)
	end
	
	@@globalTargets.each do |t|
		task t;
	end	

	task :autogen 		=> [ :includes, :vcproj ];
	task :cleanautogen 	=> [ :cleanincludes, :cleandepends, :vcprojclean ];
	task :depends		=> [ :includes ];
	task :build   		=> [ :includes ];
	task :compile 		=> [ :includes ];
	task :default		=> [ :build ];
	
	# returns the Rake task namespace for this project
	attr_reader :myNamespace
	alias 		:moduleName :myNamespace

	# full path of the file containing this project
	attr_reader :projectFile
	# directory containing the file for this project
	attr_reader :projectDir
	# name of this project
	attr_reader :myName
	# package name for this project
	attr_reader :myPackage
	# UUID of this project
	attr_reader :projectId

	# output directory common to all configurations
	def OBJDIR
		@OBJDIR||="#{BUILDDIR()}/obj/#{moduleName()}";
	end
	# configuration specific intermediate output directory
	def OBJPATH
		@OBJPATH||="#{OBJDIR()}/#{CONFIG()}";
	end

	def OUTPUT_SUFFIX
		@OUTPUT_SUFFIX||=CONFIG();
	end
	
	def project
		self
	end
		
	# add file or files to be deleted in the :clean task
	def addCleanFiles(*args)
		unless(@cleanFiles_)
		@cleanFiles_ = FileSet.new(*args);
			task :clean do |t|
				deleteFiles(@cleanFiles_)
			end
		else
			@cleanFiles_.include(*args)
		end
	end
		
		
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
	# &block is always yeilded to in the directory of the projects file, and the 
	# Rake namespace of the new project, and called in this instance's context
		
	def initialize(args={},&block)

		# derive path to file declaring this project - from loaded file that 
		# called this initializer
		
		@build = Rakish.build
		
		myFile = nil	
        regex = Regexp.new(Regexp.escape(File.dirname(__FILE__)));				
		caller.each do |clr|
			unless(clr =~ regex)
				clr =~ /\:\d/
				myFile = $`;
                break;
			end					    		
		end

		# if(clr =~ /:in `<top \(required\)>'$/)
		#		$` =~ /:\d+$/
		#		myFile = File.expand_path($`)
		#		break
		# end

		# load all subprojects this is dependent on
		# unless it is from a vcProject which has already checked dependencies
	
		dependencies = args[:dependsUpon]
		
		parent = args[:config]
		parent ||= GlobalConfig.instance

		super(parent) {}

		@projectFile = myFile
		@projectDir  = File.dirname(myFile)		
		@projectId 	 = args[:id]

		name 	= args[:name];
		name ||= @projectDir.pathmap('%n') # namespace = projName for this Module
		projName = name;
		package = args[:package];
		if(package)
			projName = "#{package}-#{name}";
		end		
		@myNamespace = projName

		@myName 	= name;
		@myPackage 	= package;

		@build.loadProjects(dependencies) if dependencies
		@build.registerProject(self);

		cd @projectDir, :verbose=>verbose? do
			
			addIncludePaths [
				"#{@INCDIR}"
			];
			
			ensureDirectoryTask(OBJDIR());
			ensureDirectoryTask(OBJPATH());
		
			# call instance initializer block inside local namespace.
			# we are in the directory the defining file is contained in.

			ns = Rake.application.in_namespace(@myNamespace) do					
				@myNamespace = "#{Rake.application.current_scope.join(':')}"
				instance_eval(&block)	
			end	
		end		
	end

	# called after initializers on all projects and before rake 
	# starts ececuting tasks
	def preBuild	
		
		cd @projectDir, :verbose=>verbose? do

			puts("pre building #{moduleName}")
			tname = "#{@myNamespace}:preBuild"

			ns = Rake.application.in_namespace(@myNamespace) do					

				if(@projectId) 				
					task :vcproj do |t|
						require "#{Rakish::MAKEDIR}/BuildVcproj.rb"
						onVcprojTask
					end
					task :vcprojclean do |t|
						require "#{Rakish::MAKEDIR}/BuildVcproj.rb"
						onVcprojCleanTask
					end
				end
				
				# optional pre build task 
				doPreBuild = Rake.application.lookup(tname);
				if(doPreBuild)
										
					# @myNamespace = "#{Rake.application.current_scope.join(':')}"
					# instance_eval(&block)	
					
				end
			end
			
			# link global tasks to this project's tasks if defined
			@@globalTargets.each do |gt| 
				tname = "#{@myNamespace}:#{gt}"
				tsk = Rake.application.lookup(tname);
				# overide invoke_with_call_chain to print the tasks as they are invoked
				if(tsk)	
					tsk.instance_eval do
						alias :_o_iwcc_ :invoke_with_call_chain
						def invoke_with_call_chain(task_args, invocation_chain)
							puts("---- #{name()}") unless @already_invoked
							_o_iwcc_(task_args, invocation_chain);
						end
					end
					task gt => [ tname ];
				end	 		
			end
		end	
	end

	def showScope(here='') # :nodoc:
		puts("#{here}  #{@myNamespace} ns = :#{Rake.application.current_scope.join(':')}");
	end
	
protected  #### compile target configuration
		
public
		
	def compileConfig(&b)
		yield self
	end
	
	def addSourceFiles(*args)
		
		opts = (Hash === args.last) ? args.pop : {}
		
		@sourceFiles ||= FileSet.new;
		@sourceFiles.include(args);
		
		files = FileSet.new(args);

		# @srcdirs ||= FileSet.new

		cfg = self
		
        objs = tools.createCompileTasks(files,cfg);
		
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
		
		@objs ||= [];
		@objs += objs;
		return(objs)
	end
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

	# execute block inside this projects Rake namespace
	def inMyNamespace(&block) 
		namespace(":#{@myNamespace}",&block)
	end	
	
public

	def loadProjects(*args)
		@build.loadProjects(*args)
	end
	
	@@linkPublicInclude_ = lambda do |t|
		config = t.config;
		if(config.verbose?) 
			puts "generating #{t.name} from #{t.source}"
		end
		
		destfile = t.name;
		srcpath = config.getRelativePath(t.source,File.dirname(t.name));
		fname = File.basename(t.name);
		File.open(destfile,'w') do |file|
			file.puts("/* #{fname} - generated file - do not alter */");
			file.puts("#include \"#{srcpath}\"");
		end
	end
	
	# add tasks to place links to or copy source files to
	# specified directory and adds tasks to target ':includes'
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
		destdir = File.join(@INCDIR,destdir);
	
		flist = createCopyTasks(destdir,files,:config => self,&@@linkPublicInclude_)
		task :includes => flist
		task :cleanincludes do |t| 
			deleteFiles(flist)
		end
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

# initialize the build instance
Rakish.build

end # Rakish

# global  alias for Rakish::Project.new()
def RakishProject(args={},&block)
	Rakish::Project.new(args,&block)
end

# global  alias for Rakish::Project.new()
def LibraryProject(args={},&block)
	Rakish::Project.new(args,&block)
end

# global  alias for Rakish::Project.new()
def ParentProject(args={},&block)
	puts("##### Parent Project !!!");
	Rakish::Project.new(args,&block)
	puts("##### end Parent Project !!!");
end
