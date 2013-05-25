myPath = File.dirname(File.expand_path(__FILE__));
require "#{myPath}/RakishProject.rb"

module Rakish

class CTools

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
end

class VisualCTools < CTools

	def linkIncludeAction()
		@@linkIncludeAction_
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
		else
			@ctools = VisualCTools.new();
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

end

class CppProject < Rakish::Project
    include CppProjectConfig

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
		flist = createCopyTasks(destdir,files,:config => self,&ctools.linkIncludeAction())
		task :includes => flist
		task :cleanincludes do |t|
			deleteFiles(flist)
		end
	end

	# called after initializers on all projects and before rake
	# starts executing tasks
	def preBuild()
        super;
        puts("pre building #{@myNamespace}");
		if(@projectId)
			cd @projectDir, :verbose=>verbose? do
                ns = Rake.application.in_namespace(@myNamespace) do
                    task :vcproj do |t|
                        require "#{Rakish::MAKEDIR}/VcprojBuilder.rb"
                        # onVcprojTask
                    end
                    task :vcprojclean do |t|
                        require "#{Rakish::MAKEDIR}/VcprojBuilder.rb"
                        # onVcprojCleanTask
                    end
				export(:vcproj);
				export(:vcprojclean);
                end
            end
        end
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

