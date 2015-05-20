myPath = File.dirname(File.expand_path(__FILE__));
require "#{myPath}/ArchiveBuilder.rb"

module Rakish


module ZipBuilderModule

    class ZipBuilder < ArchiveBuilder

    public

   	    def doBuildZipAction(t)
            cfg = t.config;

            puts("creating #{t.name}");

            # delete old archive file and liberate space ? zip when creating clears old file
            # FileUtils.rm_f t.name;

            # use persistent file for debugging
            # dir = "d:/ziptemp";
            # rm_rf dir;
            # mkdir_p dir;
            # cd dir

            Dir.mktmpdir do |dir|

                FileUtils.cd dir do

                    cfg.archiveContents_.each do |entry|

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

                    # ensure we have a place to put the new zip file in.
                    FileUtils.mkdir_p(t.name.pathmap('%d'));

#                    cmdOpts = 'cvfM';
#                    unless cfg.verbose?
#                        cmdOpts = cmdOpts.gsub('v','');
#                    end
#
#                    cmdline = "\"#{cfg.java_home}/bin/jar\" #{cmdOpts} \"#{getRelativePath(t.name)}\" .";
#                    execLogged(cmdline, :verbose=>cfg.verbose?);
                end
             # ruby seems to do this ok on windows and screws
             # up if I do due to thread latency in spawning the command or something.
             #       FileUtils.rm_rf dir;
            end
        end

        @@buildZipAction_ = ->(t) do
            t.config.doBuildZipAction(t);
        end

        # create task for building jar file to specifications stored in builder.
        def zipTask(*args)
            tsk = ArchiveTask.define_task(*args).enhance(nil,&@@buildZipAction_);
            tsk.config = self;
            tsk
        end

    end

    def createZipBuilder
        ZipBuilder.new(self); # for now we make the parent project the parent config
    end

end
