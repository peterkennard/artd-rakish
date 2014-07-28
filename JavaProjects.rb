myPath = File.dirname(File.expand_path(__FILE__));
require "#{myPath}/RakishProject.rb"

module Rakish


module JavaProjectConfig

    attr_reader :javaOutputClasspath
    attr_reader :java_home

#    def self.included(base)
#        base.addModInit(base,self.instance_method(:initializer));
#    end

 	def initializer(pnt,opts)
 	end

    def javaClassPaths
        @javaClassPaths_||=(@parent_.get(:javaClassPaths)||FileSet.new);
    end
    def addJavaClassPaths(*paths)
		@javaClassPaths_||= FileSet.new;
        @javaClassPaths_.include(paths);
    end
end

module JavaCompileModule
    include JavaProjectConfig

    def self.included(base)
        base.addModInit(base,self.instance_method(:initializer));
    end

 	def initializer(pnt,opts)
 	end

protected

    CompileJavaAction = ->(t) do
        t.config.doCompileJava(t);
    end

public
    def doCompileJava(t)

        config = t.config;
        outClasspath = getRelativePath(config.javaOutputClasspath);

        cmdline = "\"#{config.java_home}/bin/javac.exe\"";
        cmdline << " -g -d \"#{outClasspath}\""

        paths = config.javaClassPaths
        unless(paths.empty?)
            cmdline << " -classpath \"#{outClasspath}";
            paths.each do |path|
                cmdline << ";#{getRelativePath(path)}"
            end
            cmdline << "\"";
        end

        paths = config.javaSourceRoots
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

        log.info("#{cmdline}") # if verbose?
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
    def javacTask(deps=[])

        srcFiles = FileCopySet.new;
        javaSourceRoots.each do |root|
            files = FileList.new
            files.include("#{root}/**/*");
            srcFiles.addFileTree(javaOutputClasspath, root, files );
        end

        tsk = JavaCTask.define_unique_task &CompileJavaAction
        task :compile=>[tsk]

        tasks = srcFiles.generateFileTasks( :config=>tsk, :suffixMap=>{ '.java'=>'.class' }) do |t|  # , &DoNothingAction_);
            # add this source prerequisite file to the compile task if it is needed.
            t.config.sources << t.source
        end

#        if(any_task_earlier?(tasks,File.mtime(File.expand_path(__FILE__))))
#            puts("project is altered");
#        end

        tsk.enhance(deps);
        tsk.enhance(tasks);
        tsk.config = self;

        task :clean do
            addCleanFiles(tasks);
        end

        tsk;
    end

    def addJavaSourceRoot(*roots)
        (@javaSourceDirs_||=FileSet.new).include(roots);
    end
    def javaSourceRoots
        @javaSourceDirs_||=[File.join(projectDir,'src')];
    end

    # output directory common to all configurations
    def javaOutputClasspath
        @javaOutputClasspath||="#{BUILDDIR()}/production/#{moduleName()}";
    end

end


class JavaProject < Project
    include JavaCompileModule

    def initialize(args={},&block)
        super(args,&block);
    end

end

end # Rakish

# global  alias for Rakish::JavaProject.new()
def JavaProject(args={},&block)
	Rakish::JavaProject.new(args,&block)
end
