class BarclampChef::Server < Role
  def on_active(nr)
    j = BarclampChef::Jig.where(:name => "chef").first
    j.server = "http://#{nr.node.name}:4000"
    j.client_name = "crowbar"
    j.active = true
    j.key = "/home/crowbar/.chef/crowbar.pem"
    j.save!
  end
end
