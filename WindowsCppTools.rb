
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
					
			platform  = splitcfgs[0];
			platformType = args[:platform];
			platformBits = args[:platformBits];
		
			compiler  = args[:compiler];
			linkType  = args[:linkType];
			debugType = args[:debugType];
							
		end

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
			platform = $`;
			platformBits = $&;
		end
		if(platform === 'Win')
			platform = 'Windows';
		end

		log.debug { "config validated #{cfgs.join('-')}" };
		return( Win32Tools.new( 
			:split=>cfgs,
			:platformBits=>platformBits,
			:compiler=>compiler,
			:linkType=>linkType,
			:debugType=>debugType
		));
	end

end);

end  # Rakish
