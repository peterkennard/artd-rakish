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

#             ### use persistent file for debugging
#             dir = "d:/ziptemp";
#             rm_rf dir;
#             mkdir_p dir;
#             cd dir do

            Dir.mktmpdir do |dir|

                FileUtils.cd dir do

                    cfg.loadTempDir(dir)

                    # ensure we have a place to put the new zip file in.
                    FileUtils.mkdir_p(t.name.pathmap('%d'));

                    cmdOpts = '-r9v';
                    unless cfg.verbose?
                        cmdOpts = cmdOpts.gsub!('v','');
                    end

                    cmdline = "zip #{cmdOpts} \'#{getRelativePath(t.name)}\' .";
                    execLogged(cmdline, :verbose=>cfg.verbose?);
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

end # Rakish
