myPath = File.dirname(File.expand_path(__FILE__));
require "#{myPath}/BuildConfig.rb"

module Rakish

# Nacent project inclusion module for invoking Rdoc
module RubydocModule
    include BuildConfigModule

protected

    addInitBlock do |pnt,opts|
        if(pnt != nil)
        end
    end

    class RubydocBuilder < BuildConfig
        include RubydocModule


        def doBuildRubydocs(t) # :nodoc:


            cd "#{t.config.projectDir}/../lib/rakish" do
                command = [ 'rdoc',
                            "--output=#{t.config.projectDir}/rdoc",
                          ];
                execLogged(command);
            end


        end

        # create task to invoke Rdoc to the specifications in this builder.
        def rubydocTask
            tsk = Rake::Task.define_unique_task &CreateRubydocAction;
            tsk.config = self;
            tsk
        end

        # action for rdoc task.
        # :nodoc:
        CreateRubydocAction = ->(t,args) do
            t.config.doBuildRubydocs(t);
        end

    end

    # Creates a RubydocBuilder for the including project's configuration
    def createRubydocBuilder
        RubydocBuilder.new(self);
    end

public

end

end # Rakish