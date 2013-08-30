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
      # Clean up PATH as well
      ENV["PATH"] = ENV["PATH"].split(":").reject{|part| part =~ /crowbar_framework/}.join(":")
      exit!(system("knife #{args}"))
    end
    Process.waitpid2(pid)[1].exitstatus == 0
  end

  # Add role-specific overrides.
  module Role

    # chef-server role needs an on_active helper
    module ChefServer
      def on_active(nr)
        j = BarclampChef::Jig.where(:name => "chef").first
        j.server = "http://#{nr.node.name}:4000"
        j.client_name = "crowbar"
        j.active = true
        j.key = "/home/crowbar/.chef/crowbar.pem"
        j.save!
      end

      def on_error(nr)
        raise "aieee! Failed to install chef-server, cannot create chef jig!"
      end
    end

    module ChefClient
      def on_transition(nr)
        # Create chef metadata if needed.
        NodeRole.transaction do
          d = nr.sysdata
          clientinfo = (d["chefjig"]["client"] || {} rescue {})
          return if clientinfo["key"]
          chefjig = Jig.where(:name => "chef").first
          raise "Cannot load Chef Jig" unless chefjig
          chef_node, chef_role, chef_client = chefjig.create_node(nr.node)
          raise "COuld not create chef client!" unless chef_client["private_key"]
          clientinfo["key"] = chef_client["private_key"]
          clientinfo["name"] = nr.node.name
          d["chefjig"] ||= Hash.new
          d["chefjig"]["client"] = clientinfo
          nr.sysdata = d
          nr.save!
        end
      end
    end
  end
end
