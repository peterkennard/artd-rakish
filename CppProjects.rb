


class CppProject < Project
	include Rakish::Util

	# initialize "static" class variables

	task :autogen 		=> [ :includes, :vcproj ];
	task :cleanautogen 	=> [ :cleanincludes, :cleandepends, :vcprojclean ];
	task :depends		=> [ :includes ];
	task :build   		=> [ :includes ];
	task :compile 		=> [ :includes ];
	task :default		=> [ :build ];

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
        super.initialize(args,block);
    end

    def initializeProject(args)
        addIncludePaths [
            "#{@INCDIR}"
        ];
        ensureDirectoryTask(OBJDIR());
        ensureDirectoryTask(OBJPATH());
    end

	# called after initializers on all projects and before rake
	# starts executing tasks
	def preBuild()
        if(@projectId)
            cd @projectDir, :verbose=>verbose? do
                ns = Rake.application.in_namespace(@myNamespace) do
                    task :vcproj do |t|
                        require "#{Rakish::MAKEDIR}/BuildVcproj.rb"
                        onVcprojTask
                    end
                    task :vcprojclean do |t|
                        require "#{Rakish::MAKEDIR}/BuildVcproj.rb"
                        onVcprojCleanTask
                    end
                end
            end
        end
        super.preBuild()
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



# global  alias for Rakish::Project.new()
def CppProject(args={},&block)
	Rakish::CppProject.new(args,&block)
end
