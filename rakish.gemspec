require 'rake'

Gem::Specification.new do |s|
  s.name        = 'rakish'
  s.version     = '0.9.0'
  s.summary     = "Rakish build support gem"
  s.description = "Rakish build support gem"
  s.authors     = ["Peter Kennard"]
  s.email       = 'peterk@livingwork.com'
  s.files       =  FileList.new(["lib/rakish.rb",
                                  "lib/rakish/*"
                   ]).to_a();
  s.homepage    = ''
  s.license     = 'BSD'
end