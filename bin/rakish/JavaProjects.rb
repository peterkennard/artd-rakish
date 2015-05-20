myPath = File.dirname(File.expand_path(__FILE__));
require "#{myPath}/ArchiveBuilder.rb"

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

module JarBuilderModule

    class JarBuilder < ArchiveBuilder

    public

        def addDirectory(dir,*filters)
            if(filters.length < 1)
               filters=['**/*.class'];
            end
            filters.map! do |filter|
                File.join(dir,filter);
            end
            addFileTree('.',dir,*filters);
        end

        def addJarContents(jarPath,*filters)
            addZipContents(jarPath,*filters);
        end

   	    def doBuildJarAction(t)
            cfg = t.config;

            puts("creating #{t.name}");

            # delete old jar file and liberate space ? jar when creating clears old file
            # FileUtils.rm_f t.name;

            # use persistent file for debugging
            # dir = "d:/jartemp";
            # rm_rf dir;
            # mkdir_p dir;
            # cd dir

            Dir.mktmpdir do |dir|
                FileUtils.cd dir do
                    loadTempDir(dir)

                    # ensure we have a place to put the new jar file it.
                    FileUtils.mkdir_p(t.name.pathmap('%d'));

                    # need to handle manifest creation etc.
                    cmdOpts = 'cvfM';
                    unless cfg.verbose?
                        cmdOpts = cmdOpts.gsub('v','');
                    end

                    cmdline = "\'#{cfg.java_home}/bin/jar\' #{cmdOpts} \'#{getRelativePath(t.name)}\' .";
                    execLogged(cmdline, :verbose=>cfg.verbose?);
                end
             # ruby seems to do this ok on windows and screws
             # up if I do due to thread latency in spawning the command or something.
             #       FileUtils.rm_rf dir;
            end
        end

        @@buildJarAction_ = ->(t) do
            t.config.doBuildJarAction(t);
        end

        # create task for building jar file to specifications stored in builder.
        def jarTask(*args)
            tsk = ArchiveTask.define_task(*args).enhance(nil,&@@buildJarAction_);
            tsk.config = self;
            tsk
        end

    end

    def createJarBuilder
        JarBuilder.new(self); # for now we make the parent project the parent config
    end

end


module JavaProjectModule
    include JavaProjectConfig
    include JarBuilderModule

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

    def addJavaClassPaths(*paths)
		@javaClassPaths_||= FileSet.new;
        @javaClassPaths_.include(paths);
    end

    def doCompileJava(t)

        config = t.config;

        FileUtils::mkdir_p(config.javaOutputClasspath);

        outClasspath = getRelativePath(config.javaOutputClasspath);

        cmdline = "\"#{config.java_home}/bin/javac\"";
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

        ret = execLogged(cmdline, :verbose=>verbose?);
        raise "Java compile failure" if(ret.exitstatus != 0);
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
            proj = nil;
            begin
                proj = Rakish.projectByName(name);
                addJavaClassPaths(proj.javaOutputClasspath);
            rescue => e
                log.error { "#{moduleName} - failure loading classpath for #{name}" }
                log.error { e } if(proj);
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
   end

public

    def createJarFileTask(opts={})
        jarPath = opts[:name]||"#{BINDIR()}/#{moduleName}.jar";
        jarPath = jarPath.pathmap("%X.jar");

        tsk = JarFileTask.define_task jarPath do |t|

            config = t.config;

            FileUtils.mkdir_p(getRelativePath(t.name).pathmap('%d'));

            cmdOpts = 'cvMf';
            unless config.verbose?
                cmdOpts = cmdOpts.gsub('v','');
            end

            cmdline = "\"#{config.java_home}/bin/jar\" #{cmdOpts} \'#{getRelativePath(t.name)}\'";

            t.jarContents.each do |path|
                cmdline += " -C \"#{getRelativePath(path)}\" .";
            end

            execLogged(cmdline, :verbose=>config.verbose?);
        end
        tsk.config = self;
        tsk
    end

end


JavaProject = GetProjectClass( :includes=>[JavaProjectModule] );

end # Rakish
