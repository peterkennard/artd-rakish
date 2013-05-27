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
  <ItemGroup>
    <None Include="readme.txt" />
  </ItemGroup>
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
			addVCX10ProjectConfig(out,cfg);
		end
		out.join("\n#{indent}");
	end

	def addVCX10ConfigTypeCondition(out, config)
		out << "<PropertyGroup Condition=\"'$(Configuration)|$(Platform)'=='#{config}|Win32'\" Label=\"Configuration\">";
		out << '  <ConfigurationType>Makefile</ConfigurationType>';
		out << '  <UseDebugLibraries>false</UseDebugLibraries>';
		out << '</PropertyGroup>';
	end

	def getVCX10RakefileConfigTypes(indent)
		indent = "%#{indent}s" % "";
		out = [];
		eachConfig do |cfg|
			addVCX10ConfigTypeCondition(out,cfg);
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
			addVCX10RakefileImportGroup(out, cfg );
		end
		out.join("\n#{indent}");
	end

	def addVCX10RakefileUserMacroGroup(out, config)
		out << "<PropertyGroup Condition=\"'$(Configuration)|$(Platform)\'=='#{config}|Win32'\">";
		out << "  <NMakeOutput>#{cppProject.moduleName}.exe</NMakeOutput>";
		out << '  <NMakePreprocessorDefinitions>WIN32;_DEBUG;$(NMakePreprocessorDefinitions)</NMakePreprocessorDefinitions>';
		out << '  <NMakeBuildCommandLine>rake build</NMakeBuildCommandLine>';
		out << '  <NMakeReBuildCommandLine>rake rebuild</NMakeReBuildCommandLine>';
		out << '  <NMakeCleanCommandLine>rake clean</NMakeCleanCommandLine>';
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

	def eachConfig(&b) 
		['Autogen','Debug','Release'].each(&b);
	end

	attr_reader :cppProject

	def writeRakefileVCProj(file,targ,diffto)
		indent = "";
		@cppProject = targ.config;
		cfg = targ.config; # TODO: clean this up ??
		projectUuid = cfg.projectId;
		projectNamespace = cfg.moduleName;
		
		rakeCommand = getWindowsRelativePath(File.join(cfg.thirdPartyPath,'tools/exec-rake.bat'),cfg.vcprojDir);
		rakeFile = getWindowsRelativePath(cfg.projectFile,cfg.vcprojDir);

		buildCommandLine = "#{rakeCommand} -f #{rakeFile} build";
		reBuildCommandLine = "#{rakeCommand} -f #{rakeFile} rebuild";
		cleanCommandLine = "#{rakeCommand} -f #{rakeFile} clean";

		rubyLinePP(@@rakefileConfigTxt_,file,binding());
	end

	def VcprojBuilder.onVcprojTask(t)
		
		builder = VcprojBuilder.new # do
		#	@cppProject = t.config.
		# end

		cfg = t.config;
		defpath = File.join(cfg.vcprojDir, cfg.moduleName + '-rake.vcxproj'); 
		puts(" creating vcproj in #{defpath}")
		begin
			File.open(defpath,'w') do |f|
				builder.writeRakefileVCProj(f,t,nil);
			end	
		rescue => exception
		  puts exception
		  # exception.backtrace
		end	
	end
	
	def VcprojBuilder.onVcprojCleanTask(t)
		puts(" cleaning vcproj ");
	end 

end

end # Rakish