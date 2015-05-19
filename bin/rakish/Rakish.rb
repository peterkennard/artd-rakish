# Rakish module utilities
#
# $Id $

# this is becoming a "gem" we wat to require files with "rakish/FileName"

gemPath = File.expand_path("#{File.dirname(File.expand_path(__FILE__))}/..");
$LOAD_PATH.unshift(gemPath) unless $LOAD_PATH.include?(gemPath)

module Kernel


if false
  if defined?(rakish_original_require) then
	# Ruby ships with a custom_require, override its require
	remove_method :require
  else
	##
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

end

end # false

require 'set'
require 'logger'


# stupid thing needed because rake doesn't check for "" arguments so we make an explicit task
task "" do
end

# define the Logger first so we can use it to abort
module Rakish

	# To use this Logger initialization include it in a class or module
	# then you can do log.debug { "message" } etc 
	# from methods or initializations in that class

	module Logger

		@@_logger_ = ::Logger.new(STDOUT);

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
		
		# format a backtrace line appropriately for the IDE we are using.
		def self.formatBacktraceLine(line)
			sp = line.split(':in `',2);
			sp0 = sp[0].sub(/:(\d)/, '(\1');
			sp1 = sp.length > 1 ? "in `#{sp[1]}" : "";
			"#{sp0}) : #{sp1}";
		end

		def self.formatBacktrace(backtrace)
			out=[];
			backtrace.each do |line|
				out << formatBacktraceLine(line);
			end
			out.join("\n");
		end
		
		def self.included(by)
			by.class.send(:define_method, :log) do
				Rakish.log
			end
		end
		def log
			Rakish.log
		end
	end

	def self.log
		Rakish::Logger.log
	end

	# Execute shell command in sub process and pipe output to Logger
	# cmdline - single string command line, or array of command and arguments
	# opts:
	#     :verbose - if set to true (testable value is true) will print command when executing
	#     :env - environment hash for spawned process
	#
	#  returns status return from spawned process.

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

			# TODO: handle throwing exception if the process aborts with an error return code
			IO.popen(cmdline) do |output|
				# be nice if there was a log.flush method.
				# STDOUT.flush;  # should not be done in "batch" non TTY processes.
				while line = output.gets do
					log.info line.strip!
				end
			end
			return $?
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

end

# rake extensions


module Rake

	module DSL  # so if a version doesn't have it it works
	end

	class << self
		def get_unique_name
			@_s_||=0
			@_s_ += 1
			:"_nona_#{@_s_}"
		end
	end

	module TaskManager
	   # the only difference here is flattening the dependencies
	   def resolve_args(args)
		 if args.last.is_a?(Hash)
		   deps = args.pop
		   ret = resolve_args_with_dependencies(args, deps)
		   ret[2].flatten!
		   ret
		 else
		   resolve_args_without_dependencies(args)
		 end
	   end
	end

	class Application

		# Display the error message that caused the exception.
		# formatted the way we like it for a particualar IDE

		def display_error_message(ex)
		  
		  $stderr.puts "#{name} aborted!: #{ex.message}"
		  backtrace = ex.backtrace;

		  if options.trace
			$stderr.puts Rakish::Logger.formatBacktrace(backtrace)
		  else
			$stderr.puts(Rakish::Logger.formatBacktraceLine(backtrace[0]));
			$stderr.puts rakefile_location(backtrace);
		  end

		  $stderr.puts "Tasks: #{ex.chain}" if has_chain?(ex)
		  $stderr.puts "(See full trace by running task with --trace)" unless options.trace
		end
	end
	
	class Task
	  include Rakish::Logger
	  
	  rake_extension('config') do
		# optional "config" field on Rake Task objects
		attr_accessor :config
	  end

	  rake_extension('data') do
		# optional "per instance" field on Rake Task objects
		attr_accessor :data
	  end

	  # see Rake.Task as this overrides it's method
	  def enhance(args,&b)
		# instead of |=
		@prerequisites = [@prerequisites,args].flatten if args
		@actions << b if block_given?
		self
	  end

	  def scopeExec(args=nil)
		  @application.in_namespace_scope(@scope) do
			  FileUtils.cd @_p_.projectDir do
				  _baseExec_(args);
			  end
		  end
	  end
	  private :scopeExec

	  rake_extension('setProjectScope') do
		def setProjectScope(d)
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
		# define a task with a unique anonymous name
		# TODO: doesn't handle :name=>[] hash dependencies
		def define_unique_task(*args,&b)
			args.unshift(Rake.get_unique_name)
			Rake.application.define_task(self,*args,&b);
		end
	  end
	end
	
	# force all file tasks to reference full path for file name
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
		def _trc
			puts("** namespace \":#{@scope.join(':')}\"");
		end
		private :_trc

		# directory tasks are always in root list so this should be a bit faster
		rake_extension('directory_task_defined?') do
			def directory_task_defined?(path)
				@tasks.has_key?(path)
			end
		end

		# this allows for explicitly setting an "absolute" namespace
		rake_extension('in_namespace_scope') do
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
	end
