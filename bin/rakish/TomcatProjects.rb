myPath = File.dirname(File.expand_path(__FILE__));
require "#{myPath}/JavaProjects.rb"

module Rakish


module TomcatProjectConfig
    include JavaProjectConfig
end

module WarBuilderModule
    include JarBuilderModule

    class WarBuilder < JarBuilder

        # create task for building jar file to specifications stored in builder.
        def warFileTask(*args)
            tsk = jarTask(*args);
            tsk
        end

        alias original_addFileTree addFileTree
        private :original_addFileTree

        def addFileTree(destdir, basedir, *files)
            original_addFileTree(destdir, basedir, *files);
            @jarContents_.last[:files].each do |file|
                puts("                 #{file}");
            end
        end

    end

    def createWarBuilder
        WarBuilder.new(self); # for now we make the parent project the parent config
    end

end

module TomcatProjectModule
    include TomcatProjectConfig
    include WarBuilderModule

protected

    addInitBlock do |pnt,opts|
        if(pnt != nil)
            @java_home = pnt.get(:java_home);
        end
        @java_home ||= File.expand_path(ENV['JAVA_HOME']);
    end

public

end

end # Rakish