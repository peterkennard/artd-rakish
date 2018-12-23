myPath = File.dirname(File.expand_path(__FILE__));
require "#{myPath}/Rakish.rb"

module Rakish

    module GitModule

		# Very simple module for Git used to initialize my projects
		module Git # :nodoc:

			class << self
				def clone(src,dest,opts={})
					if(!File.directory?(dest))

						origin = opts[:remote] || "origin";

						puts("Git.clone -o \"#{origin}\" -n \"#{src}\" \"#{dest}\"");

						system("git clone -o \"#{origin}\" -n \"#{src}\" \"#{dest}\"");
						cd dest do
							system("git config -f ./.git/config --replace-all core.autocrlf true");
							system("git reset -q --hard");
						end
					end
				end

				def addRemote(dir, name, uri)
					cd dir do
						system("git remote add \"#{name}\" \"#{uri}\"");
					end
                end

				def checkout(branch, opts={})
                    cmd = "git checkout \"#{branch}\"";
					if(opts[:dir])
					    cd opts[:dir] do
                            system(cmd);
                        end
                     else
                        system(cmd);
                     end
                end
			end
		end

		def git
		    Rakish::Git
		end
	end
	Git = Rakish::GitModule::Git;
end