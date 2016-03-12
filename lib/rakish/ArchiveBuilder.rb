myPath = File.dirname(File.expand_path(__FILE__));
require "#{myPath}/RakishProject.rb"
require 'tmpdir'


module Rakish

    class ArchiveBuilder < BuildConfig

    public

        # archiveContents has these "fields"
        # :files   - list of file paths (can use wild cards)
        # :baseDir - base directory of file list as "source root dir" to be truncated from resolved paths
        # :destDir - destination folder in jar file to have truncated files paths added to in jar file.
        # :cacheList - cache the file list and auto-add dependencies only defined if true
        # requres that utility 'unzip' is in the path

        attr_reader :archiveContents_ # :nodoc:

        addInitBlock do |pnt,opts|
            @archiveContents_ = [];
        end

        def unzipPath # :nodoc:
            @@unzipPath_ ||= Rakish::Util.findInBinPath('unzip');
        end

        # Adds all the files from a subtree into the destdir
        # the subtree will have it's leading "basedir" removed from the file path
        # and replaced with the "basedir" before adding to the archive.
        # note: all "destdir" paths are relative to the root of the archive
        #  ie:
        #     file = '/a/b/c/d/e/file.txt'
        #     basedir = '/a/b/c'
        #     destdir = './archive/dir'
        #
        #     added to archive = 'archive/dir/file.txt'
        #
        # Note: the file list not resolved until configured archive task is
        # checked for being "needed?" or invoked.

        def addFileTree(destdir, basedir, *files)

            # ensure all destdirs are relative to an implicit destination folder
            # with the root specified by '.'
            if(destdir=='.' || destdir == './' || destdir == '/'  || destdir=='')
                destdir == '.'
            elsif(destdir =~ /^\//)
                destdir="./#{$'}"
            else
                unless(destdir =~ /^\.\//)
                    destdir="./#{destdir}";
                end
            end

log.debug("######\ndestdir #{destdir}");

            entry = {};
            entry[:destDir]=(destdir);

            (basedir=File.expand_path(basedir)) unless basedir=='#';

            entry[:baseDir]=basedir;

            filePaths = [];
            files.flatten.each do |file|
                filePaths << File.expand_path(file);
            end

            entry[:files]=filePaths;
            @archiveContents_ << entry;
        end



        # Add files in the *files list into the 'destdir' in the archive
        # note: all "destdir" paths are relative to the root of the archive
        def addFiles(destdir,*files)
            addFileTree(destdir,'#',*files); # note '#' is flag to do addFiles
        end

        # Sets up a task to load contents from a directory to the root of the archive file recursively.
        # filters - if filters are specified, they select files within the directory to put in the jar
        # with the wildcard path relative to the source directory in the format of a Rake::FileList
        # the default if unspecified is to select all files in the directory.
        # The list of files is resolved when the builder task is invoked.

        def addDirectory(dir,*filters)
            if(filters.length < 1)
               filters=['**/*'];
            end
            filters.map! do |filter|
                File.join(dir,filter);
            end
            addFileTree('.',dir,*filters);
        end


        # Add task to extract contents from the given zip file, will apply filters
        # and add the extracted files/folders to the root of the
        # new archive recursively, the extraction is done when the
        # builder task is invoked.
        # filters - if filters are specified, they select files within the source to put in the jar
        # with the wildcard path relative to the source root in the format of a Rake::FileList
        # the default if unspecified is to select all files in the source.
        # The list of files is resolved when the builder task is invoked.

        def addZipContents(archivePath,*filters)

            if(filters.length < 1)
               filters=['*'];
            end
            entry = {};
            entry[:destDir]=('.');
            entry[:baseDir]=("#{File.expand_path(archivePath)}###"); # note "###" is flag to indicate source is an archive
            entry[:files]=filters;
            @archiveContents_ << entry;
        end

        def loadTempDir(dir) # :nodoc: TODO "the "####" and '#' flag thing is messy maybe :type in entry ??


            archiveContents_.each do |entry|

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

                    cmd = "\"#{unzipPath}\" -q \"#{spl[0]}\" \"#{entry[:files].join("\" \"")}\" -x \"META-INF/*\" -d \"#{dir}\"";

                    execLogged(cmd, :verbose=>verbose?);

                else
                    contents = entry[:files];
                    unless(FileCopySet === contents)
                        contents = FileCopySet.new; # a new set for each entry.
                        # for each entry add files to a copy set
                        if(baseDir=="#")
                            contents.addFiles(entry[:destDir],entry[:files]);
                        else
                            contents.addFileTree(entry[:destDir],baseDir,entry[:files]);
                        end
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
        end


        class ArchiveTask < Rake::FileTask

            # I wonder if there is a better way in rake.
            # This will auto generate source prerequisites
            # from the specified FileSets when
            # they are demanded

        protected

            def resolvePrerequisites
                # TODO "the "####" and '#' flag thing is messy maybe :type in entry ??
                unless defined? @filesResolved_
                    @filesResolved_ = true;
                    contents = config.archiveContents_;

                    contents.each do |entry|
                        baseDir = entry[:baseDir];
                        spl = baseDir.split('###',2)
                        if(spl.length > 1)
                            @prerequisites << spl[0]
                        else
                            copySet = FileCopySet.new;
                            # for each entry add files to the copy set
                            if(baseDir=='#')
                                copySet.addFiles(entry[:destDir],entry[:files]);
                            else
                                copySet.addFileTree(entry[:destDir],baseDir,entry[:files]);
                            end
                            @prerequisites |= copySet.sources;
                            # replace file list in entry with the resolved copy set
                            entry[:files] = copySet if entry[:cacheList]
                        end
                    end
                end
            end

        public

            # Override of Rake::Task::prerequisite_tasks to return list of prerequisite tasks,
            # generated and cached upon first access.
            def prerequisite_tasks
                resolvePrerequisites unless defined? @filesResolved_
                prerequisites.collect { |pre| lookup_prerequisite(pre) }
            end

            # Override of Rake::FileTask::needed? this resolves all the specified source file lists
            # and adds them all as prerequisites to the task for which the purpose is to copy the sources into
            # a destination archive.
            def needed?
                resolvePrerequisites unless defined? @filesResolved_
                !File.exist?(name) || out_of_date?(timestamp);
            end
        end
    end

end # Rakish

