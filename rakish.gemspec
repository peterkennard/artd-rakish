myDir = File.expand_path(File.dirname(__FILE__));
require 'rake'

Gem::Specification.new do |s|
  s.name        = 'rakish'
  s.version     = '0.9.12.beta'
  s.summary     = "Rakish build support gem"
  s.description = "Rakish Rake build system built on top of Rake for managing large scale projects with lots of modules."
  s.authors     = ["Peter Kennard"]
  s.email       = 'peterk@livingwork.com'

  privateKeyPath = File.expand_path("~/.ssh/gem-private_key.pem");
  certPath = File.expand_path("#{File.join(myDir,"certs/peterk@artd.com.pem")}");

  if($0 =~ /gem\z/ && File.exists?(privateKeyPath))
      s.cert_chain  = [ certPath ];
      s.signing_key = privateKeyPath;
  end
  s.executables << 'artd-rakish-find'

  s.files       =  FileList.new(["lib/rakish.rb",
                                  "lib/rakish/*",
                                  "bin/**/*",
								  "doc/*"
                   ]).to_a();
  s.extra_rdoc_files = [
      'doc/UserGuide'
  ];
  s.rdoc_options << '--tab_width=4'
  # s.add_runtime_dependency 'rake',
  # [ '>= 0.9.0.0']
				   
  s.homepage    = ''
  s.license     = '0BSD'
end
