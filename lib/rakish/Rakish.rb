# Rakish module utilities
#
# $Id $

# this is becoming a "gem" we wat to require files with "rakish/FileName"

gemPath = File.expand_path("#{File.dirname(File.expand_path(__FILE__))}/..");
$LOAD_PATH.unshift(gemPath) unless $LOAD_PATH.include?(gemPath)

require 'open3.rb'

module Kernel # :nodoc:

#--
if false

  if defined?(rakish_original_require) then
	# Ruby ships with a custom_require, override its require
	remove_method :require
  else
	# The Kernel#require from before RubyGems was loaded.
	alias rakish_original_require require
	private :rakish_original_require
  end

  @@_rakish_={}

  def require path
	  # $: is search path list
	  # $" is array of loaded files?

	  if rakish_original_require path
		puts("************ requiring #{path}");
		puts("                loaded #{$".last}");
		true
	  else
		false
	  end
  end
  private :require
end # end false

end # Kernel
#++

require 'set'
require 'logger'


#-- stupid thing needed because rake doesn't check for "" arguments so we make an explicit task
#++
task "" do
end

# Module containg the package Rakish
# includes the module ::Rakish::Logger
#
# :include:doc/RakishOverview.html
#
# For more information see UserGuide[link:./doc/UserGuide.html]
#
module Rakish

    # set to true if called from windows - cygwin
    HostIsCygwin_ = (RUBY_PLATFORM =~ /(cygwin)/i) != nil;
    # set to true if called on a windows host
    HostIsWindows_ = (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil;
    # set to true if called on a unix host
    HostIsUnix_ = (!HostIsWindows_);
    # set to true on a MacOS or iOS host
    HostIsMac_ = (/darwin/ =~ RUBY_PLATFORM) != nil;


	# Logger module
	# To use this Logger initialization include it in a class or module
	# enables log.debug { "message" } etc 
	# from methods or initializations in that class 
	# Other than for INFO level output
	# output messages are formatted to include the file and line number where 
	# log.[level] was invoked.

    # add a search path to the ruby search path for this process unless it is already there
    def self.addToRubySearchPath(dir)
        toAdd =  File.expand_path(dir);
        $LOAD_PATH.unshift(toAdd) unless $LOAD_PATH.include?(toAdd);
    end

	module Logger

		@@_logger_ = ::Logger.new(STDOUT);

		# Returns the singleton instance of ::Logger managed by the Rakish::Logger
		def self.log
			@@_logger_
		end
		@@_logger_.formatter = proc do |severity, datetime, progname, msg|

			fileLine = "";
			unless('INFO' === severity)
				caller.each do |clr|
					unless(/\/logger.rb:/ =~ clr)
						fileLine = clr;
						break;
					end
				end
				fileLine = fileLine.split(':in `',2)[0];
				fileLine.sub!(/:(\d)/, '(\1');
				fileLine += ') : ';
			end

			if(msg.is_a? Exception)
				"#{fileLine}#{msg}\n    #{formatBacktraceLine(msg.backtrace[0])}\n"
			else
				"#{fileLine}#{msg}\n"
			end
		end
		
		# Format a single backtrace line as defined for the IDE we are using.
		def self.formatBacktraceLine(line)
			sp = line.split(':in `',2);
			sp0 = sp[0].sub(/:(\d)/, '(\1');
			sp1 = sp.length > 1 ? "in `#{sp[1]}" : "";
			"#{sp0}) : #{sp1}";
		end

		# Format all lines in a backtrace using formatBacktraceLine() into a 
        # single printable string with entries separated by "\\n"
		def self.formatBacktrace(backtrace)
			out=[];
			backtrace.each do |line|
				out << formatBacktraceLine(line);
			end
			out.join("\n");
		end
		
		# Defines the method "log" in any including 
		# module or class at the class "static" level
		def self.included(by)  # :nodoc: 
			by.class.send(:define_method, :log) do
				::Rakish.log
			end
		end
		
		# Returns the singleton instance of ::Logger managed by the Rakish::Logger
		def log
			STDOUT.flush;
			::Rakish.log
		end
	end

	def self.log # :nodoc:
		Rakish::Logger.log
	end

	# Execute shell command in sub process and pipe output to Logger at info level
	# cmdline - single string command line, or array of command and arguments
	#  opts:
	#     :verbose - if set to true (testable value is true) will print command when executing
	#     :env - optional environment hash for spawned process
	#
	#  returns status return from spawned process.
	#  uses Open3:popen2()

	def self.execLogged(cmdline, opts={})
		begin
			if(cmdline.respond_to?(:to_ary))
				log.info("\"#{cmdline.join("\" \"")}\"") if opts[:verbose]
				# it is the array form of command
				unless (Hash === cmdline[0]) # to handle ruby style environment argument - env is cmdline[0]
					cmdline.unshift(opts[:env]) if opts[:env];
				end
			else
				# TODO: handle parsing command line into array of arguments if opts[:env]
				log.info("#{cmdline}") if opts[:verbose]
			end

			# this will redirect both stdout and stderr to the "output" pipe
			# TODO: handle throwing exception if the process aborts with an error return code
			exit_status = nil;
			Open3.popen2(*cmdline, :err => [:child, :out]) do |i,output,t|
				while line = output.gets do
					log.info line.strip!
				end
				exit_status = t.value; # Process::Status object returned.
			end
 			return(exit_status);
#			IO.popen(cmdline) do |output|
#				while line = output.gets do
#					log.info line.strip!
#				end
#			end
#			return $?
		rescue => e
			if(opts[:verbose])
				if(cmdline.respond_to?(:to_ary))
					cmdline.shift if opts[:env];
					cmdline = "\"#{cmdline.join("\" \"")}\"";
				end
				log.error("failure executing: #{cmdline}");
			end
			log.error(e);
			raise(e);
		end
	end

    # convenience method like Rake::task
    def self.task(*args,&block)
        ::Rake::Task.define_task(*args, &block)
    end

end


