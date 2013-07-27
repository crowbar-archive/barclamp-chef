require "fileutils"
require "barclamp_chef/engine"

module BarclampChef

  def self.knife(args)
    pid = fork
    unless pid
      # Get rid of all bundle-related env vars
      [
       "RAILS_ENV",
       "RUBYOPT",
       "GEM_HOME",
       "GEM_PATH",
       "BUNDLE_BIN_PATH",
       "BUNDLE_GEMFILE"
      ].each {|k|ENV.delete(k)}
      # Sigh, knife needs EDITOR
      ENV["EDITOR"] ||= "true"
      exit!(system("knife #{args}"))
    end
    Process.waitpid2(pid)[1].exitstatus
  end

  # Add role-specific overrides.
  module Role

    # chef-server role needs an on_active helper
    module ChefServer
      def on_active(nr)
        unless BarclampChef::Jig.exists?(:name => "chef")
          j = BarclampChef::Jig.create(:name => "chef")
          j.description = "Chef Jig"
          j.order = 100
          j.server = "http://#{nr.node.name}:4000"
          j.client_name = "crowbar"
          j.key = "/home/crowbar/.chef/crowbar.pem"
          j.save!
        end
      end

      def on_error(nr)
        raise "aieee! Failed to install chef-server, cannot create chef jig!"
      end
    end

    module ChefClient
      def on_transition(nr)
        # Create chef metadata if needed.
        NodeRole.transaction do
          d = nr.data
          clientinfo = (d["chefjig"]["client"] || {} rescue {})
          return if clientinfo["key"]
          clientinfo["name"]=nr.node.name
          Dir.mktmpdir do |tempdir|
            FileUtils.cd(tempdir) do
              unless BarclampChef.knife("client create '#{nr.node.name}' -f ./client.pem")
                raise "Cannot create Chef Client for #{nr.node.name}"
              end
              clientinfo["key"] = IO.read("client.pem")
            end
          end
          d["chefjig"] ||= {}
          d["chefjig"]["client"] = clientinfo
          nr.data = d
          nr.save!
        end
      end
    end

  end
end
