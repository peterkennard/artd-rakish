myDir = File.expand_path(File.dirname(__FILE__));
require 'rake'

Gem::Specification.new do |s|

puts("checking if key exists")

  privateKeyPath = File.expand_path("~/.ssh/gem-private_key.pem");

  certPath = File.expand_path("#{myDir}/certs/peterk@artd.com.pem}");

  unsignedGem = (ENV['RAKISH_UNSIGNED'] === '1' || (!File.exists?(privateKeyPath)));

puts("unsignedGem \"#{unsignedGem}\" #{unsignedGem === true}\"")


  versionNumber = '0.9.14';

  s.name        = 'rakish'
  s.summary     = "Rakish build support gem"
  s.description = "Rakish Rake build system built on top of Rake for managing large scale projects with lots of modules."
  s.authors     = ["Peter Kennard"]
  s.email       = 'peterk@livingwork.com'

  unless(unsignedGem)
      puts("making signed gem");
      if($0 =~ /gem\z/)
        s.cert_chain  = [ certPath ];
        s.signing_key = privateKeyPath;
      else
        unsignedGem = false;
      end
  end

  if(unsignedGem)
    s.version     = "#{versionNumber}.test"
  else
    s.version     = "#{versionNumber}.beta"
  end

  puts("building gem \"#{s.version}.gem\"");

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
