myPath = File.dirname(File.expand_path(__FILE__));
require "#{myPath}/RakishProject.rb"
require 'tmpdir'


module Rakish

    class ArchiveBuilder < BuildConfig

    public
        attr_reader :archiveContents_

        addInitBlock do |pnt,opts|
            @archiveContents_ = [];

            if(BASEHOSTTYPE =~ /Windows/)
                @@unzipPath_ ||= "#{thirdPartyPath}/tools/msysgit/bin/unzip.exe";
            else
                @@unzipPath_ ||= '/bin/unzip';
            end

        end

        # archiveContents has these "fields"
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
            @archiveContents_ << entry;
        end

        # Adds all directory contents to root of jar file recursively
        # contents resolved when jar file task is invoked
        # filters - 0 or more selects files within the directory to put in the jar
        # with the wildcard path relative to the source directory
        # the default filer is all files in the dir.
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


        # set up task to extract contents from the given zip file, will apply filters
        # and add the extracted files/folders to the root of the
        # new archive recursively, the extraction is done when the
        # builder task is invoked.
        # filters - 0 or more selects files within the directory to put in the jar
        # with the wildcard path relative to the root of the source jar file
        # the default filter is all files in source jar.
        def addZipContents(archivePath,*filters)

            if(filters.length < 1)
               filters=['*'];
            end
            entry = {};
            entry[:destDir]=('.');
            entry[:baseDir]=("#{File.expand_path(archivePath)}###");
            entry[:files]=filters;
            @archiveContents_ << entry;
        end



        def loadTempDir(dir)

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

                    cmd = "\"#{@@unzipPath_}\" -q \"#{spl[0]}\" \"#{entry[:files].join("\" \"")}\" -x \"META-INF/*\" -d \"#{dir}\"";

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
        end


        class ArchiveTask < Rake::FileTask

            # I wonder if there is a better way in rake to auto generate prerequisites when
            # they are demanded
            def resolvePrerequisites
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
    end

end # Rakish

