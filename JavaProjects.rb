myPath = File.dirname(File.expand_path(__FILE__));
require "#{myPath}/RakishProject.rb"

module Rakish


module JavaProjectConfig

    attr_reader :outputClasspath

    def self.included(base)
        base.addModInit(base,self.instance_method(:initializer));
    end
 	def initializer(pnt)
		@classPaths_= Set.new;
 	end

    def addClassPaths(*defs)
        defs.flatten!()
        defs.each do |ip|
            @classPaths_.add(File.expand_path(ip));
        end
    end
end

class JavaProject < Project
    include JavaProjectConfig

    def initialize(args={},&block)
        super(args,&block);
    end

    @@CompileJavaAction = lambda do |t|
        t.config.tools.doCompileJava(t)
    end
    def doCompileJava(t)

        cppfile = t.source;
        objfile = t.name;
        cfig = t.config;

        cmdline = "\"#{@MSVC_EXE}\" \"#{cppfile}\" -Fd\"#{cfig.OBJDIR}/vc80.pdb\" -c -Fo\"#{objfile}\" ";
        cmdline += getFormattedMSCFlags(cfig)
        cmdline += ' /showIncludes'

        puts("\n#{cmdline}\n") if(cfig.verbose?)
        included = Rakish::FileSet.new

        IO.popen(cmdline) do |output|
            while line = output.gets do
                if line =~ /^Note: including file: +/
                    line = $'.strip.gsub(/\\/,'/')
                    next if( line =~ /^[^\/]+\/Program Files\/Microsoft /i )
                    included << line
                    next
                end
                puts line
            end
        end

        depfile = objfile.ext('.raked');
        updateDependsFile(t,depfile,included);
    end

    def createCompileTask(source,obj,cfg)

        action = @@CompileForSuffix[File.extname(source).downcase];

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

    def javacTask

        log.info "javaC task";
        log.info { "autogen in artd-bml-rpc #{jdk_}" };
        puts "BUILDDIR = #{BUILDDIR()}"
        puts "outputClasspath = #{outputClasspath}"

        action = @@CompileJavaAction

        srcFiles = FileCopySet.new;
        sourceRoots.each do |root|
            files = FileList.new
            files.include("#{root}/**/*");

            files.each do |f|
                puts("file #{f}");
            end
            srcFiles.addFileTree(outputClasspath, root, files );
        end

    end

    def javac()

        cmdline = "\"#{jdk_}/bin/javac.exe\" -help";
        puts cmdline
     #   system( cmdline );

    end

    def addSourceRoot(*roots)
        roots.flatten!()
        @sourceDirs_||=Set.new
        roots.each do |ip|
            @sourceDirs_.add(File.expand_path(ip));
        end
    end
    def sourceRoots
        @sourceDirs_||=[File.join(projectDir,'src')];
    end
    # output directory common to all configurations
    def outputClasspath
        @outputClasspath||="#{BUILDDIR()}/production/#{moduleName()}";
    end


end




end # Rakish

# global  alias for Rakish::JavaProject.new()
def JavaProject(args={},&block)
	Rakish::JavaProject.new(args,&block)
end
