myPath = File.dirname(File.expand_path(__FILE__));
require "#{myPath}/RakishProject.rb"
require 'tmpdir'

module Rakish


module JavaProjectConfig

    attr_reader :javaOutputClasspath
    attr_reader :java_home

    def javaClassPaths
        @javaClassPaths_||=(@parent_.get(:javaClassPaths)||FileSet.new);
    end
    def addJavaClassPaths(*paths)
		@javaClassPaths_||= FileSet.new;
        @javaClassPaths_.include(paths);
    end
end

module JavaProjectModule
    include JavaProjectConfig

protected

    addInitBlock do |pnt,opts|
        if(pnt != nil)
            @java_home = pnt.get(:java_home);
        end
        @java_home ||= File.expand_path(ENV['JAVA_HOME']);
    end

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
        copyFiles = FileCopySet.new;

        javaSourceRoots.each do |root|
            files = FileList.new
            files.include("#{root}/**/*.java");
            srcFiles.addFileTree(javaOutputClasspath, root, files );
            files = FileList.new
            files.include("#{root}/**/*");
            files.exclude("#{root}/**/*.java");
            copyFiles.addFileTree(javaOutputClasspath, root, files);
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

        tasks = copyFiles.generateFileTasks();
        tsk.enhance(tasks);

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

    class JarFileTask < Rake::FileTask

        def jarContents
            @contents_||=[]
        end

        def addDirectoryContents(dir)
            jarContents << dir;
        end

        def addJarContents(jar)
            jarContents << jar;
        end
    end


    def createJarFileTask(opts={})
        jarPath = opts[:name]||"#{BINDIR()}/#{moduleName}.jar";
        jarPath = jarPath.pathmap("%X.jar");

        tsk = JarFileTask.define_task jarPath do |t|
            config = t.config;

            cmdline = "\"#{config.java_home}/bin/jar.exe\" cMf \"#{getRelativePath(t.name)}\"";
            hasJars = FALSE;

            Dir.mktmpdir() do |dir|

                t.jarContents.each do |path|
                    if(path.end_with?('.jar'))
                        hasJars = TRUE;
                        FileUtils.cd dir do
                            jarcmd = "\"#{config.java_home}/bin/jar.exe\" xf \"#{getRelativePath(path)}\"";
                            system(jarcmd);
                            rm_rf 'META-INF';
                        end
                    else
                        cmdline += " -C \"#{getRelativePath(path)}\" .";
                    end
                end

                if(hasJars)
                    cmdline += " -C \"#{dir}\" .";
                end

                # cmdline << " -g -d \"#{outClasspath}\""

                log.info("#{cmdline}") # if verbose?
                system( cmdline );
            end
        end
        tsk.config = self;
        tsk
    end

end


JavaProject = GetProjectClass( :includes=>[JavaProjectModule] );

end # Rakish
