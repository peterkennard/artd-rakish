myPath = File.dirname(File.expand_path(__FILE__));
require "#{myPath}/ZipBuilder.rb"

module Rakish


# mixin to add java configuration to a configuration or project
# adds accessors for javaConfig and java_home
module JavaProjectConfig
    include BuildConfigModule

    class JavaConfig < PropertyBag

        def initialize(parent,projConfig) # :nodoc:
            super(parent,projConfig);
            # self.class.initializeIncluded(self,parent);
            yield self if block_given?
        end

        def classpathSeparator
           @@classpathSeparator_||= ( BuildConfig::BASEHOSTTYPE =~ /Windows/ ? ';' : ':');
        end

        def classPaths
            @classPaths_||=(getInherited(:classPaths)||FileSet.new);
        end

        def addClassPaths(*paths)
            unless(@_cpWritable_)
                @classPaths_=FileSet.new(classPaths);
                @_cpWritable_ = true;
            end
            classPaths.include(paths);
        end
    end

    # Get instance of JavaConfig for this configuration
    def java
       @javaConfig_||=JavaConfig.new(getAnyAbove(:java),parent);
    end

end




module JarBuilderModule

    #- Subclass of Rakish::ArchiveBuilder
    class JarBuilder < ArchiveBuilder

    public

        # Add task to extract contents from the given jar file, if specified, will apply filters
        # and add the extracted files/folders to the root of the
        # new archive recursively, the extraction is done when the
        # builder task is invoked.
        # filters - if filters are specified, they select files within the source to put in the jar
        # with the wildcard path relative to the source root in the format of a Rake::FileList
        # the default if unspecified is to select all files in the source.
        # The list of files is resolved when the builder task is invoked.

        def addJarContents(jarPath,*filters)
            addZipContents(jarPath,*filters);
        end

   	    def doBuildJarAction(t) # :nodoc:
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

        # Create a task for building a jar file to specifications stored in this builder.
        def jarTask(*args)
            tsk = ArchiveTask.define_task(*args).enhance(nil,&@@buildJarAction_);
            tsk.config = self;
            tsk
        end

    end

    # Create e new JarBuilder for the including project's context
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
            java = cfg.java;

            # log.debug("doc output path is [#{cfg.docOutputDir}]");

            FileUtils.mkdir_p(cfg.docOutputDir);
            separator = cfg.java.classpathSeparator;

            cmdline = "\"#{cfg.java_home}/bin/javadoc\" -d \"#{cfg.docOutputDir}\"";
            cmdline += " -quiet";
            unless(java.classPaths.empty?)
                classpath = java.classPaths.join(separator);
                cmdline += " -classpath \"#{classpath}\"";
            end

            sourcepath = java.sourceRoots.join(';');
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

    # Overrides java in JavaProjectConfig
    # Get instance of JavaBuilder < JavaConfig for this project
    def java
        @javaConfig_||=JavaBuilder.new(self);
    end

    include JarBuilderModule
    include ZipBuilderModule
    include JavadocBuilderModule

