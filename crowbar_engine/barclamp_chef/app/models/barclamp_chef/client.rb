class BarclampChef::Client < Role
  def on_transition(nr)
    # Create chef metadata if needed.
    NodeRole.transaction do
      d = nr.sysdata
      clientinfo = (d["chefjig"]["client"] || {} rescue {})
      return if clientinfo["key"]
      chefjig = Jig.where(:name => "chef").first
      raise "Cannot load Chef Jig" unless chefjig
      chef_node, chef_role, chef_client = chefjig.create_node(nr.node)
      private_key = nil
      # Sometimes we get an APICilent back, sometimes we get a hash.
      # I have no idea why.
      if chef_client.kind_of?(Chef::ApiClient)
        private_key = chef_client.private_key
      elsif chef_client.kind_of?(Hash)
        private_key = chef_client["private_key"]
      else
        raise "No idea how to get the private key!"
      end
      raise "Could not create chef client!" unless private_key && private_key != ""
      clientinfo["key"] = private_key
      clientinfo["name"] = nr.node.name
      d["chefjig"] ||= Hash.new
      d["chefjig"]["client"] = clientinfo
      nr.sysdata = d
      nr.save!
    end
  end
end
