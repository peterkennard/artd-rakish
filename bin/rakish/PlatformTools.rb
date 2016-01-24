
module Rakish

	module PlatformTools
	
		VALID_PLATFORMS = { 
			:Win32 => {
				:requires => 'WindowsPlatformTools.rb',
				:factory => :WindowsToolsFactory,
			},
			:Win64 => {
				:requires => 'WindowsPlatformTools.rb',
				:factory => :WindowsToolsFactory,
			},
			:iOS => {
				:requires => 'IOSPlatformTools.rb',
				:factory => :IOSToolsFactory,
			},
			:Linux32 => {
				:requires => 'Rakish.rb',
			},
			:Linux64 => {
				:requires => 'Rakish.rb',
			},
		};
		
		def self.parseConfigString(strCfg)
			
			splitcfgs = strCfg.split('-');
			platform  = splitcfgs[0];
			
			platformBits = '32';
			if(platform =~ /\d+/)
				platform = $`;
				platformBits = $&;
			end
			if(platform === 'Win')
				platform = 'Windows';
			end
			return({ :platformType=>platform, 
			         :platformBits=>platformBits,
					 :split=>splitcfgs
					});
		end

		def self.getConfiguredTools(strCfg,config)
			
			parsed = parseConfigString(strCfg);
			split = parsed[:split];
			
			platform = split[0].to_sym;
			pdef = VALID_PLATFORMS[platform];
			unless(pdef)
				puts("###### platform #{platform} not a supported");
			end
			
			config.set(':PLATFORM',platform);

			# load tools module and initialize a tools object  
			require File.join(Rakish::MAKEDIR,pdef[:requires]);
			factory = PlatformTools.const_get(pdef[:factory]);
			tools = factory.loadTools(parsed,config);
		
		end

		class ToolsBase
			include Rakish::Util
		
            
            # given a list of dependencies will write out a '.raked' format dependencies file 
            # for the target task
			def updateDependsFile(task, outName, dependencies)
				
				srcfile = task.source
				tempfile = "#{outName}.temp";
				
				File.open(tempfile,'w') do |out|			
					if(dependencies.size > 0)
						out.puts "t = Rake::Task[\'#{task.name}\'];"
						out.puts 'if(t)'
						out.puts ' t.enhance ['
						out.puts " \'#{srcfile}\',"
						dependencies.each do |f|
							out.puts " \'#{f}\',"
						end
						out.puts ' ]'
						out.puts 'end'
					end
				end
				
                # only touch file if new files differs from old one
				if(textFilesDiffer(outName,tempfile)) 
                    # @#$#@$#@ messed up. set time of new file ahead by one second.
                    # seems rake time resolution is low enough that the comparison often says 
                    # times are equal between depends files and depends.rb.
                    mv(tempfile, outName, :force=>true);
                    time = Time.at(Time.new.to_f + 1.0);
                    File.utime(time,time,outName);
				else
					rm(tempfile, :force=>true);
				end	
			end
			
			def initDependsTask(cfg) # :nodoc:		
               
				# create dependencies file by concatenating all .raked files				
				tsk = file "#{cfg.nativeObjectPath()}/depends.rb" => [ :includes, cfg.nativeObjectPath() ] do |t|
					cd(cfg.nativeObjectPath(),:verbose=>false) do
                        File.open('depends.rb','w') do |out|
							out.puts("# puts \"loading #{t.name}\"");
						end
						t.prerequisites.each do |dep|
                            next unless (dep.pathmap('%x') == '.raked')
							system "cat \'#{dep}\' >> depends.rb"
						end
					end
				end
				# build and import the consolidated dependencies file
				task :depends => [ "#{cfg.nativeObjectPath()}/depends.rb" ] do |t|
					load("#{cfg.nativeObjectPath()}/depends.rb")
				end		
				task :cleandepends do
					deleteFiles("#{cfg.nativeObjectPath()}/*.raked",
								"#{cfg.nativeObjectPath()}/depends.rb");
				end
				tsk
			end

			def initCompileTask(cfg)
				cfg.project.addCleanFiles("#{cfg.nativeObjectPath()}/*#{OBJEXT()}",
							  "#{cfg.nativeObjectPath()}/*.sbr");
				Rake::Task.define_task :compile => [:includes,
													 cfg.nativeObjectPath(),
													 :depends]
			end	
		
			@@CompileForSuffix = {};
		protected	
			def ToolsBase.addCompileAction(suff,action)
				@@CompileForSuffix[suff] = action;		
			end
        public
			def createCompileTask(source,obj,cfg)

				action = @@CompileForSuffix[File.extname(source).downcase];

				unless action
					puts("unrecognized source file type \"#{File.name(source)}\"");
					return(nil);				
				end

				if(Rake::Task.task_defined? obj)
					puts("Warning: task already defined for #{obj}")
					return(nil);
				end

				tsk = Rake::FileTask.define_task obj
				tsk.enhance(tsk.sources=[source], &action)
				tsk.config = cfg;
				tsk;				
			end
            
            def createCompileTasks(files,cfg)
                
                # format object files name
	                                 
                mapstr = "#{cfg.nativeObjectPath()}/%n#{OBJEXT()}";

                objs=FileList[];
                files.each do |source|
                    obj = source.pathmap(mapstr);                                                         
                    task = createCompileTask(source,obj,cfg);
                    objs << obj if task;  # will be the same as task.name
                end
                objs
            end
		end	
												
# rule based			
#			obj = f.pathmap(objstr);
#			srcdir = File.dirname(f);
#			objs << obj;  
#			
#			compileCppRule(srcdir) if(@srcdirs.add?(srcdir)) 		
#			begin	
#				tsk = Rake::Task[obj]
#				tsk.config = cfg;
#			rescue => e
#				puts "Error don't know how to build \n\t#{obj} \nfrom\t#{f}"
#				raise e
#			end	
		
#		def compileCppRule(srcdir) # :nodoc:
#
#			srcdir ||= @projectDir;
#
#		#	if(verbose?) 
#		#		puts("creating rule for #{srcdir} -> #{@nativeObjectPath}");
#		#	end
#		
#			pmapcpp = srcdir + '/%n.cpp';
#			pmapc   = srcdir + '/%n.c';
#					
#			# rule for object file generation
#			regex = 
#				Regexp.new('^' + Regexp.escape(@nativeObjectPath) + '\/[^\/]+' + OBJEXT() + '\z');
#
#			Rake::Task::create_rule( regex => [
#				proc { |task_name| 
#					task_name = task_name.pathmap(pmapcpp);
#				}
#			  ], &tools.compileCPPAction)
#			  
#			Rake::Task::create_rule( regex => [
#				proc { |task_name| 
#					task_name = task_name.pathmap(pmapc);
#				}
#			  ], &tools.compileCAction)
#			  
#			if(nil)
#				# rule for dependency generation 
#				regexd = 
#					Regexp.new('^' + Regexp.escape(@nativeObjectPath) + '\/[^\/]+.raked\z');
#				
#				Rake::Task::create_rule( regexd => [
#					proc { |task_name| 
#						task_name = task_name.pathmap(pmapcpp);
#					}
#				  ], &tools.compileCPPDependsAction)
#
#				Rake::Task::create_rule( regexd => [
#					proc { |task_name| 
#						task_name = task_name.pathmap(pmapc);
#					}
#				  ], &tools.compileCPPDependsAction)
#			end
#		end			
	end
end


#---------- PLATFORM DEFS ------------#

# SUPPORTED_HOST_TYPES := Win64 Win32 Linux32 Linux64 Macosx64
#  
# BASEHOST_Win64 := Windows
# BASEHOST_Win32 := Windows
# BASEHOST_Linux64 := Linux
# BASEHOST_Linux32 := Linux
# #BASEHOST_Macosx64 := Macosx
# #BASEHOST_Macosx32 := Macosx
# 
# #supported platforms
# #VALID_PLATFORMS := Win32 Win64 Linux32 Linux64 Macosx64 Macosx32
# VALID_PLATFORMS := Win32 Win64 Linux32 Linux64
# 
# #default args here
# DEFAULT_CONFIG_Win32 := Win32 VC8 MDd Debug
# DEFAULT_CONFIG_Win64 := Win64 VC9 MDd Debug
# DEFAULT_CONFIG_Linux32 := Linux32 GCC3 Dynamic Debug
# DEFAULT_CONFIG_Linux64 := Linux64 GCC3 Dynamic Debug
# #DEFAULT_CONFIG_Macosx32 := Macosx32 GCC4 Dynamic Debug
# 
# #define base platforms
# BASEPLATFORM_Win32 := Windows
# BASEPLATFORM_Win64 := Windows
# BASEPLATFORM_Linux32 := Linux
# BASEPLATFORM_Linux64 := Linux
# #BASEPLATFORM_Macosx64 := Macosx
# #BASEPLATFORM_Macosx32 := Macosx
# 
# #platform compilers
# COMPILERS_Windows := VC6 VC7 VC8 VC9 VC10
# COMPILERS_Linux := GCC3 GCC4
# COMPILERS_Macosx := GCC4
# 
# #base compiler type
# BASECOMPILER_VC6 := VC
# BASECOMPILER_VC7 := VC
# BASECOMPILER_VC8 := VC
# BASECOMPILER_VC9 := VC
# BASECOMPILER_VC10 := VC
# BASECOMPILER_GCC3 := GCC
# BASECOMPILER_GCC4 := GCC
# 
# #platform linkages
# LINKAGES_VC  := MD MDd MT MTd
# LINKAGES_GCC := Dynamic Static
# 
# BASELINKAGE_MD := Dynamic
# BASELINKAGE_MDd := Dynamic
# BASELINKAGE_MT := Static
# BASELINKAGE_MTd := Static
# BASELINKAGE_Dynamic := Dynamic
# BASELINKAGE_Static := Static
# 
