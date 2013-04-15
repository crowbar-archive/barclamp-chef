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

module ReplacementAuthMod
  @@client_name = nil
  @@raw_key = nil
  @@url = nil
  @@active = false
  @@sem = Mutex.new

  def self.replace_authenticator(url, client_name, raw_key)
    unless @@active
      @@sem.synchronize do
        @@client_name = client_name
        @@raw_key = raw_key
        @@url = url
        Chef::REST.__send__(:include, ReplacementAuthMod)
        @@active=true
      end
    end
  end

  def self.client_name
    @@client_name
  end

  def self.raw_key
    @@raw_key
  end

  def self.url
    @@url
  end

  def self.active
    @@active
  end

  class Chef::REST
    alias_method :orig_initialize, :initialize
    def initialize(url, client_name=Chef::Config[:node_name], signing_key_filename=nil, options={})
      if ReplacementAuthMod.active
        url = ReplacementAuthMod.url
        client_name = ReplacementAuthMod.client_name
        options[:raw_key] = ReplacementAuthMod.raw_key
        signing_key_filename=nil
      end
      orig_initialize(url,client_name,signing_key_filename,options)
    end
  end
end

# Due to the way we are injecting Chef auth info, this has to be a singleton class.
class BarclampChef::Jig < Jig
  @@sem = Mutex.new
  @@instance = nil

  def after_initialize
    raise "No Chef server to talk to!" unless server
    active = true
    save!
  end

  @@sem.synchronize do
    unless @@instance
      @@instance = BarclampChef::Jig.find_by_name('admin_chef')
      if @@instance
        ReplacementAuthMod.replace_authenticator(@@instance.server,@@instance.client_name,@@instance.key)
        def self.new
          @@instance
        end
      end
    end
  end

=begin
  Get a list of the node names as know to chef.
  Returns an array of node names.
=end
  def get_node_names
    Chef::Node.list.keys
  end

=begin
  Return a hash in the form of node-name=>chef node object.
  This should only be used within the chef barclamp!.
=end
  def get_inflated_node_list
    Chef::Node.list(true)
  end

  def create_node(node)
    @@sem.synchronize do
      role_name = "crowbar-#{node.name.tr('.','_')}"
      chef_node = Chef::Node.find_or_create(node.name)
      client = Chef::ApiClient.new
      client.name(node.name)
      client.admin(!!node.admin)
      c = client.save
      raise "Chef Client for #{node.name} already exists!" unless c['private_key']
      role = (Chef::Role.load(node.name) rescue nil)
      unless role
        role = Chef::Role.new
        role.name(role_name)
        role.save
      end
      dest = node.admin ? "/etc/chef" : "/updates/#{node.name}"
      Rails.logger.info(%x{sudo mkdir -p "#{dest}"})
      Rails.logger.info(%x{sudo touch "#{dest}/client.pem"})
      Rails.logger.info(%x{sudo chmod 666 "#{dest}/client.pem"})
      File.open("#{dest}/client.pem","w") do |f|
        f.puts(c['private_key'])
      end
      Rails.logger.info(%x{sudo chmod 444 "#{dest}/client.pem"})
      chef_node.save
      true
    end
  end

  def delete_node(node)
    raise "Cannot delete admin node #{node.name}" if node.admin
    name = node.name
    @@sem.synchronize do
      role_name = "crowbar-#{name.tr('.','_')}"
      begin
        Chef::Node.load(name).destroy
        Chef::ApiClient.load(name).destroy
        Chef::Role.load(role_name).destroy
        if File.exists?("/updates/#{name}/client.pem")
          Rails.logger.info(%x{sudo rm -rf "/updates/#{name}"})
        end
      rescue Exception => e
        Rails.logger.fatal("Could not destroy Chef node #{name}: #{e.inspect}")
      end
    end
  end

=begin
Defined by the framework #Jig base class. Return a JSON representation of the 
information this jig knows about this node.
=end
  def read_node_data(node)
    n = Chef::Node.load(node.name)
    JSON.parse(n.nil? ? '{}' : n.merged_attributes.to_json)
  end
end # class