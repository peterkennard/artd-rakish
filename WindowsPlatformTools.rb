module Rakish

	module PlatformTools
		
		module WindowsToolsFactory

			class Tools < ToolsBase

				
				VALID_DEBUGTYPES = { 
					'Debug'=>true,
					'Release'=>true,
					'Checked'=>true
				};

				VALID_LINKTYPES = { 
					'MT'=>true,
					'MTd'=>true,
					'MD'=>true,
					'MDd'=>true
				};
				
				VALID_COMPILERS = { 
					'VC5'=>true,
					'VC6'=>true,
					'VC7'=>true, 
					'VC8'=>true, 
					'VC9'=>true, 
					'VC10'=>true,
					'ICL'=>true
				};
				
				
				@@globalInit = nil;
				
				def initialize(parsed,cfgStr)
				
					splitcfgs = parsed[:split];
					config = cfgStr;
					
					platform  = splitcfgs[0];
					platformType = parsed[:platformType];
					platformBits = parsed[:platformBits];

					cfgs = validateConfig(splitcfgs);
					compiler  = cfgs[:compiler];
					linkType  = cfgs[:linkType];
					debugType = cfgs[:debugType];
					
					tpp 	  = config.thirdPartyPath;
								
					# initialize global config items
					unless(@@globalInit)
					
						@@globalInit = true;
						cfg = GlobalConfig.instance;
					
						cfg.enableNewFields() do |cfg|
                            cfg.platform     = platform;
							cfg.platformType = platformType;
                            cfg.platformBits = platformBits;
                            cfg.compiler    = compiler;
                            cfg.linkType    = linkType;
                            cfg.debugType   = debugType;
                        end
                        
						cfg.addIncludePaths(
							"#{tpp}/include/Win32",
							"#{tpp}/include"
						);
						cfg.cppDefine(
							'ARTD_WINDOWS=',						
							'WIN32', 
							'_LIB', 
							'WINVER=0x0501', 
							'_WIN32_WINNT=0x0501', 
							'_WIN32_WINDOWS=0x0410', 
							'_WIN32_IE=0x0600',
							'_WINDOWS',
							'_USRDLL',
							'_FILE_OFFSET_BITS=64', 
							'_CRT_SECURE_NO_DEPRECATE', 
							'_CRT_NONSTDC_NO_DEPRECATE',
							'_MBCS',
							'_UNICODE', 
							'UNICODE',
							'NOMINMAX',
							'_SCL_SECURE_NO_WARNINGS', 
							'STRSAFE_NO_DEPRECATE'
						);
					end

					config.cppDefine(
                        "ARTD_PLATFORMTYPE=#{platformType}",
                        "ARTD_PLATFORMBITS=#{platformBits}",
						"ARTD_COMPILERTYPE=#{compiler}",
						"ARTD_LINKAGETYPE=#{linkType}",
						"ARTD_DEBUGTYPE=#{debugType}"
					);
	
					cppOpts = ' -nologo';
					cppWarnings = '';
					linkOpts = '';
					sdkLibs = [];
					
					case(platformBits)
					when '32'
						machineSpec = '-machine:x86';
					when '64'
						machineSpec = '-machine:x64';
					end

					# if ($(WINDOWS_CLR),1)
					#	CPP_OPTIONS += -clr -EHa 
					# else
						cppOpts += ' -EHsc'
					# end

					linkOpts += "#{machineSpec} -incremental:no -release -ignore:4089 -ignore:4049 -ignore:4217 -ignore:4248"

					case(debugType)
					when 'Debug'
						cppOpts += ' -Zi -Od'
						linkOpts += ' -debug -nodefaultlib'
					when 'Checked'
						cppOpts += ' -Zi -Ox'
						linkOpts += ' -debug -nodefaultlib'
					when 'Release'
						linkOpts += ' -nodefaultlib'
						cppOpts += ' -O3 -Qprec-div-'
					when 'ICL'
						cppOpts += ' -O3 -Qprec-div-'
					else
						cppOpts += ' -Ox'
					end
					
