myDir = File.dirname(__FILE__);
unless defined? BUILD_OPTIONS_LOADED
    MAKEDIR=File.expand_path("#{myDir}");
end

require "#{myDir}/BuildConfig.rb";
require 'rexml/document';
require 'rexml/streamlistener'

module Rakish

    module IntellijConfig

        class XMLListener
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

        def intellij
            @@intellij_;
        end

        class Globals < PropertyBag
        	attr_property   :outputPath
        end

        def self.initGlobals
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