myDir = File.dirname(__FILE__);
require "#{myDir}/../lib/rakish/CppProjects.rb";
require "rakish/JavaProjects.rb";
require "rakish/IntellijConfig.rb";
require "rakish/RubydocModule.rb";


Rakish.Configuration :include=>[ Rakish::IntellijConfig, Rakish::CppProjectConfig] do |cfg|

	cfg.thirdPartyPath = File.expand_path("#{myDir}/../../third-party");
	cfg.verbose = false;
	cfg.didiRoot = File.expand_path("#{myDir}/..");
	cfg.buildDir = "#{cfg.didiRoot}/build";
	cfg.resourceDir = "#{cfg.buildDir}/Didi/production/.didi";
	cfg.demoRoot = "#{cfg.buildDir}/Didi/DidiDemos";
	cfg.java_home = ENV['JAVA_HOME'];

	if(cfg.java_home =~ /Program Files \(x86\)/)
		cfg.nativeConfigName = 'Win32-VC10-MD-Debug';
	else
		cfg.nativeConfigName = 'Win64-VC10-MD-Debug'
	end

    cfg.cppDefine('WINVER=0x0700');

    # tomcat deployment options

	tomcatConfig = Rakish::BuildConfig.new
	tomcatConfig.enableNewFields do |cfg|
    	cfg.managerURL = "http://localhost:8080/manager/text";
    	cfg.managerUsername = "admin";
    	cfg.managerPassword = "1111";
	end

	# deployment configurations for the three categories of apps
	cfg.omsConfig = Rakish::BuildConfig.new(tomcatConfig) do |cfg|
		cfg.managerURL = "http://localhost:8080/manager/text"
	end

	cfg.routerConfig = Rakish::BuildConfig.new(tomcatConfig) do |cfg|
	   	cfg.managerURL = "http://localhost:8081/manager/text"
	end

    (cfg.servicesConfig = Rakish::BuildConfig.new(tomcatConfig)).enableNewFields do |cfg|;
    	cfg.managerURL = "http://localhost:8082/manager/text";
	end

end
