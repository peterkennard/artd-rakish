
module Rakish

LoadableModule.onLoaded(Module.new do

	include Logger;

	VALID_DEBUGTYPES = { 
		'Debug'=>true,
		'Release'=>true,
#		'Checked'=>true
	};

	VALID_LINKTYPES = { 
		'MT'=>true,
		'MTd'=>true,
		'MD'=>true,
		'MDd'=>true
	};
				
	VALID_COMPILERS = { 
#		'VC5'=>true,
#		'VC6'=>true,
#		'VC7'=>true, 
		'VC8'=>true, 
#		'VC9'=>true, 
		'VC10'=>true,
#		'ICL'=>true
	};
	
	class Win32Tools 
		include CTools

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

		def initialize(args)

			splitcfgs = args[:split];
					
			@platform  = splitcfgs[0];
			@platformType = args[:platformType];
			@platformBits = args[:platformBits];
		
			@compiler  = args[:compiler];
			@linkType  = args[:linkType];
			@debugType = args[:debugType];

			cppOpts = ' -nologo';
			cppWarnings = '';
			linkOpts = '';
			sdkLibs = [];
			
			tpp = GlobalConfig.instance.thirdPartyPath;
					
			case(@platformBits)
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

			case(@debugType)
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

#				CPP_OPTIONS_DEBUG := -Zi
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
			case(@compiler)
				when 'VC9'
				when 'VC10'
				else
					cppWarnings += ' -Wp64'
			end

			case(@linkType)
				when 'MT'
					@BASELINKAGE = 'Static'
					cppOpts += " -MT"
					@linkDefines=['NDEBUG','_MT'];
					sdkLibs << 'libcmt.lib'
					sdkLibs << 'libcpmt.lib'
				when 'MTd'
					@BASELINKAGE = 'Static'
					cppOpts += " -MTd"
					@linkDefines=['_DEBUG','_MT'];
					sdkLibs << 'libcmtd.lib'
					sdkLibs << 'libcpmtd.lib'
				#	DEBUG_CRT := 1
				when 'MD'
					@BASELINKAGE = 'Dynamic'
					cppOpts += " -MD"
					@linkDefines=['NDEBUG', '_MT', '_DLL'];
					sdkLibs << 'msvcrt.lib'
				#	ifeq ($(WINDOWS_CLR),1)
				#		sdkLibs << 'msvcmrt.lib'
				#	end
					sdkLibs << 'msvcprt.lib'
				when 'MDd'
					@BASELINKAGE = 'Dynamic'
					cppOpts += " -MDd"
					@linkDefines=['_DEBUG', '_MT', '_DLL'];
					sdkLibs << 'msvcrtd.lib'
				#	ifeq ($(WINDOWS_CLR),1)
				#		sdkLibs << 'msvcmrtd.lib'
				#	end
					sdkLibs << 'msvcprtd.lib'
				#	DEBUG_CRT := 1
				else
					@linkDefines=[]
			end
					
 			if(@debugType === 'Debug')
			#	ifeq ($(DEBUG_CRT),1)
			#		ifneq ($(WINDOWS_CLR),1)
			#			cppOpts += " -RTC1"
			#		end
			#		cppOpts += " -Gs0"
			#	end
 			end
 
			unless(@compiler === 'VC6')
				# cppOpts += " -showIncludes"
				case(@linkType)
					when 'MT'
						sdkLibs << 'atls.lib'
						sdkLibs << 'comsuppw.lib'
					when 'MTd'
						sdkLibs << 'atlsd.lib'
						sdkLibs << 'comsuppwd.lib'
						
					when 'MD'
						sdkLibs << 'atls.lib'
						sdkLibs << 'comsuppw.lib'
					when 'MDd'
						sdkLibs << 'atlsd.lib'
						sdkLibs << 'comsuppwd.lib'
				end
			end
								
			unless(@compiler === 'VC7')
				cppOpts += " -bigobj"
			end

			# select tool executables and OS sdk library paths
			case(@compiler)
				when 'VC6'
					@CVTRES_EXE = "#{tpp}/tools/msvc6/bin/cvtres.exe"
					@MSVC_EXE = "#{tpp}/tools/msvc6/bin/cl.exe"
					@LINK_EXE = "#{tpp}/tools/msvc6/bin/link.exe"

					cppOpts += " -GX";						
					cppOpts += " -I#{tpp}/tools/msvc6/include";
					cppOpts += " -I#{tpp}/tools/msvc7/include";
					cppOpts += " -I#{tpp}/tools/msvc8/include";
					cppOpts += " -libpath:#{tpp}/tools/msvc6/lib";
				when 'VC7'
					@CVTRES_EXE = "#{tpp}/tools/msvc7/bin/cvtres.exe"
					@MSVC_EXE ="#{tpp}/tools/msvc7/bin/cl.exe"
					@LINK_EXE = "#{tpp}/tools/msvc7/bin/link.exe"

					cppOpts += " -GX"
					cppOpts += " -I\"#{tpp}/tools/msvc7/include\""
					cppOpts += " -I\"#{tpp}/tools/msvc7/atlmfc/include\""
					linkOpts += " -libpath:\"#{tpp}/tools/msvc7/lib\""
					linkOpts += " -libpath:\"#{tpp}/tools/msvc7/atlmfc/lib\""
				when 'VC8'
					@CVTRES_EXE = "#{tpp}/tools/msvc8/bin/cvtres.exe"
					cppOpts += " -I\"#{tpp}/tools/msvc8/include\""
					cppOpts += " -I\"#{tpp}/tools/msvc8/atlmfc/include\""

					if(@platform === "Win32")
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
				when 'VC9'
					@CVTRES_EXE = "#{tpp}/tools/msvc9/bin/cvtres.exe"
					cppOpts += " -I\"#{tpp}/tools/msvc9/include\""
					cppOpts += " -I\"#{tpp}/tools/msvc9/atlmfc/include\""
					if(@platform === "Win32")
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
				when 'VC10'
					@CVTRES_EXE = "#{tpp}/tools/msvc10/bin/cvtres.exe"
					cppOpts += " -I\"#{tpp}/tools/msvc10/include\""
					cppOpts += " -I\"#{tpp}/tools/msvc10/atlmfc/include\""
					if(@platform === "Win32")
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
					
			if(@platform === "Win32")
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
			case(@compiler)
				when 'VC8'
					@ManifestSource = "#{tpp}/tools/msvc8/manifest/#{@platform}-#{@linkType}.manifest"
					linkOpts += " -manifest:no"
				when 'VC9'
					@ManifestSource = "#{tpp}/tools/msvc9/manifest/#{@platform}-#{@linkType}.manifest"
					linkOpts += " -manifest:no"
				when 'VC10'
					@ManifestSource = "#{tpp}/tools/msvc10/manifest/#{@platform}-#{@linkType}.manifest"
					linkOpts += " -manifest:no"
				when 'ICL'
					@ManifestSource = "#{tpp}/tools/msvc8/manifest/#{@platform}-#{@linkType}.manifest"
					linkOpts += " -manifest:no"
				else
					includesManifest = false;
			end
										
			@CPP_OPTIONS 	= cppOpts;
			@CPP_WARNINGS 	= cppWarnings;
			@SDK_LIBS 		= sdkLibs;
			@LINK_OPTS 		= linkOpts;
			@MACHINE_SPEC 	= machineSpec;
		end

		def ensureConfigOptions(cfg)
	
			cfg.cppDefine(
				@linkDefines,
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
				'STRSAFE_NO_DEPRECATE',
                "ARTD_PLATFORMTYPE=#{@platformType}",
                "ARTD_PLATFORMBITS=#{@platformBits}",
				"ARTD_COMPILERTYPE=#{@compiler}",
				"ARTD_LINKAGETYPE=#{@linkType}",
				"ARTD_DEBUGTYPE=#{@debugType}"
			);
			
			tpp = cfg.thirdPartyPath;

			cfg.addIncludePaths(
				"#{tpp}/include/Win32",
				"#{tpp}/include"
			);

		end

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
			t.config.ctools.doCompileCpp(t)
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

		# Override for CTools
		def initCompileTask(cfg)
			cfg.project.addCleanFiles("#{cfg.OBJPATH()}/*#{OBJEXT()}",
							"#{cfg.OBJPATH()}/*.sbr");
			Rake::Task.define_task :compile => [:includes,
												cfg.OBJPATH(),
												:depends]
		end	

	end


	def self.getConfiguredTools(cfgs,strCfg)
		
		if(cfgs.length != 4) 
			raise InvalidConfigError.new(strCfg, "must be 4 \"-\" separated elements");
		end

		error = false;		
		compiler = nil
		linkType = nil;
		debugType = nil;

		cfgs.each do |cfg|
			cmp = VALID_COMPILERS[cfg];
			if(cmp)
				error = compiler;
				compiler = cfg;
				next
			end
			cmp = VALID_LINKTYPES[cfg];
			if(cmp)
				error = linkType;
				linkType = cfg;
				next
			end
			cmp = VALID_DEBUGTYPES[cfg];
			if(cmp)
				error = debugType;
				debugType = cfg;
				next
			end
		end

		if(error)
			raise InvalidConfigError.new(strCfg, "element present more than once");
		end

		# ensure order of elements is "standard"
		cfgs[1] = compiler;
		cfgs[2] = linkType;
		cfgs[3] = debugType;

		platformBits = '32';
		if(cfgs[0] =~ /\d+/)
			platformType = $`;
			platformBits = $&;
		end
		if(platformType === 'Win')
			platformType = 'Windows';
		end

		args= {
			:split=>cfgs,
			:platformBits=>platformBits,
			:platformType=>platformType,
			:compiler=>compiler,
			:linkType=>linkType,
			:debugType=>debugType
		}

		log.debug { "config validated #{cfgs.join('-')}" };
		return( Win32Tools.new(args));
	end

end);

end  # Rakish
