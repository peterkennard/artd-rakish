myPath = File.dirname(File.expand_path(__FILE__));
require "#{myPath}/Rakish.rb"
require "#{myPath}/BuildConfig.rb"

module Rakish

# Mostly internal singleton for Rakish.Project[link:./Rakish.html#method-c-Project] and
# Rakish.Configuration[link:./Rakish.html#method-c-Configuration] loading and management
class Build
	include Rakish::Util
	
	def initialize # :nodoc:
		@startTime = Time.new

		@projects=[]
		@projectsByModule={}
		@projectsByFile={}  # each entry is an array of one or more projects
		@configurationsByName={}
        @registrationIndex_ = 0;

		task :resolve do |t|
		  if(defined? Rakish::GlobalConfig.instance.nativeConfigName)
			  log.info "Starting build. for #{Rakish::GlobalConfig.instance.nativeConfigName}\""
			else
			#	if(Rakish::GlobalConfig.instance)
			#		Rakish::GlobalConfig.instance.nativeConfigName() = "not set";
			#	end
				log.info "Starting build.";
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
	
	def verbose? # :nodoc:
		true
	end
	
	# Called when the rake invocation of this Rakish::Build is complete.
	# Prints a log.info message of the time taken to execute this invocation of 'rake'.
	def onComplete 
		dtime = Time.new.to_f - @startTime.to_f;		
		ztime = (Time.at(0).utc) + dtime;
		puts(ztime.strftime("Build complete in %H:%M:%S:%3N"))
		0
	end
	
	def registerProject(p) # :nodoc: internal used by projects to register themselves wheninitialized
    pname = p.projectName;
    if(@projectsByModule[pname])
      raise("Error: project \"#{pname}\" already registered")
    end
    @projects << p;
    @projectsByModule[pname]=p;
    (@projectsByFile[p.projectFile]||=[]).push(p);
    @registrationIndex_ = @registrationIndex_ + 1;
	end

	def registerConfiguration(c) # :nodoc: internal used by configurations to register themselves when initialized
		if(@configurationsByName[c.name])
			raise("Error: configuration \"#{c.name}\" already registered");
		end
		@configurationsByName[c.name]=c;
  end

  # Retrieve an initialized Rakish.Configuration[link:./Rakish.html#method-c-Configuration] by name.
  # If name is nil retrieves the 'root' configuration
  def configurationByName(name)
    @configurationsByName[name||'root']
  end

	# Retrieve a Rakish.Project[link:./Rakish.html#method-c-Project] by the project name, nil if not found.
	def projectByName(name)
		@projectsByModule[name];
	end

	# load other project rakefiles from a project into the interpreter unless they have already been loaded
	# selects namespace appropriately
	# returns array of all projects referenced directly by this load

  def loadProjects(*args) # :nodoc: knternal called by RakishProject to load dependencies.

    opts = (Hash === args.last) ? args.pop : {}
    rakefiles = FileSet.new(args);
    projs=[];
    FileUtils.cd File.expand_path(pwd) do;
    namespace ':' do
      lastpath = '';
      begin
        rakefiles.each do |path|
          lastpath = path;
          projdir = nil;

          if(File.directory?(path))
            projdir = path;
            path = File.join(projdir,'rakefile.rb');
          else
            projdir = File.dirname(path);
          end

          unless(opts[:optional] && (!File.exist?(path)))
            FileUtils.cd(projdir) do
              if(require(path))
                #	puts "project #{path} loaded" if verbose?
              end
            end
            projs |= @projectsByFile[path];
          end
        end
      rescue LoadError => e
        log.error("#{e}");
        raise e;
      end
    end # namespace
    end # cd
    projs
  end
end

# --------------------------------------------------------------------------
# Rakish module singleton methods added for Rakish::Project handling.
#


class << self
	# Retrieve the process' singleton instance of the root Rakish::Build for this rake invocation.
	def build
	  @application ||= Rakish::Build.new
	end

	# Retrieve a Rakish::Project by the project name.
	# calls Rakish::build.projectByName(name)
	def projectByName(name)
		@application.projectByName(name)
	end
end

# Base class for all Rakish.[Projects]
# Create subclasses of this using Rakish.Project
class ProjectBase < BuildConfig
	include Rakish::Util

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

protected
	
    # Create a task that will execute all it's actions in the directory and namespace of the
	# creating project
    # it will only set the project scope ONCE upon the first call
	def taskInScope(*args,&block)
	    Rake::Task.define_task(*args, &block).setProjectScope(self);
	end

  # Create a FileTask which will execute all actions in the directory and namespace of this project
  # it will only set the project scope ONCE upon the first call
  def fileInDir(*args, &block)
    Rake::FileTask.define_task(*args, &block).setProjectScope(self);
  end

  # Called before user supplied initializer block is executed
  # in the project's directory and namespace
  def initProject(args) #
  end

