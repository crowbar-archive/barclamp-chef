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

class BarclampChef::Jig < Jig

  def run(nr)
    chef_node, chef_noderole = chef_node_and_role(nr.node)
    chef_role = (Chef::Role.load(nr.role.name) rescue nil)
    unless chef_role
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
      unless File.exist?("#{role_path}/#{nr.role.name}.rb")
        raise "Missing Chef role information for #{nr.role.barclamp.name}:#{nr.role.name}!"
      end
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
      unless BarclampChef.knife("role from file '#{role_path}/#{nr.role.name}.rb'")
        raise "Could not load Chef role from #{role_path}/#{nr.role.name}"
      end
      chef_role = Chef::Role.load(nr.role.name)
    end
    chef_noderole.default_attributes(nr.all_data)
    chef_noderole.save
    # For now, be bloody stupid.
    # We should really be much more clever about building
    # and maintaining the run list, but this will do to start off.
    chef_node.run_list(Chef::RunList.new(chef_noderole.to_s,chef_role.to_s))
    chef_node.save
    # SSH into the node and kick chef-client.
    # If it passes, go to ACTIVE, otherwise ERROR.
    out,ok = BarclampCrowbar::Jig.ssh("root@#{nr.node.name} chef-client")
    nr.state = ok ? NodeRole::ACTIVE : NodeRole::ERROR
    # Log the results of the run using Rails.logger.info.
    Rails.logger.info(out)
    # Reload the node, find any attrs on it that map to ones this
    # node role cares about, and write them to the wall.
    chef_node, chef_noderole = chef_node_and_role(nr.node)
    Node.transaction do
      node_disc = nr.node.discovery
      node_disc["ohai"] = chef_node.attributes.automatic
      nr.node.discovery = node_disc
    end
    nr.wall = chef_node.attributes.normal
    chef_node.attributes.normal = {}
    chef_noderole.default_attributes(nr.all_data)
    chef_node.save
    chef_noderole.save
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
    Chef::Config[:client_key] = key
    Chef::Config[:chef_server_url] = server
    Chef::Config[:node_name] = client_name
  end


end # class
