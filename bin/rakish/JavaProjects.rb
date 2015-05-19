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

module JarBuilderModule

    class JarBuilder < BuildConfig

    public
        attr_reader :jarContents_

        addInitBlock do |pnt,opts|
            @jarContents_ = [];
        end

        # jar contents has these "fields"
        # :files   - list of file paths (can use wild cards)
        # :baseDir - base directory of file list as "source root dir" to be truncated from resolved paths
        # :destDir - destination folder in jar file to have truncated files paths added to in jar file.
        # :cacheList - cache the file list and auto-add dependencies only defined if true

        # note not resolved until configured task is invoked
        def addFileTree(destdir, basedir, *files)
            entry = {};
            entry[:destDir]=(destdir);
            entry[:baseDir]=(File.expand_path(basedir));

            filePaths = [];

            files.flatten.each do |file|
                filePaths << File.expand_path(file);
            end

            entry[:files]=filePaths;
            @jarContents_ << entry;
        end

        # Adds all directory contents to root of jar file recursively
        # contents resolved when jar file task is invoked
        # filters - 0 or more selects files within the directory to put in the jar
        # with the wildcard path relative to the source directory
        # the default filer is all files in the dir.
        # The list of files is resolved when the builder task is invoked.
        def addDirectory(dir,*filters)
            if(filters.length < 1)
               filters=['**/*.class'];
            end
            filters.map! do |filter|
                File.join(dir,filter);
            end
            addFileTree('.',dir,*filters);
        end


        # set up task to extract contents from the given jar file, will apply filters
        # and add the extracted files/folders to the root of the
        # new jar file recursively, the extraction is done when the
        # jarTask is invoked.
        # filters - 0 or more selects files within the directory to put in the jar
        # with the wildcard path relative to the root of the source jar file
        # the default filter is all files in source jar.
        def addJarContents(jarPath,*filters)

            if(filters.length < 1)
               filters=['*'];
            end
            entry = {};
            entry[:destDir]=('.');
            entry[:baseDir]=("#{File.expand_path(jarPath)}###");
            entry[:files]=filters;
            @jarContents_ << entry;
        end

        class JarTask < Rake::FileTask

            # I wonder if there is a better way in rake to auto generate prerequisites when
            # they are demanded
            def resolvePrerequisites
                unless defined? @filesResolved_
                    @filesResolved_ = true;
                    contents = config.jarContents_;

                    contents.each do |entry|
                        baseDir = entry[:baseDir];
                        spl = baseDir.split('###',2)
                        if(spl.length > 1)
                            @prerequisites << spl[0]
                        else
                            copySet = FileCopySet.new;
                            # for each entry add files to the copy set
                            copySet.addFileTree(entry[:destDir],baseDir,entry[:files]);
                            @prerequisites |= copySet.sources;
                            # replace file list in entry with the resolved copy set
                            entry[:files] = copySet if entry[:cacheList]
                        end
                    end
                end
            end

            # List of prerequisite tasks
            def prerequisite_tasks
                resolvePrerequisites unless defined? @filesResolved_
                prerequisites.collect { |pre| lookup_prerequisite(pre) }
            end

            # Is this file task needed?  Yes if it doesn't exist, or if its time stamp
            # is out of date.
            # extension - redo of needed? method which resolves all the specified file lists
            # and adds them all as prerequisites to the task which the purporse is to copy the sources into
            # a destination archive
            def needed?
                resolvePrerequisites unless defined? @filesResolved_
                !File.exist?(name) || out_of_date?(timestamp);
            end
        end

   	    def doJarTaskAction(t)
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

                    cfg.jarContents_.each do |entry|

                        # copy or extract all the files for the jar to a temporary folder
                        # then create a jar containing the contents
                        # and delete the directory

                        baseDir = entry[:baseDir];

                        spl = baseDir.split('###',2)
                        if(spl.length > 1)

                            # from unzip man page
                            #         "*.c" matches "foo.c" but not "mydir/foo.c"
                            #           "**.c" matches both "foo.c" and "mydir/foo.c"
                            #           "*/*.c" matches "bar/foo.c" but not "baz/bar/foo.c"
                            #           "??*/*" matches "ab/foo" and "abc/foo"
                            #                   but not "a/foo" or "a/b/foo"

                            cmd = "unzip -q \"#{spl[0]}\" \"#{entry[:files].join("\" \"")}\" -x \"META-INF/*\" -d \"#{dir}\"";

                            execLogged(cmd, :verbose=>verbose?);

                        else
                            contents = entry[:files];
                            unless(FileCopySet === contents)
                                contents = FileCopySet.new; # a new set for each entry.
                                # for each entry add files to a copy set
                                contents.addFileTree(entry[:destDir],baseDir,entry[:files]);
                            end
                            # copy the file set to the temp folder
                            contents.filesByDir do |destDir,files|
                                FileUtils.mkdir_p destDir;
                                files.each do |file|
                                    FileUtils.cp(file,destDir)
                                end
                            end
                        end
                    end

                    # ensure we have a place to put the new jar file it.
                    FileUtils.mkdir_p(t.name.pathmap('%d'));

                    # need to handle manifest creation etc.
                    cmdOpts = 'cvfM';
                    unless cfg.verbose?
                        cmdOpts = cmdOpts.gsub('v','');
                    end

                    cmdline = "\"#{cfg.java_home}/bin/jar\" #{cmdOpts} \"#{getRelativePath(t.name)}\" .";
                    execLogged(cmdline, :verbose=>cfg.verbose?);
                end
             # ruby seems to do this ok on windows and screws
             # up if I do due to thread latency in spawning the command or something.
             #       FileUtils.rm_rf dir;
            end
        end

        @@jarTaskAction_ = ->(t) do
            t.config.doJarTaskAction(t);
        end

        # create task for building jar file to specifications stored in builder.
        def jarTask(*args)
            tsk = JarTask.define_task(*args).enhance(nil,&@@jarTaskAction_);
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

            cmdline = "\"#{config.java_home}/bin/jar\" #{cmdOpts} \"#{getRelativePath(t.name)}\"";

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