end

module Rakish

	MAKEDIR = File.dirname(File.expand_path(__FILE__));

	class ::Module
		
		# static method used like ruby's attr_accessor declaration
		# for use in declaring added properties on a class
		# inheriting from a PropertyBag

		def attr_property(*args)
			if(self.include? ::Rakish::PropertyBagMod)
				args.each do |s|
					# add "property" assignment operator method s= to this class
					# equivalent of: def s=(v) { @h_[s]=v }
					# where s is the input symbol, it is formatted as a string and passed
					# to eval
					eval("self.send(:define_method,:#{s}=){|v|@h_[:#{s}]=v}")
				end
			else
				raise("can only add properties to PropertyBag object")
			end
		end

		def addInitBlock(&b)
			(@_init_||=[])<<b if block_given?
		end

		def _initBlocks_
			@_init_;
		end

	end

	class ::Class

		# monkey hack to call the initBlocks of all modules included in this class in the included order
		# nicely provided by the ancestors list
		# use this in an instance initializer:
		#
		#    obj.class.initializeIncluded(obj,*args);

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

	class MultiProcessTask < Rake::Task
	private
		def invoke_prerequisites(args, invocation_chain)
			threads = @prerequisites.collect { |p|
				Thread.new(p) { |r| application[r].invoke_with_call_chain(args, invocation_chain) }
			}
			threads.each { |t| t.join }
		end
	end

	module LoadableModule
		include Rakish::Logger

		@@loadedByFile_ = {};

		def self.load(fileName)
			fileName = File.expand_path(fileName);
			mod = @@loadedByFile_[fileName];
			return mod if mod;
			begin			
				Thread.current[:loadReturn] = nil;
				Kernel.load(fileName);
				mod = Thread.current[:loadReturn];
				@@loadedByFile_[fileName] = mod if(mod);
			rescue => e
				log.error { e };
				mod = nil;
			end
			Thread.current[:loadReturn] = nil;
			mod
		end
		def self.onLoaded(retVal)
			Thread.current[:loadReturn] = retVal;
		end
	end

	public


	# a bunch of utility functions used by Projects and configurations
	module Util
		include ::Rake::DSL
		include Rakish::Logger
				
		module Git

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


		# like each but checks for null and if object doesn't respond to each
		# use like 
		# eachof [1,2,3] do |v|
		# end
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

		# execute shell command and pipe output to Logger
		def execLogged(cmd, opts={})
			Rakish.execLogged(cmd,opts)
		end

		# Generate an anonymous name.
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

		# get time stamp of file or directory 
		def filetime(name)
			File.exists?(name) ? File.mtime(name.to_s) : Rake::EARLY
		end

		# get simple task action block (lambda) to copy from t.source to t.name
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
		# <b>named options:</b> all [true|false]: 
		#	:force   => default true
		#	:noop    => just print (if verbose) don't do anything
		#	:verbose => print "rm ..." for each file
		#   :noglob  => do not interpret '*' or '?' as wildcard chars
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
		
		# "pre-process" input lines using the ruby escape sequence
		# '#{}' for substitutions
		#  in the binding
		#     linePrefix is an optional prefix to prepend to each line.
		#
		#     setIndent means set a variable "indent" in the environment
		#     to be the indent level of the current raw line
		#
		#   ffrom = input lines (has to implement each_line)
		#   fout  = output file (has to implement puts)
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

		# "preprocess" a file using the ruby escape sequence 
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

		# create relative path between path and relto
		# returns absolute path of path if the roots 
		# are different.
		def getRelativePath(path,relto=nil)

			relto ||= pwd
			relto = File.expand_path(relto)
			path = File.expand_path(path.to_s)
			if( path =~ /^#{relto}\//)
				return("./#{$'}")
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

		def getWindowsRelativePath(path,relto=nil)
			getRelativePath(path,relto).gsub('/','\\');
		end

		HostIsCygwin_ = RUBY_PLATFORM =~ /(cygwin)/i
		HostIsWindows_ = (Rake::application.windows? || HostIsCygwin_ )
		
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
			
		def hashDiff(parent,child)
			dif={}
			child.defines.each do |k,v|
				next if(parent.has_key?(k) && (parent[k] == v))
				dif[k]=v
			end
			dif
		end

		# prepends a parent path to an array of file names
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
		
		# create a single simple file task to process source to dest
		#
		# if &block is not given, then a simple copy action
		#    do |t| { cp(t.source, t.name) } 
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
		
		def lookupTask(tname)
			Rake.application.lookup(tname);
		end
		
		# create a single simple "copy" task to process source file 
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
		
		
		# for all files in files create a file task to process the file from the
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

	# yes including your own internal module
	include Rakish::Util
	
private
	class Utils < Module
		include Util
	end
	@@utils = Utils.new

public	
	def self.utils
		@@utils
	end

	# generic dynamic propety bag functionality
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
	
	module PropertyBagMod

		# constructor for PropertyBagMod to be called by including classes
		def init_PropertyBag(*args)			
			@h_ = (Hash === args.last) ? args.pop : {}			
			@parent_=args.shift
		end

		# get the parent of this property bag
		def parent
			@parent_
		end

		# enable creation of new fields in a property bag within the suppiled block.
		# may be called recursively
		
		def enableNewFields(&b)
			# field creation locked by default, can be recursively "unlocked"
			# by using reference count
			@ul_=@ul_ ? @ul_+1:1
			yield self
			remove_instance_variable(:@ul_) if((@ul_-=1) < 1)
		end
		
		# item from "Module" we want overidable
		def name
			@h_[:name]
		end
		
		# item from "Module" we want overidable
		def name=(v)
			@h_[:name]=v		
		end
		
		def self.included(by)
		end
		
		# set or create property irrespective of property (field) creation lock on this object
		def set(k,v)
			if self.class.method_defined? k
				raise PropertyBagMod::cantOverideX_(k)
			end
			@h_[k]=v
		end

		# get value for property, traverse up parent tree to get first inherited 
		# value if not present on this node, returns nil if property not found or
		# it's value is nil
		def get(sym)
			if((v=@h_[sym]).nil?)
				unless @h_.has_key?(sym)
					if(self.class.method_defined? sym)
						v=__send__(sym)
					else
						v=@parent_.get(sym) if @parent_
					end
				end
			end
			v
		end
	
	protected
		def self.cantOverideX_(k)
			"can't overide method \"#{k}\" with a property"
		end
	
	public
		# get value for property. 
		# does *not* traverse up tree, gets local value only.
		# returns nil if value is either nil or not present
		def getMy(s)
			(self.class.method_defined? s) ? self.send(s) : @h_[s]
		end

		# class Eqnil
		#	def self.nil?
		#		true
		#	end
		# end
		
		# preperty is set on this node
		def has_key?(k)
			@h_.has_key?(k)
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
		def method_missing(sym, *args, &block)

			if((v=@h_[sym]).nil?)
				unless @h_.has_key?(sym) # if property exists nil is a valid value
					if sym.to_s =~ /=$/ # it's an attempted asignment ie: ':sym='
						sym = $`.to_sym  # $` has symbol with '=' chopped off
						unless @ul_ # if locked check if there is an inherited 
									# property declared by an ancestor to assign to
							p = self
							until(p.has_key?(sym))
								super unless(p=p.parent) # raise no method exception!
							end
						end
						if(self.class.method_defined? sym)
							raise PropertyBagMod::cantOverideX_(sym)
						end
						return(@h_[sym]=args[0]) # assign value to property
					elsif @parent_ # recurse to parent
						return @parent_.get(sym) if(self.class.method_defined?("#{sym}="))
						return @parent_.__send__(sym)
					else
						return v if (self.class.method_defined?("#{sym}="))
						c = caller
						caller.each do |clr|
							c.shift
							unless(clr =~ /\/Rakish.rb:\d+:in `(method_missing|__send__)'/)
								raise RuntimeError, "\n#{Logger.formatBacktraceLine(clr)} - undefined property or method \"#{sym}\"", c
							end
						end
						super
					end
				end
			end
			v
		end
		# enhancement for 1.9.X allows use of upper case names 
		# for property accessors.
		#
		# tries to access method if symbol for const is missing
		# alias :const_missing :__send__
		
#		def const_missing(name)
#			raise "property bag const missing: #{name}"
#		end
	end

	# general purpose property bag :see: PropertyBabMod
	class PropertyBag < Module
		include PropertyBagMod
		
		def initialize(*args,&block)
			init_PropertyBag(*args)
			enableNewFields(&block) if(block_given?)
		end
	end
		
	# case independent set for file paths
	# intended to act like a Ruby class Set for File path names
	class FileSet < Module
		
		# create a FileSet containing an initial set of files
		# contained in 'files'.  It will acccept 'wildcard' 
		# entries which are expanded relative to the current directory.

		def initialize(*files)
			@h={}
			add_ary(files) unless(files.empty?)
		end			
		
		# case independent string key. WARNING does not clone and intern keys
		# so the source strings must not be changed after being set.
		class Key
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
		def delete_a(f) # ;nodoc: 
			if(f.respond_to?(:to_ary))
				f.each do |x| delete_a(x) end
			else
				@h.delete(Key.new(f))
			end
		end
	
	public
		# Add files contained in 'files' to this set.  It will acccept 'wildcard' 
		# entries which are expanded relative to the current directory.
		def include(*files)
			add_ary(files)
		end
		
		# add a single file path to this set if it is not present.
		#
		# returns true if the path was not previously in the set, false otherwise
		def add?(f)
			f = Key.new(f)
			return false if @h[f]
			@ordered << f if @ordered
			@h[f]=nil
			true
		end
		# add a single file path to this set
		def add(f)
			@h[Key.new(f)]=nil
		end
		alias :<< :add
		
		# Remove path or paths from this set if they are present
		# It does not accept wildcards,  but will accept FileLists
		def delete(*args)
			delete_a(args)
		end

		# returns true if the path is in this set
		# false otherwise.
		def include?(f)
			@h.has_key?(Key.new(f))
		end
		
		# returns true if this set is empty
		def empty?
			@h.empty?
		end
		# iterates over each path (key) in the set
		def each(&b) # :yields: path
			@h.each do |k,v|
				yield(k.to_s)
			end
		end
		# returns then number of entries in this set
		def size
			@h.size
		end
		# returns an array of all path entries in this set
		def to_ary
			@h.keys
		end
	end

	class OrderedFileSet < FileSet
		def initaliaze
			super
			@ordered=[]
		end
		alias :add :add?
		alias :<< :add?

		# iterates over each path (key) in the set
		def each(&b) # :yields: path
			@ordered.each do |k|
				yield(k.to_s) unless k.nil?
			end
		end
		# returns then number of entries in this set
		def size
			@h.size
		end
		# returns an array of all path entries in this set
		def to_ary
			@ordered
		end
		
	end
	
	
	# case independent "path" hash
	class FileHash < FileSet
		def initialize()
			super
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
		# returns array of all values in the hash
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
	
		# create new FileCopySet with optional argument to initialize this set as a 
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
		# add a directory with no source files to this set, if not already there.
		def addDir(dir)
#			if(dir =~ /^\//)
#				dir = $'           # truncate leading '/' ???
#			end
			@byDir_[dir]||=[]
		end
		
		# add files all assigned to the destdir directory
		def addFiles(destdir, *files)			
			destdir = destdir.to_s
#			if(destdir =~ /^\//)
#				destdir = $'
#			end
			if(!files.empty?)
				ilist = (@byDir_[destdir] ||= [])
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
	
		# add a tree of files all of which are to be assigned 
		# to the supplied 'destdir' relative to 'destdir' as the source files are 
		# relative to the supplied 'basedir'
		#
		#  ie: if destdir is 'outdir' basedir is '/base/dir'
		#  the file '/base/dir/dir2/file.x' will be assigned to the 
		#  directory outdir/dir2[/file.x]
		#
		# <b>named options:</b>
		#   :data => user value to assign to all entries added to this set
		#
		def addFileTree(destdir, basedir, *files)
			opts = (Hash === files.last) ? files.pop : {}			
			destdir = destdir.to_s
#			if (destdir =~ /^\//)
#				destdir = $'
#			end
			basedir = File.expand_path(basedir)	
			regx = Regexp.new('^' + Regexp.escape(basedir+'/'),Regexp::IGNORECASE);
			add_filet_a(destdir,regx,files,opts[:data])
		end
	
		# retrieve all source files by assigned output directory
		# one source file may be assigned to more than one output directory
		#
		def filesByDir(&block) # :yields: directory, iterable of files
			@byDir_.each_pair do |k,v|
				yield(k.to_s,v)
			end
		end
		
		# return array of all source files in this set
		# TODO: make this a true set and remove redundancies
		def sources
			@byDir_.values.flatten
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
		
		# generate processing tasks for all files in this copy set
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

	Semaphore = CountingSemaphore

end
