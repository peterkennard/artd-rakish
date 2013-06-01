module Rakish

	module PlatformTools
		
		module WindowsToolsFactory

			class Tools < ToolsBase

				@@makeManifestAction = lambda do |t|
					t.config.tools.doMakeManifest(t)
				end
				def doMakeManifest(t)
					puts("Generating #{File.basename(t.name)}");
					data = t.data;
					cp(@ManifestSource, data[:txt],:verbose => false) 
					File.open(t.name,'w') do |f|
						f.puts "#include <windows.h>"						
						if(@BASELINKAGE === 'Dynamic' && t.config.isLibrary)
							id = 'ISOLATIONAWARE_MANIFEST_RESOURCE_ID'
						else
							id = 'CREATEPROCESS_MANIFEST_RESOURCE_ID'
						end		
						f.puts "#{id} RT_MANIFEST \"#{File.basename(data[:txt])}\""
					end
				end
				
				def compileRcFile(cfg,rc,res)
					cmdline = "\"#{@RC_EXE}\" -nologo -I\"#{cfg.thirdPartyPath}/tools/winsdk/include\""
					cmdline += " -I\"#{cfg.thirdPartyPath}/tools/msvc9/include\""
					cmdline += " -I\"#{cfg.thirdPartyPath}/tools/msvc9/atlmfc/include\""
					cmdline += " -fo\"#{res}\"  \"#{rc}\""
					system cmdline
				end

				def compileResFile(cfg,res,obj)
					cmdline = "\"#{@CVTRES_EXE}\" #{@MACHINE_SPEC} -nologo -out:\"#{obj}\" \"#{res}\""
					system(cmdline)
				end

				def getAutoResourcesObjs(cfg)

					resobjs=[]
					rcobjs=[]
					basePath = File.join(cfg.OBJPATH,cfg.baseName);
					
					if(@ManifestSource) # not present if not needed
						manifest_rc = "#{basePath}.manifest.rc"
						tsk = lookupTask(manifest_rc)
						unless(tsk)
							manifest_txt = "#{basePath}.manifest"							
							# manifest resource
							cfg.project.addCleanFiles(manifest_rc,manifest_txt);
												
							tsk = Rake::FileTask.define_task manifest_rc => [ cfg.OBJPATH, cfg.projectFile, @ManifestSource ]
							tsk.enhance &@@makeManifestAction;
							tsk.config = cfg
							tsk.data = { :txt=>manifest_txt }
						end
						rcobjs <<= tsk
					end	

					autores_obj = "#{basePath}.resources.obj"
					tsk = lookupTask(autores_obj)
					unless(tsk)
						autores_rc = "#{basePath}.resources.rc"
						autores_res = "#{basePath}.resources.res"

						cfg.project.addCleanFiles(autores_rc,autores_res,autores_obj);
						
						restask = Rake::FileTask.define_task autores_obj => [ cfg.OBJPATH, cfg.projectFile, rcobjs].flatten do |t|
							puts("Generating #{t.name}")
							File.open(autores_rc,'w') do |f|
								t.sources.each do |src|
									f.puts("#include \"#{File.basename(src.to_s)}\"")
								end
							end
							compileRcFile(cfg,autores_rc,autores_res);
							compileResFile(cfg,autores_res,t.name);
						end
						restask.sources = rcobjs;
						resobjs <<= restask;
					end	
					return(resobjs)
				end
				
				
			
				def createLibraryTarget(config)
						
					ensureDirectoryTask(config.BINDIR());

					targetName = "#{config.baseName}-#{config.OUTPUT_SUFFIX}"
		
					if(config.SHARED_LIBRARY)

						#LIBS_DEP_WINDOWS := $(subst $(THIRD_PARTY_PATH),$(THIRD_PARTY_PATH),$(THIRD_PARTY_LIB_FILES) $(SPECIFIC_LIBS))
						#$(TARGET_FILE): $(OBJS) $(STATIC_LIB_FILES) $(AUTORESOURCES_OBJ) $(LIBS_DEP_WINDOWS)

						resobjs = getAutoResourcesObjs(config)
						tpath = File.join(config.BINDIR(),targetName+'.dll');
						mapfile = tpath.pathmap("%X.map");
						pdbfile = tpath.pathmap("%X.pdb");
						implib = File.join(config.LIBDIR(),targetName+'.lib')
						
						config.project.addCleanFiles(mapfile,pdbfile,implib);

						targ = Rake::FileTask.define_task tpath => [ :compile, config.LIBDIR(), config.BINDIR(), resobjs].flatten
						targ.enhance &@@linkDllAction;
						targ.sources = { 
							:autores=>resobjs, 
							:mapfile=>mapfile,
							:pdbfile=>pdbfile,
							:implib=>implib
						}
					else
						tpath = File.join(config.LIBDIR(),targetName+'.lib');							
						targ = Rake::FileTask.define_task tpath => [ :compile, config.LIBDIR(), config.BINDIR()]
						targ.enhance &@@buildLibAction;
					end
					targ.config = config;
					targ
				end
				
				def createExeTarget(config)
						
					isolationAware = false;	
						
					targetName = "#{config.baseName}-#{config.CPP_CONFIG}"
					tpath = File.join(config.BINDIR,targetName+'.exe');
					
					ensureDirectoryTask(config.BINDIR);
					resobjs = getAutoResourcesObjs(config)
					mapfile = tpath.pathmap("%X.map");
					pdbfile = tpath.pathmap("%X.pdb");
					config.project.addCleanFiles(mapfile,pdbfile);

					targ = Rake::FileTask.define_task tpath => [ :compile, config.BINDIR, resobjs ].flatten

					targ.enhance &@@linkAppAction;
					targ.config = config;
					targ.sources = { 
						:autores=>resobjs, 
						:mapfile=>mapfile,
						:pdbfile=>pdbfile,
					}
					targ
				end
								
			end # class Tools
		end
	end	
end
