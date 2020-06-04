
module Rakish
    class << self
        def ensureVersion(lastHash)
            home = ENV["HOME"];
            currentHash = `artd-rakish-find`;
            currentHash.strip!;

            if(currentHash != lastHash)
                puts("currently on rakish #{currentHash}");
                puts("checking out rakish #{lastHash}");s
                cd "#{home}/artd-rakish" do
                    system("git checkout master");
                    system("git pull");
                    system("git checkout #{lastHash}");
                    system("rake installGem");
                end
            end
        end
    end
end
