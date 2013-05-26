module Rakish

class VcprojBuilder
	include Rakish::Util

	@@rakefileConfigTxt_=<<EOTEXT
<?xml version="1.0" encoding="utf-8"?>
<Project DefaultTargets="Build" ToolsVersion="4.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <ItemGroup Label="ProjectConfigurations">
    <ProjectConfiguration Include="Debug|Win32">
      <Configuration>Debug</Configuration>
      <Platform>Win32</Platform>
    </ProjectConfiguration>
    <ProjectConfiguration Include="Release|Win32">
      <Configuration>Release</Configuration>
      <Platform>Win32</Platform>
    </ProjectConfiguration>
  </ItemGroup>
  <PropertyGroup Label="Globals">
    <ProjectGuid>{\#{projectUuid}}</ProjectGuid>
    <Keyword>MakeFileProj</Keyword>
   <RootNamespace>\#{projectNamespace}</RootNamespace>
   </PropertyGroup>
  <Import Project="$(VCTargetsPath)\\Microsoft.Cpp.Default.props" />
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'" Label="Configuration">
    <ConfigurationType>Makefile</ConfigurationType>
    <UseDebugLibraries>true</UseDebugLibraries>
  </PropertyGroup>
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'" Label="Configuration">
    <ConfigurationType>Makefile</ConfigurationType>
    <UseDebugLibraries>false</UseDebugLibraries>
  </PropertyGroup>
  <Import Project="$(VCTargetsPath)\\Microsoft.Cpp.props" />
  <ImportGroup Label="ExtensionSettings">
  </ImportGroup>
  <ImportGroup Label="PropertySheets" Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'">
    <Import Project="$(UserRootDir)\\Microsoft.Cpp.$(Platform).user.props" Condition="exists('$(UserRootDir)\\Microsoft.Cpp.$(Platform).user.props')" Label="LocalAppDataPlatform" />
  </ImportGroup>
  <ImportGroup Label="PropertySheets" Condition="'$(Configuration)|$(Platform)'=='Release|Win32'">
    <Import Project="$(UserRootDir)\\Microsoft.Cpp.$(Platform).user.props" Condition="exists('$(UserRootDir)\\Microsoft.Cpp.$(Platform).user.props')" Label="LocalAppDataPlatform" />
  </ImportGroup>
  <PropertyGroup Label="UserMacros" />
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'">
    <NMakeOutput>makerake.exe</NMakeOutput>
    <NMakePreprocessorDefinitions>WIN32;_DEBUG;$(NMakePreprocessorDefinitions)</NMakePreprocessorDefinitions>
    <NMakeBuildCommandLine>..\\..\\third-party\\tools\\exec-rake.bat -f rakefile.rb vcproj</NMakeBuildCommandLine>
    <NMakeReBuildCommandLine>rake -f rakefile.rb rebuild</NMakeReBuildCommandLine>
    <NMakeCleanCommandLine>rake -f rakefile.rb clean</NMakeCleanCommandLine>
  </PropertyGroup>
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'">
    <NMakeOutput>makerake.exe</NMakeOutput>
    <NMakePreprocessorDefinitions>WIN32;NDEBUG;$(NMakePreprocessorDefinitions)</NMakePreprocessorDefinitions>
  </PropertyGroup>
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

	def writeRakefileVCProj(file,targ,diffto)
		indent = "";
		cfg = targ.config; # TODO: clean this up ??
		projectUuid = cfg.projectId;
		projectNamespace = cfg.moduleName;

		rubyLinePP(@@rakefileConfigTxt_,file,binding());
	end

	def VcprojBuilder.onVcprojTask(t)
		
		@@instance_||= VcprojBuilder.new();

		cfg = t.config;
		defpath = File.join(cfg.vcprojDir, cfg.moduleName + '-rake.vcproj'); 
		puts(" creating vcproj in #{defpath}")
		begin
			File.open(defpath,'w') do |f|
				@@instance_.writeRakefileVCProj(f,t,nil);
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