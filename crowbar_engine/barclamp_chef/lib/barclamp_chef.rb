require "barclamp_chef/engine"

module BarclampChef

  # Add role-specific overrides.
  module Role

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
    
  end
end
