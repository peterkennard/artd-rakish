
module Rakish

	LoadableModule.onLoaded(Class.new do

		include Logger;

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
	
		class Win32Tools < CTools


		end


		def self.validateConfig(cfgs)
			found = 0;
			configs={}
			cfgs.each do |cfg|
				cmp = VALID_COMPILERS[cfg];
				if(cmp)
					configs[:compiler] = cfg;
					found |= 1;
					next
				end
				cmp = VALID_LINKTYPES[cfg];
				if(cmp)
					configs[:linkType] = cfg;
					found |= 2;
					next
				end
				cmp = VALID_DEBUGTYPES[cfg];
				if(cmp)
					configs[:debugType] = cfg;
					found |= 4;
					next
				end
			end

			log.debug { "config validated" };

			return(configs);
		end



	end);

end