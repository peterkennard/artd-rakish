require 'rakish/CppProjects.rb'

module Rakish
    module RaspberiPiCppTools

        class RaspiTools
            include CTools

            # extension for pre linked object files
            # for consumers of CTools toolchain
            def objExt
                '.o'
            end
            # extension for static library files
            # for consumers of CTools toolchain
            def libExt
                '.a'
            end
            # extension for dynamic library files
            # for consumers of CTools toolchain
            def dllExt
                '.so'
            end
            # extension for executable files
            # for consumers of CTools toolchain
            def exeExt
                ''
            end

        # CC   = ${GCC}
        # CXX  = ${GCC} -x c++
        # AS   = as
        # LD   = cc -pthread
        # CPP  = ${GCC} -x c++ -E ${DEPINC}

            GccPath = '/usr/bin/gcc';

            def initialize
                @compileForSuffix = {};

                addCompileAction('.cpp', @@compileCPPAction);
                addCompileAction('.c', @@compileCAction);
            end

            # will format and cache into the config the /I and /D and other constant
            # compiler flags for the specific configuration and cache it in the configuration
            def getFormattedGccFlags(cfig)

                unless(cfl = cfig.getMy(:gccFlags_))
                    # if not cached build command line string
                    cfl = "";

                    if(false)
                        cfig.cflags.each do |cf|
                            cfl += (' ' + cf)
                        end
                    end

                    # format include paths
                    cfig.includePaths.each do |dir|
                        cfl += " -I \"#{dir}\"";
                    end

                    cfl += " -D\"ARTD_PLATFORM=Linux32\"";

                    # format CPP macro defs
                    cfig.cppDefines.each do |k,v|
                        cfl += " -D\"#{k}#{v ? '='+v : ''}\""
                    end
                    cfig.set(:gccFlags_,cfl)
                end
                cfl
            end


            def addCompileAction(suff,action)
                @compileForSuffix[suff] = action;
            end

            @@compileCPPAction = lambda do |t|
                t.config.ctools.doCompileCpp(t)
            end
            @@compileCAction = @@compileCPPAction;

            def doCompileCpp(t)

                cppFile = t.source;
                objFile = t.name;
                cfig = t.config;
                depname = objFile.pathmap('%X.d');

                cmdline =   "\"#{GccPath}\"  -pthread -x c++ -std=c++11 -fpic  -MT\"#{depname}\" -MMD -MP -MF \"#{depname}\" -Wall -pedantic -c ";
                cmdline += " -o\"#{objFile}\"";
                cmdline += getFormattedGccFlags(cfig);
                cmdline += " \"#{cppFile}\"";
                # log.debug("\n\t#{cmdline}");
                log.info cppFile.pathmap('%f');

                IO.popen(cmdline) do |output|
                    while line = output.gets do
                        log.info line.strip!
                    end
                end

                included = Rakish::FileSet.new

                File.open(depname) do |file|
                    file.each_line do |line|
                        line.strip!
                        if line.end_with?(':')
                            line.sub!(':','');
                            # line = line[0...(line.length-1)];
                            included << line
                        end
                    end
                end

                depfile = depname.ext('.raked');
                updateDependsFile(t,depfile,included);

            end

            @@buildLibAction = lambda do |t|
                t.config.ctools.doBuildLib(t)
            end
            def doBuildLib(t)

            end


            def resolveAndAddLibs(cmdline, cfg) 
                # add library search paths
                # eachof cfg.libpaths do |lpath|
                #	f.puts("-libpath:\"#{lpath}\"");
                # end
                
                # seems we can't specify libraries as an absolute path
      #         cmdline << "-L\"#{cfg.nativeLibDir}\" ";

                # libraries               
                testLibDir = Regexp.escape(cfg.nativeLibDir());

                testPrefix = "#{cfg.nativeLibDir}/";
                libs=[]
                libs << cfg.dependencyLibs
                libs.flatten.each do |lib|
                    lib.strip!();


                    if(File.path_is_absolute?(lib))
                        if(lib.start_with?(testPrefix)) 
                            lib = lib.slice(testPrefix.length, lib.length - testPrefix.length);
                        end      
                    end
                    cmdline += "-l \"#{lib}\" ";
                end
            end

            @@linkDllAction = lambda do |t|
                t.config.ctools.doLinkDll(t)
            end
            def doLinkDll(t)

                cfg = t.config;
                outpath = t.name;

			    writeLinkref(cfg,cfg.targetBaseName,outpath);

                log.info("linking shared lib #{outpath}");

                cmdline = "\"#{GccPath}\" -pthread -shared -shared-libgcc -Wl,-soname,\"#{outpath}\" -o \"#{outpath}\" ";

                resolveAndAddLibs(cmdline,cfg);                

                # object files
                objs=[]
                objs << t.sources[:userobjs];
                objs.flatten.each do |obj|
                    obj = obj.to_s
                    next unless obj.pathmap('%x') == '.o'
                    cmdline += "\"#{obj}\" ";
                end

                # log.debug("\n cmdline = #{cmdline}\n");

                system(cmdline);

        # @${LD} -Wl,-X -shared -o $@  \
        # $(filter-out ${FULL_LIBS}, $(filter %.so %.o,$^)) ${FULL_LIBS} ${XLIBS} \
        # -Wl,-rpath=${LIB_PATH} -Wl,-soname=lib${TARGET}.so

            end

            @@linkAppAction = lambda do |t|
                t.config.ctools.doLinkApp(t)
            end
            def doLinkApp(t)

                cfg = t.config;
                outpath = t.name;

                log.info("linking application #{outpath}");

                cmdline = "\"#{GccPath}\" -pthread -shared -shared-libgcc  -o \"#{outpath}\" ";

                resolveAndAddLibs(cmdline,cfg);                

                # object files
                objs=[]
                objs << t.sources[:userobjs];
                objs.flatten.each do |obj|
                    obj = obj.to_s
                    next unless obj.pathmap('%x') == '.o'
                    cmdline += "\"#{obj}\" ";
                end

                # log.debug("\n cmdline = #{cmdline}\n");

                system(cmdline);

        # @${LD} -Wl,-X -shared -o $@  \
        # $(filter-out ${FULL_LIBS}, $(filter %.so %.o,$^)) ${FULL_LIBS} ${XLIBS} \
        # -Wl,-rpath=${LIB_PATH} -Wl,-soname=lib${TARGET}.so

            end

            # for consumers of CTools toolchain
            def getCompileActionForSuffix(suff)
                @compileForSuffix[suff]
            end

            # for consumers of CTools toolchain
            def initCompileTask(cfg)
                ensureDirectoryTask(cfg.moduleConfiguredObjDir);
                cfg.project.addCleanFiles("#{cfg.moduleConfiguredObjDir}/*#{objExt()}",
                                         "#{cfg.moduleConfiguredObjDir}/*.d"
                                        );
                Rake::Task.define_task :compile => [:includes,
                                                cfg.moduleConfiguredObjDir,
                                                :depends]
            end

            @@resolveLinkAction_ = lambda do |t|
            end

            # for consumers of CTools toolchain
            def createLinkTask(objs,cfg)

                case(cfg.targetType)

                    when 'APP'

                        targetName = "#{cfg.binDir()}/#{cfg.targetName}";

    #					resobjs = getAutoResourcesObjs(cfg)
    #					mapfile = targetName.pathmap("%X.map");
    #					pdbfile = targetName.pathmap("%X.pdb");
    #					cfg.project.addCleanFiles(mapfile,pdbfile);

                        doLink = Rake::FileTask.define_task targetName => [], &@@linkAppAction;
                        doLink.sources = {
                            :userobjs=>objs,
    #						:autores=>resobjs,
    #						:mapfile=>mapfile,
    #						:pdbfile=>pdbfile,
                        }

                    when 'LIB'

                        targetName = "#{cfg.nativeLibDir()}/#{cfg.targetName}.a";
                        doLink = Rake::FileTask.define_task targetName,
                                &@@buildLibAction;

                    when 'DLL'

                        targetName = "#{cfg.nativeLibDir()}/#{cfg.configName}/lib#{cfg.targetName}.so";

                        # resobjs = getAutoResourcesObjs(cfg)

                        # mapfile = targetName.pathmap("%X.map");
                        # pdbfile = targetName.pathmap("%X.pdb");
                        # implib = "#{cfg.binDir()}/#{cfg.targetName}.lib";

                        # cfg.project.addCleanFiles(mapfile,pdbfile,implib);

                        doLink = Rake::FileTask.define_task targetName => [], &@@linkDllAction;
                        doLink.sources = {
                            :userobjs=>objs,
                            # :autores=>resobjs,
                            # :mapfile=>mapfile,
                            # :pdbfile=>pdbfile,
                            # :implib=>implib
                        }

                    else
                        log.info("unsupported target type #{cfg.targetType}");
                        return(false);
                end

                cfg.project.addCleanFiles(targetName);

                doLink.config = cfg;
                doLink.enhance(objs);

                # create a "setup" task to resolve everything and set up the link.
                tsk = task "#{cfg.targetName}.#{cfg.targetType}.resolve", &@@resolveLinkAction_;
                tsk.config = doLink;

                { :setupTasks=>tsk, :linkTask=>doLink } # note this returns a hash !!
            end
        end
 
        def self.getConfiguredTools(configName,args={})
            return(RaspiTools.new());
        end

    end

end
