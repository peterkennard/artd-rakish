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
		@projectsByFile={}
		
		task :resolve do |t|
		    if(defined? Rakish::GlobalConfig.instance.CPP_CONFIG)
			    puts "Starting build. for #{Rakish::GlobalConfig.instance.CPP_CONFIG}\""
			else
			#	if(Rakish::GlobalConfig.instance)
			#		Rakish::GlobalConfig.instance.CPP_CONFIG() = "not set";
			#	end
                puts "Starting build.";
            end
			@projects.each do |p|
				p.preBuild
				p.resolveExports
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
		@projectsByFile[p.projectFile]=p;
	end


	def loadProjects(*args)
	# load other project rakefiles from a project into the interpreter unless they have already been loaded
	# selects namespace appropriately

		rakefiles = FileSet.new(args);
		projs=[];
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
					projs << @projectsByFile[path];	
				end
			rescue => e
				cd dir
				log.error("failure loading #{path}"); 
				if(verbose?)
					puts e
					puts e.backtrace.join("\n\t")
				end
				raise e			
			end
		end # namespace
		projs
	end
end

# --------------------------------------------------------------------------
# Rakish module singleton methods.
#
class << self
	# Current Build
	def build
	  @application ||= Rakish::Build.new
	end
end


class Project < BuildConfig
	include Rakish::Util

	# this may need to be changed as rake evolves
	def self.task(*args,&block)
		Rake::Task.define_task(*args, &block)
	end

	# initialize "static" class variables

	@@globalTargets = Set.new;

	[
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
	].each do |gt|
	    @@globalTargets.add(gt);
		task gt;
	end

	def task(*args,&block)
		Rake::Task.define_task(*args, &block)
	end

	# this may need to be changed as rake evolves
	def export(name)

	    if(name.is_a? Rake::Task)
	        # note: doesn't check if task is actually in this namespace
            name = name.to_s().sub("#{myNamespace}:",'').to_sym;
	    end

	    @exported_ ||= Set.new;
        if(@exported_.add?(name))
			namespace(':') do
				task name;
			end
		end
	end

	task :default		=> [ :build ];
	task :rebuild 		=> [ :cleandepends, :depends, :clean, :build ];

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
	# list of projects specified that this is dependent on ( not recursive )
	attr_reader :dependencies

	# output directory common to all configurations
	def OBJDIR
		@OBJDIR||="#{BUILDDIR()}/obj/#{moduleName()}";
	end

	# configuration specific intermediate output directory
	def OBJPATH
		@OBJPATH||="#{OBJDIR()}/#{CPP_CONFIG()}";
	end

	def OUTPUT_SUFFIX
		@OUTPUT_SUFFIX||=CPP_CONFIG();
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
	# &block is always yielded to in the directory of the projects file, and the
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

		fileDependencies = args[:dependsUpon]

		parent = args[:config]
		parent ||= GlobalConfig.instance


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

        # initialize config properties from the parent and initialize included configuration modules.
		super(parent) {}

		cd @projectDir, :verbose=>verbose? do

			# load all subprojects this is dependent on relative to this project's directory
			@dependencies = (fileDependencies ? @build.loadProjects(fileDependencies) : []);

			# register after the others are loaded for proper dependency initialization order
			@build.registerProject(self);

			# call instance initializer block inside local namespace and project's directory.
			# and in the directory the defining file is contained in.
			ns = Rake.application.in_namespace(@myNamespace) do
				@myNamespace = "#{Rake.application.current_scope.join(':')}"
		        initProject(args);
				instance_eval(&block) if block;
			end
		end
	end

    # called before user supplied initializer block is executed
    # in the project's directory and namespace
    def initProject(args)
    end

	# link global tasks to this project's tasks if they are defined and set as exported
	def resolveExports
		targets = @exported_ || Set.new;
		targets.merge(@@globalTargets);

		targets.each do |gt|
			tname = "#{@myNamespace}:#{gt}"
			tsk = Rake.application.lookup(tname);
			# overide invoke_with_call_chain to print the tasks as they are invoked
			if(tsk)
				tsk.instance_eval do
					alias :_o_iwcc_ :invoke_with_call_chain
					def invoke_with_call_chain(task_args, invocation_chain)
						unless @already_invoked
							puts("---- #{name()}") 
							STDOUT.flush # for the visual C command window TODO: don't do for batch jobs?
						end
						_o_iwcc_(task_args, invocation_chain);
					end
				end
				task gt => [ tname ];
			end
		end
	end

	# execute block inside this projects Rake namespace
	def inMyNamespace(&block)
		namespace(":#{@myNamespace}",&block)
	end

	
	# called after initializers on all projects and before rake
	# starts executing tasks
	def preBuild

		cd @projectDir, :verbose=>verbose? do

			tname = "#{@myNamespace}:preBuild"

			ns = Rake.application.in_namespace(@myNamespace) do

				# optional pre build task
				doPreBuild = Rake.application.lookup(tname);
				if(doPreBuild)

					# @myNamespace = "#{Rake.application.current_scope.join(':')}"
					# instance_eval(&block)

				end
			end
		end
	end

	def showScope(here='') # :nodoc:
		puts("#{here}  #{@myNamespace} ns = :#{Rake.application.current_scope.join(':')}");
	end

end

# initialize the build application instance
Rakish.build

end # Rakish

# global  alias for Rakish::Project.new()
def RakishProject(args={},&block)
	Rakish::Project.new(args,&block)
end

