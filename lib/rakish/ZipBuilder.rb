myPath = File.dirname(File.expand_path(__FILE__));
require "#{myPath}/ArchiveBuilder.rb"

module Rakish

# module for including in projects that wish to build and output zip file archinves.
module ZipBuilderModule

    # Subclass of Rakish::ArchiveBuilder for creating zip files.
    class ZipBuilder < ArchiveBuilder

        addInitBlock do |pnt,opts|
			if(BASEHOSTTYPE =~ /Windows/)
                @@zipPath_ ||= "#{thirdPartyPath}/tools/msysgit/bin/zip.exe";
            else
                @@zipPath_ ||= 'zip'; # allow path to find it
            end
        end

    public

   	    def doBuildZipAction(t) # :nodoc:

            cfg = t.config;

            if(cfg.verbose?)
                puts("creating #{t.name} verbose=#{cfg.verbose}");
            end

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

                    cmdOpts = '-r9q';
                    if cfg.verbose?
                        cmdOpts = cmdOpts.gsub('q','v');
                    end

                    cmdline = "\"#{@@zipPath_}\" #{cmdOpts} \'#{t.name}\' .";
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

        # create task for building a zip file to specifications stored in this builder.
        def zipTask(*args)
            tsk = ArchiveTask.define_task(*args).enhance(nil,&@@buildZipAction_);
            tsk.config = self;
            tsk
        end
    end

    # Create a new zip builder for the including project's context
    def createZipBuilder
        ZipBuilder.new(self); # for now we make the parent project the parent config
    end

end

end # Rakish
