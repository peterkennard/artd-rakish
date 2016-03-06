require 'rake'

Gem::Specification.new do |s|
  s.name        = 'rakish'
  s.version     = '0.9.0'
  s.summary     = "Rakish build support gem"
  s.description = "Rakish build support gem"
  s.authors     = ["Peter Kennard"]
  s.email       = 'peterk@livingwork.com'
  s.files       =  FileList.new(["lib/rakish.rb",
                                  "lib/rakish/*",
								  "doc/*"
                   ]).to_a();
				   
  s.add_runtime_dependency 'rake',
  '>= 0.9.0.0'
				   
  s.homepage    = ''
  s.license     = 'BSD'
end