protected

    addInitBlock do |pnt,opts|
        enableNewFields do |my|
            my.java_home = my.getAnyAbove(:java_home) || File.expand_path(ENV['JAVA_HOME']);
        end
    end

    # Configuration/Builder API available as JavaProjectModule.java
    # in projects including the JavaProjectModule
    class JavaBuilder < JavaConfig
        include Rakish::Util

        def initialize(proj) # :nodoc:
            super(proj.getAnyAbove(:java),proj);
            @myProject = proj; # cache this
        end

        # the project this is attached to
        attr_reader :myProject

        def export(t,&b) # :nodoc:
            @myProject.export(t,&b)
        end

        # Add source root directory(s) to the list of source roots for this compile.
        #
        # options:
        #
        # [:generated] if true, part or all of this directory or it's contents will not exist until after a prerequisite target to the :compile task has built it's contents.
        def addSourceRoots(*roots)
            opts = (roots.last.is_a?(Hash) ? roots.pop : {})
            (@javaSourceDirs_||=FileSet.new).include(roots);
        end

        # retrieve added source roots, default to [projectDir]/src if not set
        def sourceRoots
            @javaSourceDirs_||=[File.join(projectDir,'src')];
        end


        # Adds output classpaths from other java project modules to the classpath set for
        # this build configuration
        def addProjectOutputClasspaths(*moduleNames)
            names = moduleNames.flatten;
            names.each do |name|
                proj = nil;
                begin
                    proj = Rakish.projectByName(name);
                    addClassPaths(proj.java.outputClasspath);
                rescue => e
                    log.error { "#{moduleName} - failure loading classpath for #{name}" }
                    log.error { e } if(proj);
                end
            end
        end

        def outputClasspath
            @outputClasspath||="#{buildDir()}/production/#{moduleName()}";
        end

        def doCompileJava(t) # :nodoc:

            config = t.config;

            FileUtils::mkdir_p(outputClasspath);

            outClasspath = getRelativePath(outputClasspath);

            cmdline = "\"#{config.java_home}/bin/javac\"";
            cmdline << " -g -d \"#{outClasspath}\""

            separator = config.classpathSeparator;
            paths = config.classPaths

            unless(paths.empty?)
                cmdline << " -classpath \"#{outClasspath}";
                paths.each do |path|
                    cmdline << "#{separator}#{getRelativePath(path)}"
                end
                cmdline << "\"";
            end

            paths = sourceRoots
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


    #        sourceRoots.each do |root|
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

        # :nodoc:
        CompileJavaAction = ->(t) do
            t.config.doCompileJava(t);
        end

        def javacTask(deps=[])

            srcFiles = FileCopySet.new;
            copyFiles = FileCopySet.new;

            sourceRoots.each do |root|
                files = FileList.new
                files.include("#{root}/**/*.java");
                srcFiles.addFileTree(outputClasspath, root, files );
                files = FileList.new
                files.include("#{root}/**/*");
                files.exclude("#{root}/**/*.java");
                copyFiles.addFileTree(outputClasspath, root, files);
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

        # Adds and exports simple configured targets for building classes, creating jar file, src.zip file
        # and exports :compile (classes), :libs (jar files), and :dist (jar file, -src.zip, and -doc.zip file
        # requires that source roots and compile classpaths have been set in this builder.
        def addLibraryTargets(opts={})

            export task :resources;

            proj = myProject();

            javac = java.javacTask

            export (task :compile => javac);

            jarBuilder = createJarBuilder();
            jarBuilder.addDirectory(java.outputClasspath());

            jarPath = opts[:name]||"#{binDir()}/#{moduleName}.jar";
            jarPath = jarPath.pathmap("%X.jar");

            jarTask = jarBuilder.jarTask(jarPath);
            jarTask.enhance(:compile);

#            jarTask = proj.createJarFileTask();
#            jarTask.enhance(:compile);
#            jarTask.addDirectoryContents();


            zipBuilder = proj.createZipBuilder();
            java.sourceRoots.each do |dir|
                zipBuilder.addDirectory(dir, "**/*.java");
            end
            srcZip = zipBuilder.zipTask(jarTask.name.pathmap('%X-src.zip'));

            export (task :libs => [jarTask, srcZip ])

            docBuilder = proj.createJavadocBuilder();
            docTask = docBuilder.javadocTask;
            docTask.enhance([:compile]);

            zipBuilder = proj.createZipBuilder();
            zipBuilder.addDirectory(docBuilder.docOutputDir "**/*");

            docZip = zipBuilder.zipTask(jarTask.name.pathmap('%X-doc.zip'));
            docZip.enhance(docTask);

            export (task :javadoc => [ docZip ])
            export (task :dist => [ :libs, :javadoc ])

        end
    end


if(false) # dead code
    protected

        class JarFileTask < Rake::FileTask # :nodoc:

            def jarContents
                @contents_||=[]
            end

            def addDirectoryContents(dir)
                jarContents << dir;
            end
       end

    public

        def createJarFileTask(opts={}) # :nodoc:

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
    end

end

# Frozen class definition for java projects
JavaProject = GetProjectClass( :includes=>[JavaProjectModule] );

end # Rakish