# Rake extensions
module Rake

	module DSL  # :nodoc: so if a version doesn't have it it works
	end

	class << self
	    # get a new generated unique name for "anonymous" classes
	    # and tasks and other uses
		def get_unique_name
			@_s_||=0
			@_s_ += 1
			:"_nona_#{@_s_}"
		end
	end

    # Rake::TaskManager extensions
	module TaskManager

        # Two difference here:
        # flattening of dependency lists
        # so arguments can be arrays of arrays
        # and it will recognize a leading ':' as an indicator of global root namespace scope
        # in additon to "rake:"
        def resolve_args(args)
            if args.last.is_a?(Hash)
                deps = args.pop
                ret = resolve_args_with_dependencies(args, deps)
                ret[2].flatten!
                ret[2].map! do |e|
                    (e=~/^:/)?"rake#{e}":e
                end
                ret
            else
                resolve_args_without_dependencies(args)
            end
        end

        alias_method :old_define_task, :define_task

        # thie will parse additional "reat time" arguments passed into a task in the form of additional
        # hash entries to the primary "named argument list" non of these keys may be arrays.
        # or be the same ast the task name
        def define_task(task_class, *args, &block)

            createArgs = nil;
            last = args.last;
            if(last.is_a?(Hash))
                if(last == args[0]) # only a hash
                    if(last.size > 1)
                        name = last.keys[0];
                        # replace hash from args with only the name and dependencies
                        # delete the first key and remainder goes into createArgs
                        args[0] = { name => last.delete(name) }
                        createArgs = last;
                    end
                else # name and a hash
                    unless last.empty?
                        name = last.keys[0];
                        if(name.is_a? Array)
                            # replace hash from args with only the arrayKey and command line argument list
                            # delete the first key, remainder goes into createArgs if not empty
                            args[1] = { name => last.delete(name) }
                            createArgs = last unless last.empty?;
                        else
                            args.pop # it is our added arguments
                            createArgs = last;
                        end
                    end
                end
            end
            tsk = old_define_task(task_class, *args, &block);
            tsk.createArgs = createArgs if createArgs
            tsk
        end


	end

    # Rake::Application extensions
	class Application

		# Display the error message that caused the exception.
		# formatted the way we like it for a particualar IDE

		def display_error_message(ex)

		  $stdout.flush;
		  $stderr.flush;

		  $stderr.puts "#{name} aborted!: #{ex.message}"
		  backtrace = ex.backtrace;

		  if options.trace
			$stderr.puts Rakish::Logger.formatBacktrace(backtrace)
    		  else

    		lineNum = 0;
    		useLine = 0;

            if(ex.message =~ /wrong number of arguments/)
                useLine = 1;
            end

    		backtrace.each do |line|
                lineNum = lineNum + 1;
			    sp = line.split(':in `',2);
                if(sp.length > 1)
    		        if(sp[1] =~ /const_missing'$/)
    		            useLine = lineNum;
                        break;
    		        end
    		    end
    		end

			$stderr.puts(Rakish::Logger.formatBacktraceLine(backtrace[useLine]));
			$stderr.puts(rakefile_location(backtrace)); # this seems to be broken !!
          end

		  $stderr.puts "Tasks: #{ex.chain}" if has_chain?(ex)
		  $stderr.puts "(See full trace by running task with --trace)" unless options.trace
		end
	end
	
	class Task
	  include Rakish::Logger
	  
	  rake_extension('config') do
		# note commented because Rdoc does not parse this 
		# attr_accessor :config
	  end
	  # optional "config" field on Rake Task objects
	  attr_accessor :config
	  
	  rake_extension('createArgs') do
	  end
      def createArgs
        @createArgs||={};
      end
      def createArgs=(aHash)
        @createArgs||=aHash # can only assign once !!!
      end

	  # see Rake.Task as this overrides it's method
	  # to flatten dependencies so they can be provided as
	  # nested arrays or arguments
	  def enhance(*args,&b)
		# instead of |=
		if(args)
		    args.flatten!
            args.map! do |e|
                (e=~/^:/)?"rake#{e}":e
            end
		    @prerequisites = @prerequisites.concat(args);
		end
		@actions << b if block_given?
		self
	  end
	  
	  def scopeExec(args=nil) # :nodoc:
		@application.in_namespace_scope(@scope) do
			FileUtils.cd @_p_.projectDir do
				_baseExec_(args);
			end
		end
	  end
	  private :scopeExec

	  rake_extension('setProjectScope') do
		def setProjectScope(d) # :nodoc:
			return self if(@_p_)
			instance_eval do
				alias :_baseExec_ :execute
				alias :execute :scopeExec
			end
			@_p_=d;
			self
		end
	  end

	  class << self

        def usesCreatArgs
            false
        end

		# define a task with a unique anonymous name
		# does not handle :name=>[] dependencies because the generated name is
		# not known at the time of this declaratation
		def define_unique_task(*args,&b)
			args.unshift(Rake.get_unique_name)
			Rake.application.define_task(self,*args,&b);
		end
	  end
	end
	
	# Extension to force all file tasks to reference the full path for the file name.
	# We want to make sure all File tasks are named after the full path
	# so there is only one present for any given file.
	class FileTask
		class << self
		    # Apply the scope to the task name according to the rules for this kind
		    # of task.  File based tasks ignore the scope when creating the name.
			def scope_name(scope, task_name)
				File.expand_path(task_name)
			end
		end
	end

	module TaskManager

		if(RUBY_VERSION =~ /^2./)
			def _trc  # :nodoc:
				puts("** namespace \":#{@scope.path}\"");
			end
		else # ruby 1.9.X
			def _trc # :nodoc:
				puts("** namespace \":#{@scope.join(':')}\"");
			end
		end
		private :_trc

		# Directory tasks are always in root list so this should be a bit faster
		rake_extension('directory_task_defined?') do
			# Return true if a directory creation task for the diven path is defined.
			def directory_task_defined?(path)
				@tasks.has_key?(path)
			end
		end

		rake_extension('in_namespace_scope') do
		    # Allows for explicitly setting an "absolute" namespace
			# Executes the block in the provided scope.
			def in_namespace_scope(scope)
				prior = @scope;
				@scope = scope;
				if options.trace
					_trc
				end
				ns = NameSpace.new(self,scope);
				yield(ns)
				ns
			ensure
				@scope = prior;
				if options.trace
					_trc
				end
			end
		end

		if(RUBY_VERSION =~ /^2./)
			# this allows for explicitly setting an "absolute" namespace from string
			rake_extension('in_namespace_path') do
				def in_namespace_path(name,&b)

					# handle new scope which is a linked list instead of an array
					prior=@scope
					if(name.instance_of?(String))
						spl = name.split(':');
						newScope = @scope;
						if(spl.size() == 0 || spl[0].length == 0) # absolute, begins with ':'
							spl.shift();
							# Rakish.log.debug("prior scope is \"#{name}\" => \"#{prior.path}\"");
							newScope = Scope.make;
						# else # relative
						    # TODO: handle '..:..: for back a level ???
						end
						spl.each do |elem|
							newScope = Scope.new(elem,newScope);
						end
						@scope = newScope;
						# Rakish.log.debug("new scope is \"#{@scope.path}\"");
					elsif(name) # untested
						Rakish.log.debug("prior scope is \"#{prior.path}\"");
						@scope=Scope.new(name,@scope);
						Rakish.log.debug("new scope is \"#{@scope.path}\"");
					else # untested
						Rakish.log.debug("prior scope is \"#{prior.path}\"");
						@scope=Scope.make; # explicit to root
						Rakish.log.debug("new scope is \"#{@scope.path}\"");
					end
					if options.trace
						_trc
					end
					ns = NameSpace.new(self,@scope);
					yield(ns)
					ns
				ensure
					@scope=prior;
					if options.trace
						_trc
					end
				end
			end

		else # Ruby 1.9.X
			# this allows for explicitly setting an "absolute" namespace from string
			rake_extension('in_namespace_path') do
				def in_namespace_path(name,&b)
					prior=@scope
					if(name.instance_of?(String))
						spl = name.split(':');
						if(spl.size() == 0 || spl[0].length == 0) # absolute
							spl.shift();
							@scope = spl;
						else # relative
							@scope = Array.new(prior).concat(spl);
						end
					elsif(name)
						@scope=Array.new(prior).push(name);
					else
						@scope=Array.new
					end
					if options.trace
						_trc
					end
					ns = NameSpace.new(self,@scope);
					yield(ns)
					ns
				ensure
					@scope=prior;
					if options.trace
						_trc
					end
				end
			end
		end # ruby 1.9.X
	end
end

module Rakish

    # extension to Ruby ::File class
    class ::File

        unless defined? ::File.path_is_absolute?

            if(HostIsWindows_)
                # Return true if path is an absolute path
                def self.path_is_absolute?(path)
                    f0 = path[0]
                    f0 == '/' or f0 == '\\' or path[1] == ':'
                end
            else
                # Return true if file is an absolute path
                def self.path_is_absolute?(path)
                    path[0] == '/'
                end
            end
        end
    end

	# Extensons to root level Module
	
	class ::Module
		
		# Static method used like ruby's attr_accessor declaration
		# for use in declaring added properties on a class
		# inheriting from a Rakish::PropertyBag or including a Rakish::PropertyBagMod

		def attr_property(*args)
			if(self.include? ::Rakish::PropertyBagMod)
				args.each do |s|
					# add "property" assignment operator method s= to this class
					# equivalent of: def s=(v) { @_h[s]=v }
					# where s is the input symbol, it is formatted as a string and passed
					# to eval
					eval("self.send(:define_method,:#{s}=){|v|@_h[:#{s}]=v}")
				end
			else
				raise("can only add properties to PropertyBag object")
			end
		end

		# Allows for the declaration and initialization of 
		# "Constructor" chains in the way C++ or Java operates where base classes (here mixin modules)
		# can be optionally "automagically" invoked in inclusion order on class instance initialization.
		# Any Class and Module may now take advantage of this. see ::Class.initializeIncluded
		#   
		#    Module HasConstructor
		#       addInitBlock do |args|
		#           @myVariable_ = "initialized in constructor of HasContructor"
        #           log.debug("initializing HasConstructor - on #{self} XX #{arg[0]}");
		#       end
		#    end
		#
		#    class MyObject
		#        include HasConstructor
		#
		#        initialize(*args)
		#           # Of course all modules included on this object and by their recursively
		#           # included modules must respond properly to args so likely best to use
		#           # named hash args and a naming convention for what included modules
		#           # use as opposed to an array of positional arguments
		#           self.class.initializeIncluded(self,args);
		#        end
		#    end
		
		def addInitBlock(&b)
			(@_init_||=[])<<b if block_given?
		end

		def _initBlocks_ # :nodoc:
			@_init_;
		end

	end

	class ::Class

		# Monkey Hack to enable constructor inheritance like C++ on mixin modules
		# and call the "initBlocks" of all modules included in this class in the included order
		# installed by included modules which are nicely provided by the ruby ancestors list
		# To do this use this in a Class instance initializer, the arguments will be passed to all superclass mixin init blocks:
		#
		#    obj.class.initializeIncluded(obj,*args);
		#
		# see ::Module and ::Module.addInitBlock() for example.

		def initializeIncluded(obj,*args)
			# call the included modules init blocks with arguments
			self.ancestors.reverse_each do |mod|
				inits = mod._initBlocks_;
				if inits
					inits.each do |b|
						obj.instance_exec(args,&b);
					end
				end
			end
		end
	end

    # Container for searchable path set for finding files in
    class SearchPath

        # Initialize a new SearchPath calls setPath(*paths)
        def initialize(*paths)
            setPath(*paths);
        end

		if( HostIsWindows_ )
            @@osDelimiter_=';';
        else
            @@osDelimiter_=':';
        end

        # Clear and set path set and call adPath(*paths)
        #
        # If no paths are provided then this path set is left empty.
        def setPath(*paths)
            @path_=[];
            addPath(*paths);
        end

		# So we can pass this into SearchPath.new or SearchPath.addPath
		def to_ary # :nodoc:
		   	@path_
		end

		# Iterate over all paths in this SearchPath
        def each(&b)
            @path_.each(&b)
        end

        # Add a path or path list to this search path
        # If a path entry begins with a '.' is will be left in the search path
        # as a relative path, otherwise it will be expanded to an absolute path when added.
        #
        #  Named opts:
        #    :delimiter => path entry delimiter
        #
        def addPath(*paths)
			opts = (Hash === paths.last) ? paths.pop : {}
            delimiter = opts[:delimiter] ||@@osDelimiter_;
            paths.flatten!
            paths.each do |path|
                pa = path.split(delimiter);
                pa.each do |p|
                    p=File.absolute_path(p) unless p[0]=='.'
                    @path_ << p;
                end
            end
            @path_.uniq!
        end

        # like array.join() to build path strings
        def join(s)
            @path_.join(s);
        end

    private
        def onNotFound(name,opts) # :nodoc:
            msg = "could not find file #{name}\n     from: #{File.expand_path('.')}\n     in:\n       #{join("\n      ")}"
            case opts[:onMissing]
            when 'log.error'
                ::Rakish.log.error msg;
            when 'log.warn'
                ::Rakish.log.warn msg;
            when 'log.debug'
                ::Rakish.log.debug msg;
            when 'log.info'
                ::Rakish.log.debug msg;
            else
                raise Exception.new(msg);
            end
        end
    public

        # Find a file with the given name (or relative subpath) in this search set
        # If the input name is an absolute path it is simply returned.
        #  named ops:
        #    :suffi => If set search for file with suffix in order of suffi list
        #              '' is a valid suffix in this case. suffi must have leading dot
        #              as in '.exe'
        #    :onMissing => reporting action to perform when file is not found
        #              'log.error','log.warn',log.debug','log.info',
        #              any other true (or non false/nil) value raises an exception
        #              I prefer 'raise'
        #

        def findFile(name,opts={})
            if(File.path_is_absolute?(name))
                onNotFound(name,opts) if(opts[:onMissing] && (!File.exists?(name)))
                return(name);
            end
            found = nil;
            suffi = opts[:suffi];
            @path_.each do |path|
                path = "#{path}/#{name}";
                unless suffi
                    if(File.exists?(path))
                        found=File.absolute_path(path);
                        break;
                    end
                else
                    suffi.each do |suff|
                        fpath="#{path}.exe";
                        if(File.exists?(fpath))
                            found=File.absolute_path(fpath);
                            break;
                        end
                    end
                    break if(found)
                end
            end
            onNotFound(name,opts) if(!found && opts[:onMissing]);
            found;
        end
        
        def findFiles(*files) 
            opts = (Hash === files.last) ? files.pop : {}
            files.flatten!
            ret=[];
            files.each do |file|
                ret << findFile(file,opts);
            end
            ret;
        end
    end

    # Intended to clean up things to minimize thread usage and queue up these so as to
    # keep avaiable processor cores saturated but without thread thrashing. Spawning lots of threads
    # does not help in the process spawning case and actually slows things down.
    class MultiProcessTask < Rake::Task
	private
		def invoke_prerequisites(args, invocation_chain)
			threads = @prerequisites.collect { |p|
				Thread.new(p) { |r| application[r].invoke_with_call_chain(args, invocation_chain) }
			}
			threads.each { |t| t.join }
		end
	end

    public

    # Create task that finds an existing set of files with wildcards and
    # checks timestamps on the files.
    # currently it is never "out of date" as it doesn't have a target
    # the file set is evaluated and resolved when the timestamp is checked.
    # so if the directory or files are created or updated by a prior prerequisite
    # this will supply the up to date timestamp.
    #
    # it uses additional hash arguments beyond the rake dependencies assigned to the name
    # so you can't use these symbols for the name itself.
    #
    # :basedir => string, the directory to search for the
    #    the default is '.'
    # :files => a single string or an array of the files to find relative to the :basedir
    #    the default is '*'
    # example:
    #
    # fileset_task :nameOfTask => [prerequisites], :files=>['*.sh','*.py'], :basedir=>'scripts';
    #
    class FileSetTask < Rake::Task

        # Is this image build needed?  Yes if it doesn't exist, or if its time stamp
        # is out of date.
        def needed?
            ret = out_of_date? Time.now
            # log.debug("#{name} needed #{ret}");
            ret
        end

        # Time stamp for task.
        def timestamp
            resolveFiles
            unless @timestamp
                ts = Rake::EARLY;
                @fileset.each do |f|
                    ft = File.mtime(f);
                    ts = ft if(ft > ts)
                end
                @timestamp = ts;
            end
            # log.debug("#{name} @timestamp #{@timestamp}");
            @timestamp
        end

        private

        def resolveFiles
            unless @fileset
                basedir = createArgs[:baseDir]||'.';
                files = createArgs[:files]||'*';
                FileUtils.cd basedir do
                    @fileset = FileSet.new(files);
                end
            end
        end

        # Are there any prerequisites with a later time than the given time stamp?
        def out_of_date?(stamp)
            @prerequisites.any? do |n|
                application[n, @scope].timestamp >stamp;
            end
        end
    end

    class << self
        # convenience method like Rake::task for fileset_task
        def fileset_task(*args,&block)
            tsk = FileSetTask.define_task(*args, &block);
        end
    end
	# a bunch of utility functions used by Projects and configurations
	module Util
		include ::Rake::DSL
		include Rakish::Logger

		# Very simple module for Git used to initialize my projects
		module Git # :nodoc:

			class << self
				def clone(src,dest,opts={})
					if(!File.directory?(dest))

						origin = opts[:remote] || "origin";

						puts("Git.clone -o \"#{origin}\" -n \"#{src}\" \"#{dest}\"");

						system("git clone -o \"#{origin}\" -n \"#{src}\" \"#{dest}\"");
						cd dest do
							system("git config -f ./.git/config --replace-all core.autocrlf true");
							system("git reset -q --hard");
						end
					end
				end

				def addRemote(dir, name, uri)
					cd dir do
						system("git remote add \"#{name}\" \"#{uri}\"");
					end
				end
			end
		end

        # convenience method like Rake::task
        def task(*args,&block)
            Rake::Task.define_task(*args, &block)
        end

        # convenience method like Rake::task
        def fileset_task(*args,&block)
            Rakish::FileSetTask.define_task(*args, &block)
        end

		# Like each but checks for null and if object doesn't respond to each
		#
		#  use like
		#    eachof [1,2,3] do |v|
		#    end
		#  
		def eachof(v,&b)
			v.each &b rescue yield v if v # TODO: should use a narrower exception type ?
		end

	protected
		# Task action to simply copy source to destination
		SimpleCopyAction_ = ->(t) { FileUtils.cp(t.source, t.name) }

		# Task action to do nothing.
		DoNothingAction_ = ->(t) {}


	public

		# Execute shell command and pipe output to Logger
		def execLogged(cmd, opts={})
			Rakish.execLogged(cmd,opts)
		end

		# Get current namespace as a string.
		def currentNamespace
			":#{Rake.application.current_scope.join(':')}";
		end

		# Used like Rake's 'namespace' to execute the block 
		# in the specified namespace, except it enables
		# explicit specification of absolute namespace paths
		#  ie: 
		#  ':' selects the root namespace
		#  ':levelOne:levelTwo' is an absolute specification to ':'
		#
		def namespace(name=nil,&block)
			Rake.application.in_namespace_path(name, &block)
		end

		# Get time stamp of file or directory
		def filetime(name)
			File.exists?(name) ? File.mtime(name.to_s) : Rake::EARLY
		end

        # Are there any tasks in the iterable 'tasks' list with an earlier 'time' than the given time stamp?
        def any_task_earlier?(tasks,time)
            tasks.any? { |n| n.timestamp < time }
        end

		# Get simple task action block (lambda) to copy from t.source to t.name
		#   do |t|
		#      cp t.source, t.name 
		#   end	
		def simpleCopyAction()
			SimpleCopyAction_
		end

		def deleteFileArray(files,opts={})	# :nodoc:
			noglob = opts[:noglob]

			files.each do |f|
				if(f.respond_to?(:to_ary))
					deleteFileArray(f,opts)
					next
				end
				f = f.to_s
				unless noglob
					if(f =~ /[*?]/)
						deleteFileArray(FileList.new(f),opts)
						next
					end
				end
				rm f,opts
			end
		end
		
		# delete list of files (a single file or no files) similar to system("rm [list of files]")
		# accepts Strings, FileList(s) and FileSet(s) and arrays of them
		#
		#  named options: all [true|false]:
		#
		#    :force   => default true
		#    :noop    => just print (if verbose) don't do anything
		#    :verbose => print "rm ..." for each file
		#    :noglob  => do not interpret '*' or '?' as wildcard chars
		#
		#
		def deleteFiles(*files)
			opts = (Hash === files.last) ? files.pop : {}			
			opts[:force]||=true # default to true
			opts[:verbose]||=false # default to false
			deleteFileArray(files,opts)
		end	
		alias :deleteFile :deleteFiles

		def getCallingLocation(count = 0)
			myLoc = nil
			count += 1;
			if(RUBY_VERSION =~ /^1\.9\.\d/)
				caller.each do |clr|
					if(count <= 0)
						myLoc = clr;
						break;
					end
					count = count - 1;
					if(clr =~ /:in `<top \(required\)>'$/)
						myLoc = $`;
						break;
					end
				end
			end
			return(myLoc);
		end
	
		# ensures a task is present to create directory dir
		def ensureDirectoryTask(dir)
			unless(dir) 
				loc = getCallingLocation();
				log.debug("warning: #{loc} ensuring NIL directory");
			else
				unless Rake.application.directory_task_defined?(dir)
					Rake.each_dir_parent(dir) do |d|
						file_create d do |t|
							FileUtils.mkdir_p t.name if ! File.exist?(t.name)
						end
					end
				end
			end
			dir
		end
	
		def copyRule(destdir, srcdir, suffix) # :nodoc:

		# puts(" copy rule #{srcdir} #{destdir} #{suffix}" );

			if(srcdir =~ /\/\z/)
				srcdir = $`
			end

			if(destdir =~ /\/\z/)
				# too bad rake doesn't check both, but string based
				ensureDirectoryTask(destdir)
				destdir = $`
			end
			ensureDirectoryTask(destdir)

			#  puts("creating rule for #{srcdir} -> #{destdir}");

			regex = 
				Regexp.new('^' + Regexp.escape(destdir) + '\/[^\/]+' + suffix + '\z', true);

			Rake::Task::create_rule( regex => [
				proc { |task_name| 
					task_name =~ /\/[^\/]+\z/
					task_name = srcdir + $& 
				}
			  ])  do |t|
				cp(t.source, t.name);
			end
		end
		
		# This will "pre-process" input lines using the ruby escape sequence
		# '#{}' for substitutions
		#
		#  in the binding
		#     linePrefix is an optional prefix to prepend to each line.
		#
		#     setIndent means set a variable "indent" in the environment
		#     to be the indent level of the current raw line
		#
		#   lines = input lines (has to implement each_line)
		#   fout  = output file (has to implement puts, print)
		#   bnd   = "binding" to context to evaluate substitutions in
		def rubyLinePP(lines,fout,bnd,opts={})

			setIndent = eval('defined? indent',bnd)
			linePrefix = opts[:linePrefix];

			rawLine = nil;
			lineNum = 0;
			begin
				lines.each_line do |line|
					++lineNum;
					rawLine = line;
					fout.print(linePrefix) if linePrefix;
					fout.puts line.gsub(/\#\{[^\#]+\}/) { |m|
						eval("indent=#{$`.length}",bnd) if setIndent;
						eval('"'+m+'"',bnd)
					}
				end
			rescue => e
				log.error do 
					bt=[]
					e.backtrace.each do |bline|
						bt << Logger.formatBacktraceLine(bline);
						break if bline =~ /(.*)rubyLinePP/;
					end
					"error processing line #{lineNum}: #{e}\n\"#{rawLine.chomp}\"\n#{bt.join("\n")}"
				end
			end
		end

		# This will "preprocess" an entire file using the ruby escape sequence 
		# '#{}' for substitutions 
		#
		#   ffrom = input file path
		#   fto   = output file path
		#   bnd   = "binding" to context to evaluate substitutions in
		def rubyPP(ffrom,fto,bnd)

			begin
				File.open(fto,'w') do |file|
					File.open(ffrom,'r') do |fin|
						rubyLinePP(fin,file,bnd)
					end
				end
			rescue => e
				log.error("error precessing: #{ffrom} #{e}")
				raise e
			end
		end

		# Get relative path between path and relto
		# returns absolute path of path if the roots 
		# are different.
		def getRelativePath(path,relto=nil)

			relto ||= pwd
			relto = File.expand_path(relto)
			path = File.expand_path(path.to_s)
            if(path.start_with?("#{relto}/"))
                reltolen = relto.length+1; 
                path = path.slice(reltolen, path.length - reltolen);
		        return("./#{path}")
			end 

			# puts("###  #{path} relto #{relto}") 

			rtspl = relto.split('/')
			pspl = path.split('/')
			pspsz = pspl.size
			
			cmpi = 0
			rtspl.each_index do |i|
				if(i < pspsz)
					next if rtspl[i] == pspl[i]
				end
				cmpi = i;
				break;
			end

			# puts("   ##### cmpi #{cmpi}")

			if(cmpi < 1)
				return('.') if(relto == path)
				return(path)
			end

			diff = rtspl.size - cmpi

			# puts("   ##### diff #{diff}")
			op=[]
			1.upto(diff) { op << '..' }
			cmpi.upto(pspsz-1) { |i| op << pspl[i] }
			op.join('/')
		end

		# Same as getRelativePath except the returned path uses '\\' instead of '/'
		# as a path separator
		def getWindowsRelativePath(path,relto=nil)
			getRelativePath(path,relto).gsub('/','\\');
		end

		# return true if host environment is windows or cygwin
		def hostIsWindows?
			HostIsWindows_
		end

		# open and read first line of a file and return it
		# returns nil if the file is not present.
		def readOneLineFile(path)
			line = nil
			begin
				File::open(path,'r') do |ifile|
					line = ifile.readline();
					line.chomp!()
				end
			rescue
			end
			line
		end

		# open and read an entire file into a string
		# throws excpetion if the file is not present.
		def readFileToString(path)
			str = nil
			File::open(path,'r') do |f|
				str = f.read();
			end
			str
		end

		if( HostIsWindows_ )
			if(HostIsCygwin_)
				@@stderrToNUL = "2>/dev/null"
			else
				@@stderrToNUL = "2>NUL:"
			end
		else
			@@stderrToNUL = "2>/dev/null"
		end
		
		def textFilesDiffer(a,b)
			differ = true;
			
			sh "diff #{@@stderrToNUL} --brief \"#{a}\" \"#{b}\"", :verbose=>false do |ok, res|
				differ = false if ok
			end
			differ
		end
		
	private
		if( HostIsWindows_ )
			def u2d(file)
				system "unix2dos \"#{file}\" #{@@stderrToNUL}" 
			end								
		else 
			def u2d(file)
				system "unix2dos -q \"#{file}\""
			end		
		end

	public
		# convert unix EOLs to dos EOLs on a file in place
		def unix2dos(file)
			begin
				u2d(file)
			rescue => e
				puts("Warning: #{e}")
			end
		end
			
		# Returns hash containing the difference between a "parent" hash
        # and an overriding "child" hash		
		def hashDiff(parent,child)
			dif={}
			child.defines.each do |k,v|
				next if(parent.has_key?(k) && (parent[k] == v))
				dif[k]=v
			end
			dif
		end

		# Prepends a parent path to an array of file names
		# 
		# returns a FileList containing the joined paths
		def addPathParent(prefix,files)

			if(prefix =~ /\/\z/)
				prefix = $`
			end
			if(files.instance_of?(String))
				a = prefix + '/' + files;
			else
				a = FileList.new() # can one allocate to files.size?
				files.each_index { |i|
					a[i] = prefix + '/' + files[i];
				}
			end
			return(a)
		end

		if( HostIsWindows_ )
            @@binPathOpts_ = { :suffi => [ '.exe', '.bat' ] };
        else
            @@binPathOpts_ = {};
        end

        # Find executable in the "bin" search path
        # return nil if not found.
        #
        #   currently the search path is set to the value of ENV['PATH']
        #
        def self.findInBinPath(name)
            @@binpath||=SearchPath.new(ENV['PATH']);
            ret = @@binpath.findFile(name,@@binPathOpts_);
			log.debug("searh for \"#{name}\" found \"#{ret}\"");
			unless ret 
			   log.debug("Path is #{ENV['PATH']}");
			end
			ret
		end

		# Create a single simple file task to process source to dest
		#
		# if &block is not given, then a simple copy action
		#    do |t| { FileUtils::cp(t.source, t.name) } 
		# is used
		#
		# <b>named arguments:</b>
		#   :config => a config object to set on the created task
		#
		# returns the task created
		
		def createFileTask(dest,source,opts={},&block)
			block = SimpleCopyAction_ unless block_given?
			dest = File.expand_path(dest.to_s)
			dir = File.dirname(dest)
			ensureDirectoryTask(dir)
			task = file dest=>[source,dir], &block
			task.sources = task.prerequisites
			if(dir = opts[:config]) # re-use dir
				task.config = dir
			end
			task
		end

		# Look up a task in the task table using a leading ':' as
		# the indicator of an absolute 'path' like 'rake:'
		def lookupTask(tname)
			Rake.application.lookup((tname=~/^:/)?"rake#{tname}":tname);
		end
		
		# Create a single simple "copy" task to process source file 
		# file of same name in destination directory
		#
		# if &block is not given, then a simple copy action
		#    do |t| { cp(t.source, t.name) } 
		# is used
		#
		# <b>named arguments:</b>
		#   :config => a config object to set on the created task
		#
		# returns the task created
		
		def createCopyTask(destDir,sourceFile,opts={},&block) 
			createFileTask("#{destDir}/#{File.basename(sourceFile)}",sourceFile,opts,&block)
		end
		
		
		# For all files in files create a file task to process the file from the
		# source file files[n] to destdir/basename(files[n])
		# 
		# if &block is not given, then a simple copy task
		#    do |t| { cp t.source t.name } 
		# is used
		#
		# <b>named arguments:</b>
		#
		#   :config  => 'config' object to set on the created tasks
		#   :basedir => directory which will be used to truncate the
		#               path of file[n] to get the relative path of the output 
		#               file from destdir.
		#               ie:  if basedir == "xx/yy"  and file[n] == /aa/bb/xx/yy/file.x 
		#                    then the output file will be 'outdir'+/xx/yy/file.x
		#   :preserve   if true will not overwrite existing task
		#
		# returns an array of all tasks created
		#

		def createCopyTasks(destdir,*files,&block)

			block = SimpleCopyAction_ unless block_given?
			opts = (Hash === files.last) ? files.pop : {}
			preserve = opts[:preserve];

			files = FileSet.new(files); # recursively expand wildcards.
	
			destdir = File.expand_path(destdir);
			if(destdir =~ /\/\z/)
				# too bad rake doesn't check both, it is string based
				ensureDirectoryTask(destdir)
			end
			ensureDirectoryTask(destdir)

			config = opts[:config]
			if(regx = opts[:basedir]) 
				basedir = File.expand_path(regx);
				if(basedir =~ /\/\z/)
					basedir = $`
				end
				regx = Regexp.new('^' + Regexp.escape(basedir+'/'),Regexp::IGNORECASE);
			end
			
			tsk = nil; # declaration only, used below in loop
			flist=[]
			files.each do |f|  # as not a set, flatten if an array
				f = f.to_s			
				f = File.expand_path(f)
				dir = destdir			
				next if(File.directory?(f)) 
				if(regx)
					if(f =~ regx)
						dir = File.dirname($');				
						if(dir.length == 0 || dir == '.')
							dir = destdir
						elsif(destdir.length > 0)
							dir = "#{destdir}/#{dir}"
							ensureDirectoryTask(dir)
						end
					end
				end

				destFile = "#{dir}/#{File.basename(f)}";  # name of task
				if((!preserve) || ((tsk = Rake.application.lookup(destFile)) == nil))
					tsk = file destFile => [ f, dir ], &block
					tsk.sources = tsk.prerequisites
					tsk.config = config if config
				end
				flist << tsk # will always be task and not name here
			end
			flist
		end				
	end

# nothing uses this now - bad idea probably
#	# include in our own module ( not needed )
#	# include Rakish::Util
#
# private
#	class Utils < Module
#		include Util
#	end
#	@@utils = Utils.new
#
# public
#	def self.utils
#		@@utils
#	end

	# Generic dynamic propety bag functionality module1
	# allows 'dot' access to dynamicly set properties.
	#   ie:  value = bag.nameOfProperty
	#        bag.nameOfProperty = newValue
	#
	# Throws an execption if the property or method is not found on this
	# node or any of it's parents.
	#
	# Assignment to a property that does not exist will add a new field *only* if
	# done so within an enableNewFields block
	#
	#   bag.newProperty = "new value" # throws missing method exception
	#   bag.enableNewFields do |s|
	#       s.newProperty = "new value" # OK
	#   end 
	#
	
	module PropertyBagMod

		# constructor for PropertyBagMod to be called by including classes
		# This will take an array of parents scanned like a like a path, first hit wins.
		# by default parents o level above are split into heritable and non-heritable parents
		# the first parent i  the list is considered heritable subsequent parents are in the
        # search path but are not considerd "heritable" so they will not be fround from 
        # inhering childern.		
		def init_PropertyBag(*args)
			@_h = (Hash === args.last) ? args.pop : {}
		    allP = [];
			@parents_ = allP;
			
			if(args.length > 0)
				hp = nil;
				# make parents array the array in the of order of encounter of all unique parents.
				args.each do |p|
					if(p)
						allP << p;
						php = p.heritableParents
						hp||=[p,php].flatten;
						allP << php;
					else
						hp||=[]
					end
				end
				@parents_ = allP.flatten.uniq;
				if( hp.length != @parents_.length) 
					@_hpc_ = hp.length;
				end
			end
			# log.debug("****** parents #{@parents_} allP #{allP}")
  		end

		# get the first parent of this property bag if any
		def parent
			(parents.length > 0 ? @parents_[0] : nil);
		end

		# get the list of ancestors (flattened) in search order.
		def parents
			@parents_||=[]
		end
		# This will supply inheritable parents to children. 
		# 
		# By default only parents[0] and it's hetitableParents are inheritable by children
		# added parents resolve in the search only.
		def heritableParents
			return parents unless @_hpc_;
			@parents_.take(@_hpc_)
		end

		# Enable creation of new fields in a property bag within the supplied block.
		# may be called recursively
		
		def enableNewFields(&b)
			# field creation locked by default, can be recursively "unlocked"
			# by using reference count
			@ul_=@ul_ ? @ul_+1:1
			yield self
			remove_instance_variable(:@ul_) if((@ul_-=1) < 1)
			self # return self for convenience
		end
		
		# Returns false if outside an enableNewFields block the nesting count if
		# inside a enebleNewFields block if(newFieldsEnabled?)  will test true in this case.
		def newFieldsEnabled?() 
			@ul_ ? @ul_:false			
		end
		
		# item from "Module" we want overidable
		# note name does NOT inherit from parents
		def name # :nodoc:
			@_h[:name]
		end
		
		# item from "Module" we want overidable
		# note name does NOT inherit from parents
		def name=(v) # :nodoc:
			@_h[:name]=v
		end
		
		def self.included(by) # :nodoc:
		end
		
		# set or create property irrespective of property (field) creation lock on this object
		def set(k,v)
			if self.class.method_defined? k
				raise PropertyBagMod::cantOverrideX_(k)
			end
			@_h[k]=v
		end

		# Get non-nil value for property 0n any level above, traverse up parent tree via flattened
		# ancestor list to get first inherited value or nil if not found.
		# opts - none define at present
		def getAnyAbove(sym)
            parents.each do |p|
                val = p.getMy(sym);
                return(val) if val;
            end
			nil
		end

		# Get non-nil value for property from heritable parents on any level above,
		# traverse up parent tree via
		# ancestor list to get first inherited value or nil if not found.
		# opts - none defined at present
		def getInherited(sym)
			return(getAnyAbove(sym)) unless @_hpc_;
			pc = @_hpc_;
			@parents_.each do |p|
				break if(pc < 1)
				val = p.getMy(sym);
				return(val) if val;
				pc=pc-1;
			end
			nil
		end
		
		
		# Get value for property, traverse up parent tree to get first inherited
		# value if not present on this node, returns nil if property not found or
		# it's value is explicitly set to nil
		def get(sym)
			if((v=@_h[sym]).nil?)
				unless @_h.has_key?(sym)
					if(self.class.method_defined? sym)
						v=__send__(sym)
					elsif(@parents_.length > 0)
                        @parents_.each do |p|
                            val = p.getMy(sym);
                            return(val) if val;
                        end
					end
				end
			end
			v
		end
	
	protected
		def self.cantOverrideX_(k) # :nodoc:
			"can't overide method \"#{k}\" with a property"
		end
	
		# returns true if any ancestor has a key defined in the hashtable
		def hasAncestorKey(sym) # :nodoc:
			@parents_.each do |p|
				return(true) if p.has_key?(sym);
			end
			false
		end

		def _h # :nodoc: _h accessor
		   @_h
		end

		def raiseUndef_(sym) # :nodoc:
			c = caller;
			caller.each do |clr|
				c.shift
				unless(clr =~ /\/Rakish.rb:\d+:in `(method_missing|__send__)'/)
					# log.debug("\n#{Logger.formatBacktraceLine(clr)} - ##### undefined property or method \"#{sym}\"");
					raise RuntimeError, "\n#{Logger.formatBacktraceLine(clr)} - undefined property or method \"#{sym}\"", c
				end
			end
		end
				
	public
		# Get value for property.
		# Does *not* traverse up tree, gets local value only.
		# returns nil if value is either nil or not present
		def getMy(s)
			(self.class.method_defined? s) ? self.send(s) : @_h[s]
		end

		# true if a property is set in hash on this object
		# does not detect methods
		def has_key?(k) # :nodoc: 
			@_h.has_key?(k)
		end


		# needed so we can flatten the parents array.
		def to_ary # :nodoc:
		   	nil
		end
		
		# allows 'dot' access to properties.
		#   ie:  value = bag.nameOfProperty
		#        bag.nameOfProperty = newValue
		#
		# Throws an execption if the property or method is not found on this
		# node or any of it's parents.
		#
		# Assignment to a property that does not exist will add a new field *only* if
		# done so within an enableNewFields block
		#
		def method_missing(sym, *args, &block) # :nodoc:

			if((v=@_h[sym]).nil?)
				unless @_h.has_key?(sym) # if property exists nil is a valid value
					if sym.to_s =~ /=$/ # it's an attempted asignment ie: ':sym='
						sym = $`.to_sym  # $` has symbol with '=' chopped off
						unless @ul_ # if not locked check if there is an inherited
									# property key declared by an ancestor to assign to
							unless(has_key?(sym))
								super unless hasAncestorKey(sym); # raise no method exception if no key!
							end
						end
						if(self.class.method_defined? sym)
							raise PropertyBagMod::cantOverrideX_(sym)
						end
						return(@_h[sym]=args[0]) # assign value to property
					elsif(@parents_.length > 0) # "recurse" to parents
					    # we don't actually recurse here but check the flattened parent list in order
					    eqSym = "#{sym}=".to_sym;
					    anyDefined = self.class.method_defined?(eqSym);
						@parents_.each do |p|
			               return(p.send(sym)) if(p.class.method_defined? sym);
						   v = p._h[sym];
						   return(v) if (v || p._h.has_key?(sym));
						   anyDefined||=p.class.method_defined?(eqSym);
						end
						return v if(anyDefined);
						raiseUndef_(sym)
					else
						return v if (self.class.method_defined?("#{sym}="));
						raiseUndef_ sym;
					end
				end
			end
			v
		end
	end

	# General purpose property bag class includes PropertyBagMod
	class PropertyBag < Module
		include PropertyBagMod
		
		def initialize(*args,&block)
			init_PropertyBag(*args)
			enableNewFields(&block) if(block_given?)
		end
	end
		
	# A case independent set for file paths
	# intended to act like a Ruby class Set for File path names
	class FileSet < Module
		
		# Create a FileSet containing an initial set of files
		# contained in 'files'.  It will acccept 'wildcard' 
		# entries as defined for a Rake::FileList which are expanded 
		# relative to the current directory at the time entries are added

		def initialize(*files)
			@h={}
			add_ary(files) unless(files.empty?)
		end			
		
		# Case independent string key. WARNING does not clone and intern keys
		# so the source strings must not be changed after being set.
		class Key  # :nodoc:
			def initialize(str)
				@s=str.to_s
				@h=@s.downcase.hash
			end
			def hash
				@h
			end
			def eql?(o)
				@s.casecmp(o)==0
			end
			def to_s
				@s
			end
			alias :to_str :to_s
		end
		
	protected	
		def add_ary(files,v=nil) # :nodoc:
			files.each do |f|
				if(f.respond_to?(:to_ary))
					add_ary(f) # recurse
					next
				end
				f = f.to_s # :nodoc:
				unless(f =~ /[*?]/) # unless a glob?
					f = File.expand_path(f)
					f = Key.new(f)
					@ordered << f if @h[f]
					@h[f]=v
				else
					add_ary(FileList.new(File.expand_path(f)))
				end
			end
		end
		def delete_a(f) # :nodoc:
			if(f.respond_to?(:to_ary))
				f.each do |x| delete_a(x) end
			else
				@h.delete(Key.new(f))
			end
		end
	
	public
		# Add files contained in 'files' to this set.  It will acccept 'wildcard' 
		# entries which are expanded relative to the current directory.
		# relative to the current directory at the time entries are added
		def include(*files)
			add_ary(files)
		end
		
		# Add a single file path to this set if it is not present.
		#
		# returns true if the path was not previously in the set, false otherwise
		# note does NOT expand the path when inserted
		def add?(f)
			f = Key.new(f)
			return false if @h[f]
			@ordered << f if @ordered
  			@h[f]=nil
			true
		end
		# Add a single file path to this set
		# note does NOT expand the path when inserted
		# returns self for convenience
		def add(f)
			add?(f);
			self
		end
		alias :<< :add
		
		# Remove path or paths from this set if they are present
		# It does not accept wildcards,  but will accept FileLists
		def delete(*args)
			delete_a(args)
		end

		# Returns true if the path is in this set
		# false otherwise.
		def include?(f)
			@h.has_key?(Key.new(f))
		end
		
		# Returns true if this set is empty
		def empty?
			@h.empty?
		end

		# Iterates over each path in the set
		def each(&b) # :yields: path
			@h.each do |k,v|
				yield(k.to_s)
			end
		end

		# Like array.join, joins all paths with separator
		def join(separator)
			out = nil;
			each do |p|
				if out
					out += separator; # TODO: not too efficient - memory thrashing
			   		out += p;
				else
					out = p;
				end
			end
			out||'';
		end

		# Returns then number of entries in this set
		def size
			@h.size
		end
		# Returns an array of all path entries in this set
		def to_ary
			@h.keys
		end
	end

    # A FileSet where the order entries are installed is preserved
	class OrderedFileSet < FileSet
		def initialize
			super
			@ordered=[]
		end
		alias :add :add?
		alias :<< :add?

		# Iterates over each path (key) in the set
		# in the order added
		def each(&b) # :yields: path
			@ordered.each do |k|
				yield(k.to_s) unless k.nil?
			end
		end
		# Returns then number of entries in this set
		def size
			@h.size
		end
		# Returns an array of all path entries in this set
		# in the order added
		def to_ary
			@ordered
		end

		def join # :nodoc:
			@ordered.join
		end
		
	end
	
	
	# Case independent "path" hash
	# preserves order of addition
	class FileHash < FileSet
		def initialize()
			super
		end
        def addAll

        end
		def [](k)
			@h[Key.new(k)]
		end
		def []=(k,v)
			@h[Key.new(k)]=v		
		end

		def each_pair(&b)
			@h.each_pair do |k,v|
				yield k,v
			end
		end
		# Returns array of all values in the hash
		def values
			@h.values
		end
	end
		
	# A set of "output" directories each assigned a set of source files.
	# The intention to map a set of input files to a set of output files
	# in a differing directory structure.
	class FileCopySet
		include Util
		
	private
			
		def add_set(set) # :nodoc:
			set.filesByDir do |dir,files|
				ilist = (@byDir_[dir] ||= [])
				add_files_a(ilist,files,nil)
			end
		end
	public
	
		# Create new FileCopySet with optional argument to initialize this set as a 
		# deep copy of another FileCopySet
		def initialize(cloneFrom=nil)
			@byDir_=FileHash.new
			if(cloneFrom && FileCopySet === cloneFrom)
				add_set(cloneFrom)
			end
		end
		
		def debug=(v) # :nodoc:
			@debug=v
		end
		
		class Entry # :nodoc: all
			def initialize(f,data=nil)
				@f=f
				@data = data unless data.nil?
			end
			def to_s
				@f.to_s
			end
			alias :to_str :to_s
			alias :source :to_s
			def dest
				File.basename(@f.to_s)
			end
			def data
				@data
			end
		end
	
	protected

        @@truncLen_ = File.expand_path("/./").length;

        # Cleans up a relative path 'rp' without expanding against the current directory
        #  ie:
        #   ./a/b/c/../../ => ./a
        #   ./ => .
        #
        #  NOTE: this will not work if the relative path evaluates to below itself
        #  which is improper for a destination directory
        #
        def cleanupDestdir(dd) # :nodoc:
            dd=dd.to_s;
            unless(File.path_is_absolute?(dd))
                dd = File.expand_path("/./#{dd}");
                dd = "./#{dd[@@truncLen_,10000]}";
                dd='.' if(dd=='./')
            end
            dd
        end

		def add_simple_a(list,files,data) # :nodoc:
			files.each do |f|
				list << Entry.new(File.expand_path(f.to_s),data)
			end
		end
		def add_files_a(list,files,data) # :nodoc:
			files.each do |f|
				if(f.respond_to?(:to_ary))
					add_files_a(list,f,data)
					next
				end
				if(f =~ /[*?]/) 
					add_simple_a(list,FileList.new(f),data)
					next
				end				
				list << Entry.new(File.expand_path(f.to_s),data)
			end		
		end

	public
		# Add a directory (in destination) with no source files to this set, if not already there.
        # dir = './set/dir' or '.' for the root of a relative destination
		def addDir(dir)
			@byDir_[cleanupDestdir(dir)]||=[]
		end
		
		# add files all assigned to the destdir directory
		def addFiles(destdir, *files)
			if(!files.empty?)
				ilist = (@byDir_[cleanupDestdir(destdir)] ||= [])
				add_files_a(ilist,files,nil)
			end
		end
	protected

		def add_filet_a(destdir,regx,files,data) # :nodoc:
			files.each do |f|
				if(f.respond_to?(:to_ary))
					add_filet_a(destdir,regx,f,data)
					next
				end
				if(f =~ /[*?]/) 
					add_filet_a(destdir,regx,FileList.new(f),data)
					next
				end
				f = File.expand_path(f.to_s)
				isDir = File.directory?(f)
				f =~ regx
				if(isDir)
					dir = ($') ? ((destdir.length > 0) ? "#{destdir}/#{$'}" : $') : destdir	
					@byDir_[dir]||=[]
				else
					dir = File.dirname($');
					if(dir.length == 0 || dir == '.')
						dir = destdir
					elsif(destdir.length > 0)
						dir = "#{destdir}/#{dir}"
					end
					(@byDir_[dir]||=[]) << Entry.new(f,data)
				end
			end		
		end
	
	public
	
        # Adds all the files from a subtree into the destdir in the set
        # the subtree will have it's leading "basedir" removed from the file path
        # and replaced with the "basedir" before adding to the archive.
        #  ie:
        #     file = '/a/b/c/d/e/file.txt'
        #     basedir = '/a/b/c'
        #     destdir = './set/dir' or '.' for the root of a relative destination
        #
        #     added to set = 'set/dir/d/e/file.txt'
        #
		# <b>named options:</b>
		#   :data => user value to assign to all entries added to this set
		#
		def addFileTree(destdir, basedir, *files)
			opts = (Hash === files.last) ? files.pop : {}			
			destdir = cleanupDestdir(destdir);
			basedir = File.expand_path(basedir)
			regx = Regexp.new('^' + Regexp.escape(basedir+'/'),Regexp::IGNORECASE);
			add_filet_a(destdir,regx,files,opts[:data])
		end
	
		# Retrieve all source files by assigned output directory
		# one source file may be assigned to more than one output directory
		#
		def filesByDir(&block) # :yields: directory, iterable of files
			@byDir_.each_pair do |k,v|
				yield(k.to_s,v)
			end
		end
		
		# Return array of all source files in this set
		def sources
			v = @byDir_.values.flatten;
			v.uniq!
			v
		end
		
		def prettyPrint
			filesByDir do |k,v|
				if(v.length > 0)
					puts("\n");
				end
				puts("directory #{k}");
				v.each do |f|
					puts( "      \"#{f}\"")
				end
			end
		end
		
		# Generate processing tasks for all files in this copy set
		# using the task action provided or a simple copy if not
		# hash args
		#     :suffixMap - map from source suffi to destination suffi
		#     :config - value to set for task.config
		#     TODO:ensureOutputDirs - if true ensure a task is present for creating
		#                         the output directory and assign it as prerequisite
		#                         default is true
		#     TODO: :outputDir value of directory to place output files

		def generateFileTasks(args={}, &block)

			ensureOutputDirs = args[:ensureOutputDirs];
			suffixMap = args[:suffixMap]||{};
			tasks = [];
			block = SimpleCopyAction_ unless block_given?

			filesByDir do |dir,files|
				# TODO: maybe have an output directory option and maybe relative path option for destinations ?
				# dir = File.join(destDir,dir);
				ensureDirectoryTask(dir)

				files.each do |srcfile|
					destname = File.basename(srcfile);
					oldext = File.extname(destname);
					if(oldext)
						newext = suffixMap[oldext];
						destname = destname.pathmap("%n#{newext}") if newext
					end
					dest = File.join(dir, destname);
					task = file dest=>[srcfile,dir], &block
					task.sources = task.prerequisites
					# set configuration data on task if desired
					if(cfg = args[:config])
						task.config = cfg
					end
					tasks << task
				end
			end
			tasks
		end
		
	end
	
	# not used yet intending to use it for MultiTask queueing
	class CountingSemaphore
	  def initialize(initvalue = 0)
		@counter = initvalue
		@waiting_list = []
	  end

	  def wait
		Thread.critical = true
		if (@counter -= 1) < 0
		  @waiting_list.push(Thread.current)
		  Thread.stop
		end
		self
	  ensure
		Thread.critical = false
	  end

	  def signal
		Thread.critical = true
		begin
		  if (@counter += 1) <= 0
		t = @waiting_list.shift
		t.wakeup if t
		  end
		rescue ThreadError
		  retry
		end
		self
	  ensure
		Thread.critical = false
	  end

	  alias down wait
	  alias up signal
	  alias P wait
	  alias V signal

	  def exclusive
		wait
		yield
	  ensure
		signal
	  end

	  alias synchronize exclusive

	end

    # :nodoc: not used curently
	# Semaphore = CountingSemaphore

end
