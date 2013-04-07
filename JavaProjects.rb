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

protected

    CompileJavaAction = lambda do |t|
        t.config.doCompileJava(t);
    end

public
    def doCompileJava(t)

        config = t.config;
        outClasspath = getRelativePath(config.outputClasspath);

        cmdline = "\"#{config.jdk_}/bin/javac.exe\"";
        cmdline << " -g -d \"#{outClasspath}\""

        paths = config.classPaths
        unless(paths.empty?)
            cmdline << " -classpath \"#{outClasspath}";
            paths.each do |path|
                cmdline << ";#{getRelativePath(path)}"
            end
            cmdline << "\"";
        end

        paths = config.sourceRoots
        unless(paths.empty?)
            prepend = " -sourcepath \"";
            paths.each do |path|
                cmdline << "#{prepend}#{getRelativePath(path)}"
                prepend = ';'
            end
            cmdline << "\"";
        end


        t.sources.each do |src|
            cmdline << " \"#{getRelativePath(src)}\"";
        end

        puts("#{cmdline}") # if verbose?
        system( cmdline );

    end

    class JavaCTask < Rake::Task
        def needed?
            !sources.empty?
        end
    end

    # Are there any tasks with an earlier time than the given time stamp?
    def any_task_earlier?(tasks,time)
        tasks.any? { |n| n.timestamp < time }
    end


public
    def javacTask

        srcFiles = FileCopySet.new;
        sourceRoots.each do |root|
            files = FileList.new
            files.include("#{root}/**/*");
            srcFiles.addFileTree(outputClasspath, root, files );
        end

        tsk = JavaCTask.define_task :compile, &CompileJavaAction

        tasks = srcFiles.generateFileTasks( :config=>tsk, :suffixMap=>{ '.java'=>'.class' }) do |t|  # , &DoNothingAction_);
            # add this source prerequisite file to the compile task if it is needed.
            t.config.sources << t.source
        end

#        if(any_task_earlier?(tasks,File.mtime(File.expand_path(__FILE__))))
#            puts("project is altered");
#        end

        tsk.enhance(tasks);
        tsk.config = self;

		task :clean do
			addCleanFiles(tasks);
		end

        tsk;
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
