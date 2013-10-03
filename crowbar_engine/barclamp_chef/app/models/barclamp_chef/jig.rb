# Copyright 2013, Dell
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
require 'chef'
require 'fileutils'
require 'thread'

class BarclampChef::Jig < Jig
  @@load_role_mutex ||= Mutex.new

  def make_run_list(nr)
    runlist = Array.new
    nr.node.active_node_roles.each do |n|
      next if (n.node.id != nr.node.id) || (n.jig.id != nr.jig.id)
      Rails.logger.info("Chefjig: Need to add #{n.role.name} to run list for #{nr.node.name}")
      runlist << Chef::Role.load(n.role.name).to_s
    end
    runlist << Chef::Role.load(nr.role.name).to_s
    Rails.logger.info("Chefjig: discovered run list: #{runlist}")
    Chef::RunList.new(*runlist)
  end

  def run(nr)
    chef_node, chef_noderole = chef_node_and_role(nr.node)
    unless (Chef::Role.load(nr.role.name) rescue nil)
      # If we did not find the role in question, then the chef
      # data from the barclamp has not been uploaded.
      # Do that here, and then set chef_role.
      chef_path = "/opt/dell/barclamps/#{nr.role.barclamp.name}/chef"
      unless File.directory?(chef_path)
        raise("No Chef data at #{chef_path}")
      end
      role_path = "#{chef_path}/roles"
      data_bag_path = "#{chef_path}/data_bags"
      cookbook_path = "#{chef_path}/cookbooks"
      FileUtils.cd(cookbook_path) do
        unless BarclampChef.knife("cookbook upload -o . -a")
          raise "Could not upload all Chef cookbook components from #{cookbook_path}"
        end
      end if File.directory?(cookbook_path)
      Dir.glob(File.join(data_bag_path,"*")).each do |d|
        data_bag_name = d.split('/')[-1]
        next unless File.directory?(d)
        next if (data_bag_name == "..") || (data_bag_name == ".")
        unless BarclampChef.knife("data bag from file '#{data_bag_name}' '#{d}'")
          raise "Could not upload Chef data bags from #{data_bag_path}/#{data_bag_name}"
        end
      end if File.directory?(data_bag_path)
      if File.exist?("#{role_path}/#{nr.role.name}.rb")
        @@load_role_mutex.synchronize do
          Chef::Config[:role_path] = role_path
          Chef::Role.from_disk(nr.role.name, "ruby").save
        end
      else
        nr.role.jig_role(nr.role.name)
      end

    end
    chef_noderole.default_attributes(nr.all_transition_data)
    chef_noderole.run_list(make_run_list(nr))
    chef_noderole.save
    # For now, be bloody stupid.
    # We should really be much more clever about building
    # and maintaining the run list, but this will do to start off.
    chef_node.attributes.normal = {}
    chef_node.save
    chef_node.run_list(Chef::RunList.new(chef_noderole.to_s))
    chef_node.save
    # SSH into the node and kick chef-client.
    # If it passes, go to ACTIVE, otherwise ERROR.
    nr.runlog, ok = BarclampCrowbar::Jig.ssh("root@#{nr.node.name} chef-client")
    # Reload the node, find any attrs on it that map to ones this
    # node role cares about, and write them to the wall.
    chef_node, chef_noderole = chef_node_and_role(nr.node)
    Node.transaction do
      node_disc = nr.node.discovery
      node_disc["ohai"] = chef_node.attributes.automatic
      nr.node.discovery = node_disc
      nr.node.save!
    end
    exclude_data = nr.all_deployment_data
    exclude_data.deep_merge!(nr.node.all_active_data)
    exclude_data.deep_merge!(nr.sysdata)
    exclude_data.deep_merge!(nr.data)
    nr.wall = deep_diff(exclude_data,chef_node.attributes.normal)
    chef_noderole.default_attributes(nr.all_data)
    chef_noderole.save
    nr.state = ok ? NodeRole::ACTIVE : NodeRole::ERROR
    nr.save!
    # Return ourselves
    return nr
  end

  def create_node(node)
    Rails.logger.info("ChefJig Creating node #{node.name}")
    prep_chef_auth
    cb_nodename = node.name
    cb_noderolename = node_role_name(node)
    chef_node = Chef::Node.build(cb_nodename)
    chef_role = Chef::Role.new
    chef_role.name(cb_noderolename)
    chef_client = Chef::ApiClient.new
    chef_client.name(node.name)
    [chef_node.save, chef_role.save, chef_client.save]
  end

  def delete_node(node)
    prep_chef_auth
    Rails.logger.info("ChefJig Deleting node #{node.name}")
    chef_client = (Chef::ApiClient.load(node.name) rescue nil)
    chef_client.destroy if chef_client
    chef_node_and_role(node).each do |i|
      i.destroy
    end
  end

  private

  def node_role_name(node)
    "crowbar-#{node.name.tr(".","_")}"
  end

  def chef_node_and_role(node)
    prep_chef_auth
    [Chef::Node.load(node.name),Chef::Role.load(node_role_name(node))]
  end

  def prep_chef_auth
    reload if server.nil? || server.empty?
    Chef::Config[:client_key] = key
    Chef::Config[:chef_server_url] = server
    Chef::Config[:node_name] = client_name
  end

  # Return all keys from hash A that do not exist in hash B, recursively
  def deep_diff(a,b)
    raise "Only pass hashes to deep_diff" unless a.kind_of?(Hash) && b.kind_of?(Hash)
    # Base case, hashes are equal.
    res = Hash[]
    b.each do |k,v|
      case
        # Simple cases first:
        # if a does not have a key named k, then b[k] is in the result set.
      when !a.has_key?(k) then res[k] = v
        # if a[k] == v, then k is not in the result set.
      when a[k] == v then next
        # a[k] != v, and both are Hashes.  res[k] is their deep_diff.
      when a[k].kind_of?(Hash) && v.kind_of?(Hash)
        maybe_res = deep_diff(a[k],v)
        res[k] = maybe_res unless maybe_res.nil? || maybe_res.empty?
        # v wins.
      else res[k] = v
      end
    end
    res
  end

end # class
