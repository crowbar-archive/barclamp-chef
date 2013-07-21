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


# Wrapper around a bare minimum of functionaloty needed to represent Chef nodes.
class BarclampChef::Node

  attr_reader :data

  # Get all the node names that Chef knows about.
  def self.names
    IO.popen("knife node list") do |p|
      return p.readlines.map {|n|n.strip}
    end
  end
  
  def initialize(n)
    name = self.class.namify(n)
    IO.popen("knife node show -f json #{name}") do |p|
      @data = JSON.parse(p.read)
    end
  end

  # Create a new Chef node object and return it.
  def self.create(n)
    name = namify(n)
    raise "Could not create Chef node #{name}" unless system("knife node create #{name}")
    self.new(name)
  end

  def destroy(n)
    name = self.class.namify(n)
    raise "Could not destroy Chef node #{name}" unless system("knife node destroy #{name}")
  end

  private

  def self.namify(n)
    case
    when n.kind_of?(n) == String then n
    when n.kind_of?(::Node) then n.name
    else raise "Cannot handle #{n.inspect!}"
    end
  end
end

class BarclampChef::Role

  # Get all the node names that Chef knows about.
  def self.names
    IO.popen("knife role list") do |p|
      return p.readlines.map {|n|n.strip}
    end
  end
  
  def initialize(n)
    IO.popen("knife role show -f json #{n}") do |p|
      @data = JSON.parse(p.read)
    end
  end

  # Create a new Chef node object and return it.
  def self.create(n)
    raise "Could not create Chef role #{n}" unless system("knife role create #{n}")
    self.new(n)
  end

  def destroy(n)
    raise "Could not destroy Chef role #{n}" unless system("knife role destroy #{n}")
  end

end

class BarclampChef::Client

  # Get all the node names that Chef knows about.
  def self.names
    IO.popen("knife client list") do |p|
      return p.readlines.map {|n|n.strip}
    end
  end
  
  def initialize(n)
    IO.popen("knife client show -f json #{n}") do |p|
      @data = JSON.parse(p.read)
    end
  end

  # Create a new Chef node object and return it.
  def self.create(n)
    raise "Could not create Chef client #{n}" unless system("knife client create #{n}")
    self.new(n)
  end

  def destroy(n)
    raise "Could not destroy Chef client #{n}" unless system("knife client destroy #{n}")
  end


end

class BarclampChef::Jig < Jig
  
  def run(nr)
    cb_node = nr.node
    cb_role = nr.role 
    chef_node = BarclampChef::Node.new(nr.node.name)
    chef_role = BarclampChef::Role.new(nr.role.name)
    # Magically create a shiny new Chef node role with the combined attrs
    # of all the noderole parents and a runlist of all the Chef roles from
    # the noderole parents, and then bind it as the only entry in that node's runlist

    # Then, run chef-client on the node.
  end

  def create_node(node)
    Rails.logger.info("ChefJig Creating node #{node.name}")
    BarclampChef::Node.create(node.name)
    BarclampChef::Role.create("crowbar-#{node.name}")
    BarclampChef::Client.create(node.name)
  end

  def delete_node(node)
    Rails.logger.info("ChefJig Deleting node #{node.name}")
    BarclampChef::Node.destroy(node.name)
    BarclampChef::Role.destroy("crowbar-#{node.name}")
    BarclampChef::Client.destroy(node.name)
  end
end # class
