module Rakish

class VcprojBuilder
	include Rakish::Util

	@@rakefileConfigTxt_=<<EOTEXT
<?xml version="1.0" encoding="utf-8"?>
<Project DefaultTargets="Build" ToolsVersion="4.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <ItemGroup Label="ProjectConfigurations">
    \#{getVCX10RakefileConfigList(indent)}
  </ItemGroup>
  <PropertyGroup Label="Globals">
    <ProjectGuid>{\#{projectUuid}}</ProjectGuid>
    <Keyword>MakeFileProj</Keyword>
	<ProjectName>\#{projectName}</ProjectName>
  </PropertyGroup>
  <Import Project="$(VCTargetsPath)\\Microsoft.Cpp.Default.props" />
  \#{getVCX10RakefileConfigTypes(indent)}
  <Import Project="$(VCTargetsPath)\\Microsoft.Cpp.props" />
  <ImportGroup Label="ExtensionSettings">
  </ImportGroup>
  \#{getVCX10RakefilePropertySheets(indent)}
  <PropertyGroup Label="UserMacros" />
  \#{getVCX10RakefileUserMacros(indent)}   
  <ItemDefinitionGroup>
  </ItemDefinitionGroup>
  \#{getVCX10FileGroups(indent)}
  <Import Project="$(VCTargetsPath)\\Microsoft.Cpp.targets" />
  <ImportGroup Label="ExtensionTargets">
  </ImportGroup>
</Project>
EOTEXT

	def addVCX10ProjectConfig(out,config)
		out << "<ProjectConfiguration Include=\"#{config}|Win32\">";
		out << "  <Configuration>#{config}</Configuration>";
		out << '  <Platform>Win32</Platform>';
		out << '</ProjectConfiguration>';
	end

	def getVCX10RakefileConfigList(indent)
		indent = "%#{indent}s" % "";
		out = [];
		eachConfig do |cfg|
			addVCX10ProjectConfig(out,cfg.configName);
		end
		out.join("\n#{indent}");
	end

	def addVCX10ConfigTypeCondition(out, config)
		out << "<PropertyGroup Condition=\"'$(Configuration)|$(Platform)'=='#{config}|Win32'\" Label=\"Configuration\">";
		out << '  <ConfigurationType>Makefile</ConfigurationType>';
		out << '  <UseDebugLibraries>false</UseDebugLibraries>';
	    out << "  <IntDir>#{cppProject.OBJPATH()}</IntDir>";
		out << "  <OutDir>#{cppProject.BINDIR()}</OutDir>";
		out << '</PropertyGroup>';
	end

	def getVCX10RakefileConfigTypes(indent)
		indent = "%#{indent}s" % "";
		out = [];
		eachConfig do |cfg|
			addVCX10ConfigTypeCondition(out,cfg.configName);
		end
		out.join("\n#{indent}");
	end

	def addVCX10RakefileImportGroup(out, config)
		out << "<ImportGroup Label=\"PropertySheets\" Condition=\"'$(Configuration)|$(Platform)'=='#{config}|Win32'\">";
		out << '  <Import Project="$(UserRootDir)\\Microsoft.Cpp.$(Platform).user.props" Condition="exists(\'$(UserRootDir)\\Microsoft.Cpp.$(Platform).user.props\')" Label="LocalAppDataPlatform" />';
		out << '</ImportGroup>';
	end

	def getVCX10RakefilePropertySheets(indent) 
		indent = "%#{indent}s" % "";
		out = [];
		eachConfig do |cfg|
			addVCX10RakefileImportGroup(out, cfg.configName );
		end
		out.join("\n#{indent}");
	end

	def addVCX10RakefileUserMacroGroup(out, cfg)
		
		out << "<PropertyGroup Condition=\"'$(Configuration)|$(Platform)\'=='#{cfg.configName}|Win32'\">";
		out << "  <NMakeOutput>#{cppProject.moduleName}.exe</NMakeOutput>";
		
		begin
			cppdefs = '';
			delim = '';
			cfg.cppDefines.each do |k,v|
				cppdefs += "#{delim}#{k}#{v ? '='+v : ''}"
				delim =';';
			end
			out << "  <NMakePreprocessorDefinitions>#{cppdefs}</NMakePreprocessorDefinitions>";
		end
		
		if(cfg.configName === 'Autogen') 
			out << "  <NMakeBuildCommandLine>#{rakeCommandLine} autogen</NMakeBuildCommandLine>";
			out << "  <NMakeReBuildCommandLine>#{rakeCommandLine} autogenclean autogen</NMakeReBuildCommandLine>";
			out << "  <NMakeCleanCommandLine>#{rakeCommandLine} autogenclean</NMakeCleanCommandLine>";
		else
			out << "  <NMakeBuildCommandLine>#{rakeCommandLine} build</NMakeBuildCommandLine>";
			out << "  <NMakeReBuildCommandLine>#{rakeCommandLine} rebuild</NMakeReBuildCommandLine>";
			out << "  <NMakeCleanCommandLine>#{rakeCommandLine} clean</NMakeCleanCommandLine>";
			# note intellisense doesn't like relative include paths.
			out << "  <NMakeIncludeSearchPath>#{cfg.includePaths.join(';')}</NMakeIncludeSearchPath>";
		end
		out << '</PropertyGroup>';
	end

	def getVCX10RakefileUserMacros(indent)
		indent = "%#{indent}s" % "";
		out = [];
		eachConfig do |cfg|
			addVCX10RakefileUserMacroGroup(out, cfg );
		end
		out.join("\n#{indent}");
	end

	def vcprojRelative(f)
		getWindowsRelativePath(f,cppProject.vcprojDir);
	end

	def getVCX10FileGroups(indent)
		indent = "%#{indent}s" % "";
		out = []
		files = cppProject.getSourceFiles();
		unless(files.empty?)
			out << '<ItemGroup>';
			files.each do |f|
				out << "  <ClCompile Include=\"#{vcprojRelative(f)}\" />";
			end
			out << '</ItemGroup>';
		end

		files = cppProject.getIncludeFiles();
		unless(files.empty?)
			out << '<ItemGroup>';
			files.each do |f|
				out << "  <ClInclude Include=\"#{vcprojRelative(f)}\" />";
			end
			out << '</ItemGroup>';
		end
		out << '<ItemGroup>';
		out << "  <None Include=\"#{vcprojRelative(cppProject.projectFile)}\" />";
		out << '</ItemGroup>';
		out.join("\n#{indent}");
	end


	def eachConfig(&b) 
		[	
			"Win32-VC10-MD-Debug",
			"Win32-VC10-MDd-Debug",
			"Win32-VC10-MT-Debug",
			"Win32-VC10-MTd-Debug",
			"Win32-VC10-MD-Release",
			"Win32-VC10-MT-Release" 
		].each do |cfg|
			cfg = cppProject.resolveConfiguration(cfg);
			next unless cfg
			yield(cfg);
		end
	end


	@@rakefileFiltersTxt_=<<EOTEXT
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="4.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <ItemGroup>
    <Filter Include="Source Files">
      <UniqueIdentifier>{4FC737F1-C7A5-4376-A066-2A32D752A2FF}</UniqueIdentifier>
      <Extensions>cpp;c;cc;cxx;def;odl;idl;hpj;bat;asm;asmx</Extensions>
    </Filter>
    <Filter Include="Header Files">
      <UniqueIdentifier>{93995380-89BD-4b04-88EB-625FBE52EBFB}</UniqueIdentifier>
      <Extensions>h;hpp;hxx;hm;inl;inc;xsd</Extensions>
    </Filter>
    <Filter Include="Resource Files">
      <UniqueIdentifier>{67DA6AB6-F800-4c08-8B7A-83BB121AAD01}</UniqueIdentifier>
      <Extensions>rc;ico;cur;bmp;dlg;rc2;rct;bin;rgs;gif;jpg;jpeg;jpe;resx;tiff;tif;png;wav;mfcribbon-ms</Extensions>
    </Filter>
  </ItemGroup>
  <ItemGroup>
  </ItemGroup>
</Project>
EOTEXT

	attr_reader :cppProject
	attr_reader :rakeCommandLine

	def writeRakefileVCProj(file)
		indent = "";
		proj = cppProject;
		projectUuid = proj.projectId;
		projectName = proj.moduleName;
		
		rakeCommand = vcprojRelative(File.join(proj.thirdPartyPath,'tools/exec-rake.bat'));
		rakeFile = vcprojRelative(proj.projectFile);

		@rakeCommandLine = "#{rakeCommand} -f #{rakeFile} \"RakishBuildRoot=$(SolutionDir)build\"";
		
		rubyLinePP(@@rakefileConfigTxt_,file,binding());
	end

	def writeRakefileVCProjFilters(file)
		rubyLinePP(@@rakefileFiltersTxt_,file,binding());
	end

	def writeVCProjFiles(proj)
		@cppProject = proj;

		defpath = File.join(proj.vcprojDir, proj.moduleName + '-rake.vcxproj'); 
		filpath = "#{defpath}.filters"
		tempPath = File.join(proj.vcprojDir, proj.moduleName + '.temp');
		
		puts(" creating vcproj in #{defpath}")
		begin
			File.open(tempPath,'w') do |f|
				writeRakefileVCProj(f);
			end	
			if(textFilesDiffer(tempPath,defpath))
				mv(tempPath, defpath);
			end
			File.open(tempPath,'w') do |f|
				writeRakefileVCProjFilters(f);
			end	
			if(textFilesDiffer(tempPath,filpath))
				mv(tempPath, filpath);
			end
		rescue => exception
		  puts exception
		  # exception.backtrace
		end	
		rm_f(tempPath);

	end

	def VcprojBuilder.onVcprojTask(proj)
		builder = VcprojBuilder.new # do
		builder.writeVCProjFiles(proj);
	end
	
	def VcprojBuilder.onVcprojCleanTask(proj)
		defpath = File.join(proj.vcprojDir, proj.moduleName + '-rake.vcxproj'); 
		filpath = "#{defpath}.filters";
		proj.addCleanFiles(defpath,filpath);		
	end 

end

end # Rakish