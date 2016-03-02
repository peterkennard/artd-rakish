myPath = File.dirname(File.expand_path(__FILE__));
require "#{myPath}/BuildConfig.rb"

module Rakish

module RubydocModule
    include BuildConfigModule

protected

    addInitBlock do |pnt,opts|
        if(pnt != nil)
        end
    end

    class RubydocBuilder < BuildConfig
        include RubydocModule

        CreateRubydocAction = ->(t) do
            t.config.doBuildRubydocs(t);
        end

        def doBuildRubydocs(t)


            cd "#{t.config.projectDir}/../lib/rakish" do
                command = [ 'rdoc',
                            "--output=#{t.config.projectDir}/doc",
                          ];
                execLogged(command);
            end


        end

        def rubydocTask
            tsk = Task.define_unique_task &CreateRubydocAction;
            tsk.config = self;
            tsk
        end
    end

    def createRubydocBuilder
        RubydocBuilder.new(self);
    end

public

end

end # Rakish