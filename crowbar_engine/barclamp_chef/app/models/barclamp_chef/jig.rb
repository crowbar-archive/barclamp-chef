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
      runlist << "role[#{n.role.name}]"
    end
    runlist << "role[#{nr.role.name}]"
    Rails.logger.info("Chefjig: discovered run list: #{runlist}")
    Chef::RunList.new(*runlist)
  end

  def stage_run(nr)
    prep_chef_auth
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
      Dir.glob(File.join(data_bag_path,"*.json")).each do |d|
        data_bag_name = d.split('/')[-1]
        next unless File.directory?(d)
        next if (data_bag_name == "..") || (data_bag_name == ".")
        unless BarclampChef.knife("data bag from file '#{data_bag_name}' '#{d}'")
          raise "Could not upload Chef data bags from #{data_bag_path}/#{data_bag_name}"
        end
      end if File.directory?(data_bag_path)
      if nr.role.respond_to?(:jig_role)
        Chef::Role.json_create(nr.role.jig_role(nr)).save
      elsif File.exist?("#{role_path}/#{nr.role.name}.rb")
        @@load_role_mutex.synchronize do
          Chef::Config[:role_path] = role_path
          Chef::Role.from_disk(nr.role.name, "ruby").save
        end
      else
        raise "Could not find or synthesize a Chef role for #{nr.name}"
      end
    end
    return {
      :runlist => make_run_list(nr),
      :data => nr.all_transition_data
    }
  end

  def run(nr,data)
    prep_chef_auth
    chef_node, chef_noderole = chef_node_and_role(nr.node)
    chef_noderole.default_attributes(data[:data])
    chef_noderole.run_list(data[:runlist])
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
    new_attrs = chef_node.attributes.normal
    nr.wall = deep_diff(data,new_attrs)
    chef_noderole.default_attributes(data.deep_merge(new_attrs))
    chef_noderole.save
    nr.state = ok ? NodeRole::ACTIVE : NodeRole::ERROR
    # Return ourselves
    finish_run(nr)
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

end # class
