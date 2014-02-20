# Copyright 2014, Dell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#

require 'json'
require 'fileutils'

class BarclampChef::SoloJig < Jig
  BERKSHELF_PACKAGE = "package.tar.gz"

  def make_run_list(nr)
    runlist = Array.new
    runlist << "recipe[barclamp]"
    runlist << "recipe[ohai]"
    runlist << "recipe[utils]"
    runlist << "role[#{nr.role.name}]"
    runlist << "recipe[crowbar-hacks::solo-saver]"
    Rails.logger.info("Chef Solo: discovered run list: #{runlist}")
    return runlist
  end

  def stage_run(nr)
    chef_path = "/opt/dell/barclamps/#{nr.role.barclamp.name}/chef-solo"
    chef_data_bag_path = "/var/tmp/barclamps/#{nr.role.barclamp.name}/chef-solo/"
    unless File.directory?(chef_path)
      raise("No Chef data at #{chef_path}")
    end
    paths = ["#{chef_path}/roles", "#{chef_data_bag_path}/data_bags", "#{chef_path}/cookbooks"].select{|d|File.directory?(d)}.join(' ')
    # This needs to be replaced by rsync.
    nr.runlog,ok = BarclampCrowbar::Jig.scp("-r #{paths} root@#{nr.node.name}:/var/chef")
    unless ok
      Rails.logger.error("Chef Solo jig run for #{nr.name} failed to copy Chef information.")
      nr.state = NodeRole::ERROR
      return nr
    end

    # If a berkshelf package was copied across, then extract it on the target
    if File.exists?("#{chef_path}/cookbooks/#{BERKSHELF_PACKAGE}")
      nr.runlog,ok = BarclampCrowbar::Jig.ssh("root@#{nr.node.name} -- \"cd /var/chef/cookbooks; tar xf #{BERKSHELF_PACKAGE}\"")
      unless ok
        Rails.logger.error("Chef Solo jig run for #{nr.name} failed to extract Berkshelf package: #{nr.runlog}")
        nr.state = NodeRole::ERROR
        return nr
      end
    end

    return {
      "name" => "crowbar_baserole",
      "default_attributes" => super(nr),
      "override_attributes" => {},
      "json_class" => "Chef::Role",
      "description" => "Crowbar role to provide default attribs for this run",
      "chef-type" => "role",
      "run_list" => make_run_list(nr)
    }
  end

  def run(nr,data)
    local_tmpdir = %x{mktemp -d /tmp/local-chefsolo-XXXXXX}.strip
    chef_path = "/opt/dell/barclamps/#{nr.role.barclamp.name}/chef-solo"
    role_json = File.join(local_tmpdir,"crowbar_baserole.json")
    node_json = File.join(local_tmpdir,"node.json")
    File.open(role_json,"w") do |f|
      f.write(JSON.pretty_generate(data))
    end
    File.open(node_json,"w") do |f|
      JSON.dump({"run_list" => "role[crowbar_baserole]"},f)
    end
    if nr.role.respond_to?(:jig_role) && !File.exists?("#{chef_path}/roles/#{nr.role.name}.rb")
      # Create a JSON version of the role we will need so that chef solo can pick it up
      File.open("#{local_tmpdir}/#{nr.role.name}.json","w") do |f|
        JSON.dump(nr.role.jig_role(nr),f)
      end
      nr.runlog,ok = BarclampCrowbar::Jig.scp("#{local_tmpdir}/#{nr.role.name}.json root@#{nr.node.name}:/var/chef/roles/#{nr.role.name}.json")
      unless ok
      Rails.logger.error("Chef Solo jig: #{nr.name}: failed to copy dynamic role to target")
        nr.state = NodeRole::ERROR
        return finish_run(nr)
      end
    end
    nr.runlog,ok = BarclampCrowbar::Jig.scp("#{role_json} root@#{nr.node.name}:/var/chef/roles/crowbar_baserole.json")
    unless ok
      Rails.logger.error("Chef Solo jig: #{nr.name}: failed to copy node attribs to target")
      nr.state = NodeRole::ERROR
      return finish_run(nr)
    end
    nr.runlog,ok = BarclampCrowbar::Jig.scp("#{node_json} root@#{nr.node.name}:/var/chef/node.json")
    unless ok
      Rails.logger.error("Chef Solo jig: #{nr.name}: failed to copy node to target")
      nr.state = NodeRole::ERROR
      return finish_run(nr)
    end
    nr.runlog,ok = BarclampCrowbar::Jig.ssh("root@#{nr.node.name} -- chef-solo -j /var/chef/node.json")
    unless ok
      Rails.logger.error("Chef Solo jig run for #{nr.name} failed")
      nr.state = NodeRole::ERROR
      return finish_run(nr)
    end
    node_out_json = File.join(local_tmpdir, "node-out.json")
    res,ok = BarclampCrowbar::Jig.scp("root@#{nr.node.name}:/var/chef/node-out.json #{local_tmpdir}")
    unless ok
      Rails.logger.error("Chef Solo jig run for #{nr.name} did not copy attributes back #{res}")
      nr.state = NodeRole::ERROR
      return finish_run(nr)
    end
    from_node = JSON.parse(IO.read(node_out_json))
    Node.transaction do
      discovery = nr.node.discovery
      discovery["ohai"] = from_node["automatic"]
      nr.node.discovery = discovery
      nr.node.save!
    end
    nr.wall = from_node["normal"]
    nr.state = ok ? NodeRole::ACTIVE : NodeRole::ERROR
    finish_run(nr)
  end
end
    