#					CPP_OPTIONS_DEBUG := -Zi
	#				LINK_OPTIONS_DEBUG := -debug
	#
	#				ifeq ($(WINDOWS_CLR),1)
	#					LINK_OPTIONS += -dynamicbase -nxcompat 
	#					LINK_OPTIONS_DEBUG += -assemblydebug
	#				endif
	#
	#				ifeq ($(DEBUGTYPE),Debug)
	#					CPP_OPTIONS += $(CPP_OPTIONS_DEBUG) -Od
	#					LINK_OPTIONS += -nodefaultlib $(LINK_OPTIONS_DEBUG)
	#					SDK_LIB += chkstk.obj
	#					DEBUGTYPEREF := Debug
	#				endif
	#				ifeq ($(DEBUGTYPE),Checked)
	#					CPP_OPTIONS += $(CPP_OPTIONS_DEBUG) -Ox
	#					LINK_OPTIONS += -nodefaultlib $(LINK_OPTIONS_DEBUG)
	#					DEBUGTYPEREF := Release
	#				endif
	#				ifeq ($(DEBUGTYPE),Release)
	#					ifeq ($(COMPILER),ICL)
	#						CPP_OPTIONS += -O3 -Qprec-div-
	#					else
	#						CPP_OPTIONS += -Ox
	#					endif
	#					LINK_OPTIONS += -nodefaultlib
	#					DEBUGTYPEREF := Release
	#				endif
	#				ifeq ($(COMPILER),ICL)
	#					COMPILERREF := VC8
	#				else
	#					COMPILERREF := $(COMPILER)
	#				endif
			
					cppWarnings = ' -W3'
					case(compiler)
					when 'VC9'
					when 'VC10'
					else
						cppWarnings += ' -Wp64'
					end

					case(linkType)
					when 'MT'
						@BASELINKAGE = 'Static'
						cppOpts += " -MT"
						config.cppDefine( 'NDEBUG','_MT');
						sdkLibs << 'libcmt.lib'
						sdkLibs << 'libcpmt.lib'
					when 'MTd'
						@BASELINKAGE = 'Static'
						cppOpts += " -MTd"
						config.cppDefine( '_DEBUG','_MT');
						sdkLibs << 'libcmtd.lib'
						sdkLibs << 'libcpmtd.lib'
					#	DEBUG_CRT := 1
					when 'MD'
						@BASELINKAGE = 'Dynamic'
						cppOpts += " -MD"
						config.cppDefine( 'NDEBUG', '_MT', '_DLL');
						sdkLibs << 'msvcrt.lib'
					#	ifeq ($(WINDOWS_CLR),1)
					#		sdkLibs << 'msvcmrt.lib'
					#	end
						sdkLibs << 'msvcprt.lib'
					when 'MDd'
						@BASELINKAGE = 'Dynamic'
						cppOpts += " -MDd"
						config.cppDefine( '_DEBUG', '_MT', '_DLL');
						sdkLibs << 'msvcrtd.lib'
					#	ifeq ($(WINDOWS_CLR),1)
					#		sdkLibs << 'msvcmrtd.lib'
					#	end
						sdkLibs << 'msvcprtd.lib'
					#	DEBUG_CRT := 1
					end
					
 					if(debugType === 'Debug')
					#	ifeq ($(DEBUG_CRT),1)
					#		ifneq ($(WINDOWS_CLR),1)
					#			cppOpts += " -RTC1"
					#		end
					#		cppOpts += " -Gs0"
					#	end
 					end
 
					unless(compiler === 'VC6')
						# cppOpts += " -showIncludes"
						case(linkType)
						when 'MT'
							sdkLibs << 'atls.lib'
							sdkLibs << 'comsuppw.lib'
						when 'MTd'
							sdkLibs << 'atlsd.lib'
							sdkLibs << 'comsuppwd.lib'
						
						whe 'MD'
							sdkLibs << 'atls.lib'
							sdkLibs << 'comsuppw.lib'
						when 'MDd'
							sdkLibs << 'atlsd.lib'
							sdkLibs << 'comsuppwd.lib'
						end
					end
								
					unless(compiler === 'VC7')
						cppOpts += " -bigobj"
					end

					# select tool executables and OS sdk library paths
					case(compiler)
					when 'VC6'
						@CVTRES_EXE = "#{tpp}/tools/msvc6/bin/cvtres.exe"
						@MSVC_EXE = "#{tpp}/tools/msvc6/bin/cl.exe"
						@LINK_EXE = "#{tpp}/tools/msvc6/bin/link.exe"

						cppOpts += " -GX";						
						cppOpts += " -I#{tpp}/tools/msvc6/include";
						cppOpts += " -I#{tpp}/tools/msvc7/include";
						cppOpts += " -I#{tpp}/tools/msvc8/include";
						cppOpts += " -libpath:#{tpp}/tools/msvc6/lib";
					when "VC7"
						@CVTRES_EXE = "#{tpp}/tools/msvc7/bin/cvtres.exe"
						@MSVC_EXE ="#{tpp}/tools/msvc7/bin/cl.exe"
						@LINK_EXE = "#{tpp}/tools/msvc7/bin/link.exe"

						cppOpts += " -GX"
						cppOpts += " -I\"#{tpp}/tools/msvc7/include\""
						cppOpts += " -I\"#{tpp}/tools/msvc7/atlmfc/include\""
						linkOpts += " -libpath:\"#{tpp}/tools/msvc7/lib\""
						linkOpts += " -libpath:\"#{tpp}/tools/msvc7/atlmfc/lib\""
					when "VC8"
						@CVTRES_EXE = "#{tpp}/tools/msvc8/bin/cvtres.exe"
						cppOpts += " -I\"#{tpp}/tools/msvc8/include\""
						cppOpts += " -I\"#{tpp}/tools/msvc8/atlmfc/include\""

						if(platform === "Win32")
							@MSVC_EXE ="#{tpp}/tools/msvc8/bin/cl.exe"
							@LINK_EXE = "#{tpp}/tools/msvc8/bin/link.exe"
							@LIB_EXE = "#{tpp}/tools/msvc8/bin/lib.exe"
							
							linkOpts += " -libpath:\"#{tpp}/tools/msvc8/lib\""
							linkOpts += " -libpath:\"#{tpp}/tools/msvc8/atlmfc/lib\""
						else
							@MSVC_EXE ="#{tpp}/tools/msvc8/bin/x86_x64/cl.exe"
							@LINK_EXE = "#{tpp}/tools/msvc8/bin/x86_x64/link.exe"
							linkOpts += " -libpath:\"#{tpp}/tools/msvc8/lib/x64\""
							linkOpts += " -libpath:\"#{tpp}/tools/msvc8/atlmfc/lib/amd64\""
						end
					when "VC9"
						@CVTRES_EXE = "#{tpp}/tools/msvc9/bin/cvtres.exe"
						cppOpts += " -I\"#{tpp}/tools/msvc9/include\""
						cppOpts += " -I\"#{tpp}/tools/msvc9/atlmfc/include\""
						if(platform === "Win32")
							@MSVC_EXE = "#{tpp}/tools/msvc9/bin/cl.exe"
							@LINK_EXE = "#{tpp}/tools/msvc9/bin/link.exe"
							linkOpts += " -libpath:\"#{tpp}/tools/msvc9/lib\""
							linkOpts += " -libpath:\"#{tpp}/tools/msvc9/atlmfc/lib\""
						else
							@MSVC_EXE = "#{tpp}/tools/msvc9/bin/x86_amd64/cl.exe"
							@LINK_EXE = "#{tpp}/tools/msvc9/bin/x86_amd64/link.exe"
							linkOpts += " -libpath:\"#{tpp}/tools/msvc9/lib/amd64\""
							linkOpts += " -libpath:\"#{tpp}/tools/msvc9/atlmfc/lib/amd64\""
						end
					when "VC10"
						@CVTRES_EXE = "#{tpp}/tools/msvc10/bin/cvtres.exe"
						cppOpts += " -I\"#{tpp}/tools/msvc10/include\""
						cppOpts += " -I\"#{tpp}/tools/msvc10/atlmfc/include\""
						if(platform === "Win32")
							@MSVC_EXE = "#{tpp}/tools/msvc10/bin/cl.exe"
							@LINK_EXE = "#{tpp}/tools/msvc10/bin/link.exe"
							linkOpts += " -libpath:\"#{tpp}/tools/msvc10/lib\""
							linkOpts += " -libpath:\"#{tpp}/tools/msvc10/atlmfc/lib\""
						else
							@MSVC_EXE = "#{tpp}/tools/msvc10/bin/x86_amd64/cl.exe"
							@LINK_EXE = "#{tpp}/tools/msvc10/bin/x86_amd64/link.exe"
							linkOpts += " -libpath:\"#{tpp}/tools/msvc10/lib/amd64\""
							linkOpts += " -libpath:\"#{tpp}/tools/msvc10/atlmfc/lib/amd64\""
						end
					end
					@RC_EXE =  "#{tpp}/tools/winsdk/bin/rc.exe"
					
					# items from appropriate windows SDKs
					cppOpts += " -I\"#{tpp}/tools/winsdk/Include\""
					
					if(platform === "Win32")
						sdkLibPath = "#{tpp}/tools/winsdk/lib"
					else
						sdkLibPath = "#{tpp}/tools/winsdk/lib/x64"
					end
					linkOpts += " -libpath:\"#{sdkLibPath}\""
			
					sdkLibs << 'oldnames.lib';
					
					[
						'gdi32.lib',
						'glu32.lib',
						'kernel32.lib',
						'ole32.lib',
						'opengl32.lib',
						'rpcrt4.lib',
						'shell32.lib',
						'user32.lib',
						'winmm.lib',
						'strmiids.lib',
						'uuid.lib',
						'ws2_32.lib',
						'wsock32.lib',
						'advapi32.lib',
						'comdlg32.lib',
						'comctl32.lib',
						'oleaut32.lib',
						'winhttp.lib',
						'quartz.lib',
						'dsound.lib',
						'userenv.lib',
						'wldap32.lib',
						'shlwapi.lib',
						'version.lib',
						'netapi32.lib',
						'usp10.lib',
						'psapi.lib',
						'msimg32.lib',
						'wininet.lib',
						'winspool.lib',
						'odbc32.lib',
						'odbccp32.lib',
						'crypt32.lib',
						'secur32.lib',
						't2embed.lib',
						'setupapi.lib',
						'dbghelp.lib',
						'cryptui.lib'
					].each do |lib|
						sdkLibs << File.join(sdkLibPath,lib);
					end

					includesManifest = true;
					case(compiler)
					when "VC8"
						@ManifestSource = "#{tpp}/tools/msvc8/manifest/#{platform}-#{linkType}.manifest"
						linkOpts += " -manifest:no"
					when "VC9"
						@ManifestSource = "#{tpp}/tools/msvc9/manifest/#{platform}-#{linkType}.manifest"
						linkOpts += " -manifest:no"
					when "VC10"
						@ManifestSource = "#{tpp}/tools/msvc10/manifest/#{platform}-#{linkType}.manifest"
						linkOpts += " -manifest:no"
					when "ICL"
						@ManifestSource = "#{tpp}/tools/msvc8/manifest/#{platform}-#{linkType}.manifest"
						linkOpts += " -manifest:no"
					else
						includesManifest = false;
					end
										
					@CPP_OPTIONS 	= cppOpts;
					@CPP_WARNINGS 	= cppWarnings;
					@SDK_LIBS 		= sdkLibs;
					@LINK_OPTS 		= linkOpts;
					@MACHINE_SPEC 	= machineSpec;
					
				end # initialize
				
				# will format and cache into the config the /I and /D and other constant
				# compiler flags for the spcific configuration and cache it in the configuration
				def getFormattedMSCFlags(cfig)
											
					unless(cfl = cfig.getMy(:msvcFlags_))			
						# if not cached build command line string
						cfl = @CPP_OPTIONS;
						cfl += @CPP_WARNINGS;
						
						cfig.cflags.each do |cf|
							cfl += (' ' + cf)
						end

						# format include paths
						cfig.incPaths.each do |dir| 
							cfl += " /I\"#{dir}\"";
						end
						
						# format CPP macro defs
						cfig.defines.each do |k,v| 
							cfl += " /D\"#{k}#{v ? '='+v : ''}\""
						end
						cfig.set(:msvcFlags_,cfl)
					end
					cfl					
				end
								
				@@compileCPPAction = lambda do |t|
					t.config.tools.doCompileCpp(t)
				end
				@@compileCAction = @@compileCPPAction;
				def doCompileCpp(t)

					cppfile = t.source;
					objfile = t.name;
					cfig = t.config;

					cmdline = "\"#{@MSVC_EXE}\" \"#{cppfile}\" -Fd\"#{cfig.OBJDIR}/vc80.pdb\" -c -Fo\"#{objfile}\" "; 
					cmdline += getFormattedMSCFlags(cfig)
					cmdline += ' /showIncludes'

					puts("\n#{cmdline}\n") if(cfig.verbose?) 
					included = Rakish::FileSet.new
					
					IO.popen(cmdline) do |output| 
						while line = output.gets do
							if line =~ /^Note: including file: +/
								line = $'.strip.gsub(/\\/,'/')
								next if( line =~ /^[^\/]+\/Program Files\/Microsoft /i )
								included << line
								next
							end
							puts line
						end
					end
					
					depfile = objfile.ext('.raked');
					updateDependsFile(t,depfile,included);
				end
				
				addCompileAction('.cpp', @@compileCPPAction);
				addCompileAction('.c', @@compileCAction);
				
				# platform specific file extensions
				def OBJEXT
					'.obj'
				end	
				def LIBEXT 
					'.lib'
				end
				def DLLEXT 
					'.dll'
				end
				def EXEEXT 
					'.exe'
				end

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
				
				@@buildLibAction = lambda do |t|
					t.config.tools.doBuildLib(t)
				end
				def doBuildLib(t)

					cfg = t.config;
					
					#STATIC_LIB_FILES += $(addsuffix .lib,$(call GET_REFERENCES,$(STATIC_LIBS),$(OUTPUT_PATH)))
					#SHARED_LIBS_FILES := $(addsuffix .lib,$(call GET_REFERENCES,$(SHARED_LIBS),$(OUTPUT_PATH)))
					#
					#$(TARGET_FILE): $(OBJS) $(STATIC_LIB_FILES)
				
					# assemble a static library 
					puts("linking #{File.basename(t.name)}")
					deleteFile(t.name)
					writeLinkref(cfg,cfg.baseName,t.name);
					lnkfile = t.name.pathmap("#{cfg.OBJPATH}/%f.response");

					#	echo -n $(PROJECT_TARGET_NAME)-$(OUTPUT_SUFFIX) > $(TARGET_REF)
					#	@echo -n "$(CPP_OBJS_BASE) $(C_OBJS_BASE)" > $(TARGET_LOBJ)

					File.open(lnkfile,'w') do |f|
						
						f.puts("#{@LIB_OPTIONS} -nodefaultlib -out:\"#{t.name}\"" );
							
						# object files
						objs = cfg.objs
						objs.flatten.each do |obj|
							obj = obj.to_s
							next unless obj.pathmap('%x') == '.obj' 
							f.puts("\"#{obj}\"");
						end		
						# library files
					#	@echo -n " $(STATIC_LIB_FILES) $(SHARED_LIBS_FILES)" >> $(TARGET_LNK)
					end
					cmdline = "\"#{@LINK_EXE}\" -lib -nologo @#{lnkfile}\""
					system( cmdline );
				end
				
				@@linkDllAction = lambda do |t|
					t.config.tools.doLinkDll(t)
				end
				def doLinkDll(t)
					
					# link a dynamic library
					cfg = t.config;
					
					puts("linking #{File.basename(t.name)}")					
					#	rm -f $(TARGET_FILE) $(TARGET_REF) $(TARGET_LOBJ); \
					deleteFile(t.name);
					writeLinkref(cfg,cfg.baseName,t.sources[:implib]);
					#	@echo -n "$(CPP_OBJS_BASE) $(C_OBJS_BASE)" > $(TARGET_LOBJ)

					lnkfile = t.name.pathmap("#{cfg.OBJPATH}/%f.response");
					
					# build linker source file
					begin

						#STATIC_LIB_FILES += $(addprefix $(OUTPUT_PATH)/,$(addsuffix -$(UNVERSIONED_SUFFIX).lobj,$(STATIC_LIBS)))
						#SHARED_LIBS_FILES := $(addsuffix .lib,$(call GET_REFERENCES,$(SHARED_LIBS),$(OUTPUT_PATH)))
						#

						File.open(lnkfile,'w') do |f|
							f.puts("-map:\"#{t.sources[:mapfile]}\"");
							f.puts("-pdb:\"#{t.sources[:pdbfile]}\"");
							f.puts("-implib:\"#{t.sources[:implib]}\"");
							f.puts("-DLL #{@LINK_OPTS}");

							# library search paths
							eachof cfg.libpaths do |lpath|
								f.puts("-libpath:\"#{lpath}\"");
							end
							
							# libraries							
							libs=[]
						
							# $(SHARED_LIBS_FILES) 
							# $(THIRD_PARTY_LIB_FILES) 
							# $(SPECIFIC_LIBS) 
							# $(EXTRA_LIBS_WINDOWS) 
							libs << @SDK_LIBS;
							libs << cfg.libs
							libs.flatten.each do |obj|
								f.puts("\"#{obj}\"");
							end
							
							f.puts("-nodefaultlib -out:\"#{t.name}\"");
							
							# object files
							objs = [cfg.objs]
							objs <<= t.sources[:autores];
							objs.flatten.each do |obj|
								obj = obj.to_s
								next unless obj.pathmap('%x') == '.obj' 
								f.puts("\"#{obj}\"");
							end			
							# static libs
							#	@$(PARSEREF) --spaces --prepend $(OUTPUT_PATH)/ $(STATIC_LIB_FILES) >> $(TARGET_LNK)
						end
					rescue => e
						puts("error precessing: #{lnkfile} #{e}")			
						raise e
					end
					
					cmdline = "\"#{@LINK_EXE}\" -nologo @\"#{lnkfile}\"";					
					puts(cmdline) if(cfg.verbose?)
					system( cmdline );
					
					#ifeq ($(RUN_SIGNTOOL),1)
					#	@echo "Signing $(notdir $(TARGET_FILE))"; \
					#	$(SIGNTOOL_EXE) -in $(TARGET_FILE) -out $(TARGET_FILE).signed
					#	@rm $(TARGET_FILE); \
					#	mv $(TARGET_FILE).signed $(TARGET_FILE)
					#endif
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
				@@linkAppAction = lambda do |t|
					t.config.tools.doLinkApp(t)
				end
				def doLinkApp(t)

					cfg = t.config;
					# assemble a static library 
					puts("linking #{File.basename(t.name)}")
					
					deleteFile(t.name);
					lnkfile = t.name.pathmap("#{cfg.OBJPATH}/%f.response");
					
					# build linker source file
					begin
						File.open(lnkfile,'w') do |f|
							f.puts("-out:\"#{t.name}\"");
							f.puts("-map:\"#{t.sources[:mapfile]}\"");
							f.puts("-pdb:\"#{t.sources[:pdbfile]}\"");							
							f.puts("#{@LINK_OPTS}");
	
							# object files
							objs=[]
							objs << cfg.objs
							objs <<= t.sources[:autores];
							objs.flatten.each do |obj|
								obj = obj.to_s
								next unless obj.pathmap('%x') == '.obj' 
								f.puts("\"#{obj}\"");
							end			
														
							libs=[]
							libs << @SDK_LIBS;
							libs << cfg.libs
							libs.flatten.each do |obj|
								f.puts("\"#{obj}\"");
							end
						end
					rescue => e
						puts("error precessing: #{lnkfile} #{e}")			
						raise e
					end
					
					cmdline = "\"#{@LINK_EXE}\" -nologo @\"#{lnkfile}\"";					
					puts(cmdline) if(cfg.verbose?)
					system( cmdline );
				end
				
				def createExeTarget(config)
						
					isolationAware = false;	
						
					targetName = "#{config.baseName}-#{config.CONFIG}"
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
				
				# platform specific task actions (lambda blocks)
				def compileCPPAction
					@@compileCPPAction
				end

				def compileCAction
					@@compileCAction
				end
				
			end # class Tools

			def self.loadTools(cfgs,config)
				puts("initializing win32 tools")
				return(Tools.new(cfgs,config));
			end	
		end
	end	
end
