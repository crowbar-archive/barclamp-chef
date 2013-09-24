class BarclampChef::Server < Role
  def on_active(nr)
    j = BarclampChef::Jig.where(:name => "chef").first
    j.server = "https://#{nr.node.name}"
    j.client_name = "crowbar"
    j.active = true
    j.key = "/home/crowbar/.chef/crowbar.pem"
    j.save!
  end
end
