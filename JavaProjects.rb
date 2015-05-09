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

    class JarBuilder < BuildConfig

    protected
        attr_reader :jarContents_
    public
        addInitBlock do |pnt,opts|
            log.debug("initializing jar builder");
            @jarContents_ = [];
        end

        # jar contents has these "fields"
        # :files   - list of file paths (can use wild cards)
        # :baseDir - base directory of file list as "source root dir" to be truncated from resolved paths
        # :destDir - destination folder in jar file to have truncated files paths added to in jar file.

        # note not resolved until configured task is invoked
        def addFileTree(destdir, basedir, *files)
            entry = {};
            entry[:destDir]=(destdir);
            entry[:baseDir]=(File.expand_path(basedir));

            filePaths = [];

            files.each do |file|
                filePaths << File.expand_path(file);
            end

            entry[:files]=filePaths;
            @jarContents_ << entry;
        end

        # adds all directory contents to root of jar file recursively
        # contents resolved when jar file task is invoked
        # filters - 0 or more selects files within the directory to put in the jar
        # with the wildcard path relative to the source directory
        # the default filer is all files in the dir.
        def addDirectoryContents(dir,*filters)
            if(filters.length < 1)
               filters=['**/*.class'];
            end
            filters.map! do |filter|
                File.join(dir,filter);
            end
            addFileTree('.',dir,*filters);
        end

        # create task for building jar file to specifications stored in builder.
        def jarTask(*args)
            tsk = Rake::FileTask.define_task(*args) do |t|

                log.debug("jar task #{t.name} invoked");

                cfg = t.config;

                FileUtils.mkdir_p(getRelativePath(t.name).pathmap('%d'));
                jarPath = getRelativePath(t.name);

                # note need to have this resolved somewhere for both windows and linux.
                cmdline = "\"#{cfg.java_home}/bin/jar.exe\" cMf \"#{jarPath}\"";

                # delete old jar file
                FileUtils.rm_f jarPath;

                # build a copy set for the jar file's contents
                contents = FileCopySet.new;

                cfg.jarContents_.each do |entry|
                    # for each entry add files to the copy set
                    contents.addFileTree(entry[:destDir],entry[:baseDir],entry[:files]);
                end

            end
            tsk.config = self;

            log.debug("jar task defined #{tsk.name}");
            tsk
        end

    end

    def createJarFileBuilder
        builder = JarBuilder.new(self); # for now we make the parent project the parent config
        builder
    end




    def addJavaClassPaths(*paths)
		@javaClassPaths_||= FileSet.new;
        @javaClassPaths_.include(paths);
    end


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


    def addProjectOutputClasspaths(*moduleNames)
        names = moduleNames.flatten;
        names.each do |name|
            begin
                proj = Rakish.projectByName(name);
                addJavaClassPaths(proj.javaOutputClasspath);
            rescue => e
                log.error { "failure loading classpath for #{name}" }
                log.error { e };
                mod = nil;
            end
        end
    end

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

protected

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

public

    def createJarFileTask(opts={})
        jarPath = opts[:name]||"#{BINDIR()}/#{moduleName}.jar";
        jarPath = jarPath.pathmap("%X.jar");

        tsk = JarFileTask.define_task jarPath do |t|

            config = t.config;

            FileUtils.mkdir_p(getRelativePath(t.name).pathmap('%d'));

            cmdline = "\"#{config.java_home}/bin/jar.exe\" cMf \"#{getRelativePath(t.name)}\"";
            hasJars = FALSE;

            Dir.mktmpdir() do |dir|

                t.jarContents.each do |path|
                    if(path.end_with?('.jar'))
                        hasJars = TRUE;
                        FileUtils.cd dir do
                            jarcmd = "\"#{config.java_home}/bin/jar.exe\" xf \"#{getRelativePath(path)}\"";
                            system(jarcmd);
                            FileUtils.rm_rf 'META-INF';
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
