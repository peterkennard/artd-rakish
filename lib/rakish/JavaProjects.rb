myPath = File.dirname(File.expand_path(__FILE__));
require "#{myPath}/ZipBuilder.rb"

module Rakish


module JavaProjectConfig
    include BuildConfigModule

    attr_reader :javaOutputClasspath

    def classpathSeparator
       @@classpathSeparator_||= ( BASEHOSTTYPE =~ /Windows/ ? ';' : ':');
    end

    def javaClassPaths
        @javaClassPaths_||=(getInherited(:javaClassPaths)||FileSet.new);
    end

    def addJavaClassPaths(*paths)
        # TODO: needs to not clobber the ancestor's classpath
		@javaClassPaths_||= FileSet.new;
        @javaClassPaths_.include(paths);
    end
end

module JarBuilderModule

    class JarBuilder < ArchiveBuilder

    public

        def addJarContents(jarPath,*filters)
            addZipContents(jarPath,*filters);
        end

   	    def doBuildJarAction(t)
            cfg = t.config;

            log.info("creating #{t.name}") if cfg.verbose

            # delete old jar file and liberate space ? jar when creating clears old file
            # FileUtils.rm_f t.name;

#             ## use persistent file for debugging
#             dir = "d:/jartemp";
#             rm_rf dir;
#             mkdir_p dir;
#             cd dir do

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

                    cmdline = "\"#{cfg.java_home}/bin/jar\" #{cmdOpts} \"#{getRelativePath(t.name)}\" .";
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
        jb = JarBuilder.new(self); # for now we make the parent project the parent config
    end

end

module JavadocBuilderModule

    class JavadocBuilder < BuildConfig

        addInitBlock do |pnt,opts|
            enableNewFields do |my|
                my.docOutputDir="#{buildDir()}/javadoc/#{moduleName}/api";
            end
        end

        def doBuildJavadoc(t)

            cfg = t.config;

            # log.debug("doc output path is [#{cfg.docOutputDir}]");

            FileUtils.mkdir_p(cfg.docOutputDir);
            separator = cfg.classpathSeparator;

            cmdline = "\"#{cfg.java_home}/bin/javadoc\" -d \"#{cfg.docOutputDir}\"";
            cmdline += " -quiet";
            unless(cfg.javaClassPaths.empty?)
                classpath = cfg.javaClassPaths.join(separator);
                cmdline += " -classpath \"#{classpath}\"";
            end

            sourcepath = cfg.javaSourceRoots.join(';');
            cmdline += " -sourcepath \"#{sourcepath}\"";
            cmdline += " -subpackages \"com\"";

            execLogged(cmdline, :verbose=>cfg.verbose?);

            dtime = Time.new;
            File.open("#{t.name}/_buildDate.txt",'w') do |file|
                file.puts("documentation built on #{dtime}");
            end
        end

        BuildJavadocAction = ->(t) do
            t.config.doBuildJavadoc(t);
        end

        def javadocTask(opts={})
            tsk = Rake::FileTask.define_task docOutputDir;
            tsk.enhance([:compile], &BuildJavadocAction);
            tsk.config = self;
            tsk
        end
    end

    def createJavadocBuilder
        JavadocBuilder.new(self)
    end

end


module JavaProjectModule
    include JavaProjectConfig
    include JarBuilderModule
    include ZipBuilderModule
    include JavadocBuilderModule

protected

    addInitBlock do |pnt,opts|
        enableNewFields do |my|
            my.java_home = my.getInherited(:java_home) || File.expand_path(ENV['JAVA_HOME']);
        end
    end

    CompileJavaAction = ->(t) do
        t.config.doCompileJava(t);
    end

public

    def getDelimitedClasspath
        javaClassPaths.join(classpathSeparator);
    end

    def javaClassPaths
        # todo: DON'T ALLOCATE COPY UNTIL THINGS ARE ADDED NEED FLAG :)
        @javaClassPaths_||=FileSet.new(getInherited(:javaClassPaths));
    end
    def addJavaClassPaths(*paths)
        @javaClassPaths_||= FileSet.new(getInherited(:javaClassPaths));
        @javaClassPaths_.include(paths);
    end

    def doCompileJava(t)

        config = t.config;

        FileUtils::mkdir_p(config.javaOutputClasspath);

        outClasspath = getRelativePath(config.javaOutputClasspath);

        cmdline = "\"#{config.java_home}/bin/javac\"";
        cmdline << " -g -d \"#{outClasspath}\""

        separator = config.classpathSeparator;
        paths = config.javaClassPaths

        unless(paths.empty?)
            cmdline << " -classpath \"#{outClasspath}";
            paths.each do |path|
                cmdline << "#{separator}#{getRelativePath(path)}"
            end
            cmdline << "\"";
        end

        paths = config.javaSourceRoots
        javaSrc = FileList.new;

        unless(paths.empty?)

            prepend = " -sourcepath \"";
            paths.each do |path|

                javaSrc.include("#{path}/**/*.java");

                cmdline << "#{prepend}#{getRelativePath(path)}"
                prepend = separator;
            end
            cmdline << "\"";
        end


#        javaSourceRoots.each do |root|
#            srcFiles.addFileTree(javaOutputClasspath, root, files );
#            files = FileList.new
#            files.include("#{root}/**/*");
#            files.exclude("#{root}/**/*.java");
#            copyFiles.addFileTree(javaOutputClasspath, root, files);
#        end

      # we collect the sources above as geenrated code may not be present when the task is created
       javaSrc.each do |src|
 #       t.sources.each do |src|
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

        # add sources we know about
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

    # add source rot dirertory to the list of source roots for thie compile.
    # options:
    # :generated - part or all of this directory or it's contents will not exists until after
    # a dependency target to the compile task has built it's contents.
    def addJavaSourceRoot(*roots)
        opts = (roots.last.is_a?(Hash) ? roots.pop : {})
        (@javaSourceDirs_||=FileSet.new).include(roots);
    end

    def javaSourceRoots
        @javaSourceDirs_||=[File.join(projectDir,'src')];
    end

    # output directory common to all configurations
    def javaOutputClasspath
        @javaOutputClasspath||="#{buildDir()}/production/#{moduleName()}";
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

        jarPath = opts[:name]||"#{binDir()}/#{moduleName}.jar";
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

    # adds and exports configured targets for building classes, creating jar file, src.zip file
    # and exports :compile (classes), :libs (jar files), and :dist (tar file, src.zip file
    # requires that source roots and compile classpaths are set in the project.
    def addJavaLibraryTargets()

        export task :resources;

        javac = javacTask

        export (task :compile => javac);

        jarTask = createJarFileTask();
        jarTask.enhance(:compile);

        jarTask.addDirectoryContents(javaOutputClasspath());


        zipBuilder = createZipBuilder();
        javaSourceRoots.each do |dir|
            zipBuilder.addDirectory(dir, "**/*.java");
        end
        srcZip = zipBuilder.zipTask(jarTask.name.pathmap('%X-src.zip'));

        export (task :libs => [jarTask, srcZip ])

        docBuilder = createJavadocBuilder();
        docTask = docBuilder.javadocTask;
        docTask.enhance([:compile]);

        zipBuilder = createZipBuilder();
        zipBuilder.addDirectory(docBuilder.docOutputDir "**/*");

        docZip = zipBuilder.zipTask(jarTask.name.pathmap('%X-doc.zip'));
        docZip.enhance(docTask);

	    export (task :javadoc => [ docZip ])

	    export (task :dist => [ :libs, :javadoc ])

    end

end


JavaProject = GetProjectClass( :includes=>[JavaProjectModule] );

end # Rakish