public

	# When called from within a project, exports a namespace internal task to
	# a global task by the same name as the task within the projects namespace.
	# Not safe if called on a task outside the project's namespace
	# returns the task that is exported if the input argument is a task.
	# example:
	#    exportedTask = export task :aTask => [ :prerequisite ] do |t|
	#        log.debug("invoking #{t.name}");
	#    end
	def export(name, &b)

		exported = name;
    if(name.is_a? Rake::Task)
      if(block_given?)
        # this to cover for ruby argument parsing and precidence
        # so you don't have to add parentheses around the task declaraton
        # as in: export (task => [prereq] do |t| { blah blah });
        name.actions << b;
      end
      name.config||=self;
      name = name.to_s().sub("#{myNamespace}:",'').to_sym;
    else
      # TODO: look up actual task and set exported to it for return value.
      name = name.to_sym;
      exported = nil
    end

    if(exported.is_a? Rake::FileTask)
      log.warn("attempt to export FileTask #{name.name}");
      return exported;
    end

    @exported_ ||= Set.new;
    if(@exported_.add?(name))
      namespace(':') do
        task name;
      end
    end
    return(exported);
	end

	task :default		=> [ :build ];
	task :rebuild 		=> [ :cleandepends, :depends, :clean, :build ];

	attr_reader :registrationIndex

	# returns the Rake task namespace for this project
	attr_reader :myNamespace
	alias 		:projectName :myNamespace

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

    # Get project's object and intermediate directory
	def projectObjDir
		@projectObjDir||="#{getAnyAbove(:projectObjDir)}/#{projectName()}";
	end

	# Get project's configuration specific intermetdiate object directory
	def configuredObjDir
		@configuredObjDir||="#{projectObjDir()}/#{nativeConfigName()}";
	end

	# Get project's configuration specific directory for (current) output configuration
	def configurationDir
		@configurationDir||="#{projectObjDir()}/#{nativeConfigName()}.config";
	end

	# return self for inheriting PropertyBag configurations
	def project
		self
	end

	# list of projects specified that this is dependent on ( not recursive - only direct dependencies )
	attr_reader :dependencies

protected
    def _depsRecursive(level, depset)
      unless(depset[projectName]) # just in case recursion protection
        depset[projectName] = self if(level > 0)
        if(@dependencies)
          level=level+1;
          @dependencies.each do |dep|
            dep._depsRecursive(level,depset);
          end
        end
      end
      depset
    end

public

	# Get a list of all projects that this project is dependent on.
	# sorted bfrom least dependent (with fewest prerequisites) to most.
    def allDependencies
      vals = _depsRecursive(0,{}).values;
      vals.sort_by! { |dep| dep.registrationIndex }
      vals
    end
  end

#    def addProjectDependencies(*args) # :nodoc:  not used anywhere at present
#    	# NOTE: for some unknown reason when this is called from initialize exception handling is
#    	# somehow screwed up so we don't call it from there.
#		begin
#			projs = @build.loadProjects(*args);
#			if(@dependencies)
#				@dependencies = @dependencies + (projs - @dependencies);
#			else
#				@dependencies = projs;
#			end
#		rescue LoadError=>e
#			log.error("dependency not found in #{myFile}: #{e}");
#			raise e
#		end
#    end

	# Add file or files to be deleted in the :clean task
	# used by task builder modules included in a project
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

	# Add a directory to be removed upon ":clean"
	# used by task builder modules included in a project
	def addCleanDir(name)
        name = File.expand_path(name);
        task :clean do |t|
			rm_rf(name);
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
	#   :dependsOptionallyUpon => array of project directories or specific rakefile paths this project
	#                            depends upon that are ignored if not present.
	#   :id          => uuid to assign to project in "uuid string format"
	#                    '2CD0548E-6945-4b77-83B9-D0993009CD75'
	#
	# &block is always yielded to in the directory of the projects file, and the
	# Rake namespace of the new project (project scope), and called in the project instance's context

	def initialize(args={},&block) # :nodoc:

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

    fileDependencies = args[:dependsUpon] || Array.new;
    optionalFileDependencies = args[:dependsOptionallyUpon];

    parent = @build.configurationByName(args[:config]);

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

    cd @projectDir, :verbose=>verbose? do

      # load all project files this is dependent on relative to this project's directory
      begin
        @dependencies = @build.loadProjects(*fileDependencies);
      rescue LoadError => e
        log.error("requred dependency not found in #{myFile}: #{e}");
        raise e
      end

      if(optionalFileDependencies)
        projs = @build.loadProjects(*optionalFileDependencies, :optional=>TRUE);
        @dependencies = @dependencies + (projs - @dependencies);
      end

      @dependencies.sort_by!  { |dep| dep.registrationIndex }

      # call instance initializer block inside local namespace and project's directory.
      # and in the directory the defining file is contained in.
      ns = Rake.application.in_namespace(@myNamespace) do

        # initialize properties from the parent configuration and initialize included modules.
        super(parent,args) {}

        if(RUBY_VERSION =~ /^2./)
          @myNamespace = Rake.application.current_scope.path;
        else
          @myNamespace = "#{Rake.application.current_scope.join(':')}"
        end

        initProject(args);
        instance_eval(&block) if block;

      end

      # register this project after the initialization has loaded all
      # the other dependencies for proper dependency initialization order
      @registrationIndex = @build.registerProject(self);
    end
	end

	# link global tasks to this project's tasks if they are defined and set as exported
	def resolveExports # :nodoc:
		targets = @exported_ || Set.new;
		targets.merge(@@globalTargets);

		targets.each do |gt|
			tname = "rake:#{@myNamespace}:#{gt}"
			tsk = Rake.application.lookup(tname);
			# overide invoke_with_call_chain to print the exportend tasks as they are invoked
			if(tsk)
				tsk.instance_eval do
					alias :_o_iwcc_ :invoke_with_call_chain
					def invoke_with_call_chain(task_args, invocation_chain)  # :nodoc:
						unless @already_invoked
							log.info("---- #{name()}")
						end
						_o_iwcc_(task_args, invocation_chain);
					end
				end
				task gt => [ tname ];
			end
		end
	end

	# execute block inside this projects Rake namespace
	# for use in tasks 
	def inMyNamespace(&block)
		namespace(":#{@myNamespace}",&block)
	end

	
	# called after initializers on all projects and before rake
	# starts executing tasks
	def preBuild # :nodoc:
    cd @projectDir, :verbose=>verbose? do
      tname = "#{@myNamespace}:configure"
      ns = Rake.application.in_namespace(@myNamespace) do
        # log.info("configuring #{@myNamespace}");
        # optional project configuration task
        doConfigure = Rake.application.lookup(tname);
        doConfigure.invoke if(doConfigure)
      end
    end
	end

	# show projects scope for debugging purposes.
	def showScope(here='') # :nodoc:
		log.info("#{here}  #{@myNamespace} ns = :#{currentNamespace}");
	end

