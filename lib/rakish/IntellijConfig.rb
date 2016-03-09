myDir = File.dirname(__FILE__);

require "#{myDir}/BuildConfig.rb";
require 'rexml/document';
require 'rexml/streamlistener'

module Rakish

    # Module to include in a 'root' Rakish.Configuration[link:./Rakish.html#method-c-Configuration]
    # to provide settings from an intellij idea invoked rakish build.
    module IntellijConfig

        class XMLListener # :nodoc:
            include Rakish::Util
            include REXML::StreamListener

            attr_accessor(:config)

            @@outPath = [ 'project', 'component', 'output' ];

            def initialize(config)
                @tagPath=[];
                @config=config;
                @skipping=nil;
            end

            def tag_start(name, attributes)
                @tagPath.push(name);
                if(@tagPath === @@outPath)
                    path = attributes['url'];
                    path = File.expand_path(path.sub('file://$PROJECT_DIR$',config.projectRoot));
                    config.outputPath = path;
                end
            end
            def tag_end(name)
                @tagPath.pop;
            end
        end

        # If non nil is a PropertyBag containing items parsed from the invoking intllij build.
        # This Works in concert with the call-rake.xml and script if used as an intellij ant script.
        #
        #  fields assigned:
        #     projectRoot - The path to the .idea folder of the invoking intellij project.
        #     outputPath  - The "Project compiler Output" path specified in the intellij settings.
        #
        def intellij
            @@intellij_;
        end

        class Globals < PropertyBag # :nodoc:
        	attr_property   :outputPath
        end

        def self.initGlobals # :nodoc:
            @@intellij_ = nil;

            if(ENV['IDEA_PROJECT'])

                @@intellij_ = Globals.new;
                ideaProject = ENV['IDEA_PROJECT'];
                ideaProject = File.expand_path(ideaProject);
                projectRoot = File.dirname(ideaProject);

                xmlPath = File.expand_path("#{ideaProject}/misc.xml");

                @@intellij_.enableNewFields do |cfg|
                    cfg.projectRoot = projectRoot;

                    listener = XMLListener.new(cfg);

                    parser = REXML::Parsers::StreamParser.new(File.new(xmlPath), listener)
                    parser.parse

                    log.debug("####### intellij output path is #{@@intellij_.outputPath}");
                end

            end

        end

        addInitBlock do |pnt,opts|
          #  log.debug("initializing intellij config");
            unless(defined? @@intellij_)
                IntellijConfig.initGlobals();
            end
        end
    end

end