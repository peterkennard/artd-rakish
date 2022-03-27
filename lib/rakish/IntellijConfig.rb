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

        class CompilerParser < XMLListener

            @@flagsPath = [ 'project', 'component', 'option' ];
            @@compPath = [ 'project', 'component' ];

            def tag_start(name, attributes)


                @tagPath.push(name);
                # log.debug(@tagPath.join("::"));
                if(@tagPath == @@compPath)
                    @compName = attributes['name'];
                elsif(@tagPath === @@flagsPath)
                   optName = attributes['name'];
                   if(@compName == 'JavacSettings' && optName == 'ADDITIONAL_OPTIONS_STRING')
                        config.javacFlags = attributes['value'];
                   end
                end
            end

        end




        # If non nil is a PropertyBag containing items parsed from the invoking intllij build.
        # This Works in concert with the call-rake.xml and script if used as an intellij ant script.
        #
        #  fields assigned:
        #     projectRoot - The path to the .idea folder of the invoking intellij project.
        #     outputPath  - The "Project compiler Output" path specified in the intellij settings.
        #     javacFlags  - "Extra Compiler Flags" from Java Compiler settings.
        #
        def intellij
            @@intellij_;
        end

        class Globals < PropertyBag # :nodoc:
        	attr_property   :outputPath
        	attr_property   :javacFlags
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

                    javacFlags="";

                    cfg.projectRoot = projectRoot;

                    listener = XMLListener.new(cfg);
                    parser = REXML::Parsers::StreamParser.new(File.new(xmlPath), listener)
                    parser.parse

                    xmlPath = File.expand_path("#{ideaProject}/compiler.xml");
                    if(File.file?(xmlPath)) do
                        listener = CompilerParser.new(cfg);
                        parser = REXML::Parsers::StreamParser.new(File.new(xmlPath), listener)
                        parser.parse
                    end

# this was what intellij wrote out by default before - they seem to have stopped doing it
# <?xml version="1.0" encoding="UTF-8"?>
# <project version="4">
#   <component name="CompilerConfiguration">
#     <resourceExtensions />
#     <wildcardResourcePatterns>
#       <entry name="!?*.java" />
#       <entry name="!?*.form" />
#       <entry name="!?*.class" />
#       <entry name="!?*.groovy" />
#       <entry name="!?*.scala" />
#       <entry name="!?*.flex" />
#       <entry name="!?*.kt" />
#       <entry name="!?*.clj" />
#       <entry name="!?*.aj" />
#     </wildcardResourcePatterns>
#     <annotationProcessing>
#       <profile default="true" name="Default" enabled="false">
#         <processorPath useClasspath="true" />
#       </profile>
#     </annotationProcessing>
#   </component>
# </project>

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