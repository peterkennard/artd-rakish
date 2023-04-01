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
                        silent = opts[:silent];

						puts("Git.clone -o \"#{origin}\" -n \"#{src}\" \"#{dest}\"");

                        ret = '';

                        oCommand = ENV['GIT_SSH_COMMAND']
                        begin
                            ENV['GIT_SSH_COMMAND'] = "ssh -o PasswordAuthentication=no"
 						    ret = `git clone -o \"#{origin}\" -n \"#{src}\" \"#{dest}\" 2>&1`
                        rescue
                        ensure
                            ENV['GIT_SSH_COMMAND'] = oCommand;
                        end
					    if(ret =~ /fatal\:/)
					        unless(silent)
					            log.debug("#{ret}");
					        end
					        return false;
					    end
					    if(!File.directory?(dest))
					        return false;
					    end
						FileUtils.cd dest do
						    # TODO: set this depending on what the platform is ?
							# system("git config -f ./.git/config --replace-all core.autocrlf true");
							system("git reset -q --hard");
						end
					end
                    return(true);
				end

				def cloneIfAvailable(src,dest,opts={})
                    # You can disable password authentication with -o PasswordAuthentication=no. Full command would be:
                    # ssh -nT -o PasswordAuthentication=no <host>  # n no stdout output, T no tty input.
                    # GIT_SSH_COMMAND=ssh -o PasswordAuthentication=no' controls what git does
                    opts[:silent] = true;
                    clone(src,dest,opts);
				end

				def addRemote(dir, name, uri)
					FileUtils.cd dir do
						system("git remote add \"#{name}\" \"#{uri}\"");
					end
                end

				def checkout(branch, opts={})
                    cmd = "git checkout \"#{branch}\"";
					if(opts[:dir])
					    FileUtils.cd opts[:dir] do
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