end

@@projectClassesByIncluded_ = {}; # :nodoc:

protected

# Dynamically create a new anonymous class < Rakish::ProjectBase or get one from
# the cache withthe same base class and included module set if there is one.
#
# Maybe its senseless optimization but I wanted a freer dynamic project
# declaration system without having to explicitly create new classes with
# explicit names everywhere. I did learn something about Ruby however :)
# the "opts" can be the same ones that would be used as args{} for
# Rakish::ProjectBase.new and Rakish.Project[link:./Rakish.html#method-c-Project]
#
#   named opts:
#     :extends  => Base class of the newly created class defaults to ProjectBase
#     :includes => If provided, ProjectModules and other modules to "include" in this class.

def self.getProjectClass(opts={})

  # get the base project type to extend the class from
  # and get list of explicit modules to include
  # eliminate duplicate modules, and sort the list.

  extends = opts[:extends]||ProjectBase;

  # if no explicit inclusions just return the class
  return(extends) unless(included=opts[:includes]);

  included.flatten!
  if included.length > 1
    # TODO: maybe get a list of all included modules and generate a hash
    # TODO: but this likely not needed or won't make things faster
    # TODO: not sure how ruby's string keys for hashes work.
    included = Set.new(included).to_a();
    included.sort! do |a,b|
      a.to_s <=> b.to_s
    end
  end
  key=[extends,included] # key is explicit definition of class

  # if we already have created a class for the specific included set use it
  unless projClass = @@projectClassesByIncluded_[key]
    # otherwise create a new class and include the requested modules
    # log.debug("new class including [#{included.join(',')}]");
    projClass = Class.new(extends) do
      included.each do |i|
        include i;
      end
    end
    @@projectClassesByIncluded_[key] = projClass;
  end
  projClass;
end

public

# Declare and create a new empty Project that subclasses Rakish::ProjectBase
#
#  named args:
#
#   :name        => name of this project, defaults to parent directory name
#   :package     => package name for this project defaults to nothing
#   :config      => explicit parent configuration name, defaults to 'root'
#   :dependsUpon => array of project directories or specific rakefile paths this project
#                   depends upon
#   :id          => uuid to assign to project in "uuid string format"
#                    '2CD0548E-6945-4b77-83B9-D0993009CD75'
#   :includes    => If provided, ProjectModules and other modules to "include" in this project.
#
# &b is always yielded to in the directory of the project's file, and the
# Rake namespace of the new project (project scope), and called in the project instance's context

def self.Project(args={},&b)
  baseIncludes = args[:baseIncludes];
  if(baseIncludes)
    includes=[baseIncludes]
    if(args[:includes])
      includes << opts[:includes]
    end
    args[:includes]=includes
  end
  getProjectClass(args).new(args,&b)
end

# initialize the build application instance
Rakish.build

end # Rakish

