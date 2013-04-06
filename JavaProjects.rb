myPath = File.dirname(File.expand_path(__FILE__));
require "#{myPath}/RakishProject.rb"

module Rakish


module JavaProjectConfig

    attr_reader :outputClasspath

    def self.included(base)
        base.addModInit(base,self.instance_method(:initializer));
    end
 	def initializer(pnt)
 	end
    def classPaths
        @classPaths_||=@parent_.classPaths
    end
    def addClassPaths(*paths)
		@classPaths_||= FileSet.new;
        @classPaths_.include(paths);
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

public
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
            srcFiles.addFileTree(outputClasspath, root, files );
        end

        # do nothing as this is only for making a dependency entry for the javac compile task
        # which compiles all the source files.
        tasks = srcFiles.generateFileTasks(:suffixMap=>{ '.java'=>'.class' }, &DoNothingAction_);

        tsk = task :compile =>tasks do |t|

            config = t.config;
            cmdline = "\"#{config.jdk_}/bin/javac.exe\"";
            cmdline << " -verbose -g -d \"#{outputClasspath}\""

            paths = config.sourceRoots
            unless(paths.empty?)
                prepend = " -sourcepath \"";
                paths.each do |path|
                    cmdline << "#{prepend}#{path}"
                    prepend = ';'
                end
                cmdline << "\"";
            end

            paths = config.classPaths
            unless(paths.empty?)
                cmdline << " -classpath \"#{outputClasspath}\"";
                paths.each do |path|
                    cmdline << ";#{path}"
                end
                cmdline << "\"";
            end

            t.sources.each do |src|
                cmdline << " \"#{src}\"";
            end

            puts("#{cmdline}");
            system( cmdline );

        end
        tsk.config = self;
        tsk.sources = srcFiles.sources
        tsk;
    end

    def javac()

        puts cmdline

    end

    def addSourceRoot(*roots)
        (@sourceDirs_||=FileSet.new).include(roots);
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
