# Copyright 2013, Dell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
require File.join(File.dirname(__FILE__),"monkeypatch","rest")

module BarclampChef
  class ChefApi

=begin
    Prepare the chef objects for use, by injecting the appropriate authentication 
    info from the DB.
    Note that because of the way chef internal code is written, these settings are
    GLOBAL for the app...(have to use static overrides to inject the connection info since
    Node,Query,Data bag and frieds do funny inconsistent things (as of Chef 11.04))

    When support for lots of chef servers is possibly added.. this should be addressed.
=end
    def self.prepare_chef_api(jig)
      raise "this should not be called - do in jig initialize"
    end


=begin
  Get a list of the nodes' names as know to chef.
  Returns an array of node names.
=end
    def get_node_names
      Chef::Node.list.keys
    end

=begin
  Given a node name, load the Chef node data into object form.  
=end
    def load_node(name)
      Chef::Node.load(name)
    end

=begin
  Return a hash in the form of node-name=>chef node object.
  This should only be used within the chef barclamp!.
=end
    def get_inflated_node_list
      nl = Chef::Node.list(true)
    end

private
 
    def node(name)
     begin 
       super.node name
       return Chef::Node.load(name)
     rescue Exception => e
       Rails.logger.warn("Could not recover Node on load #{name}: #{e.inspect}")
       return nil
     end
    end
    
    
    def data(bag_item)
     begin 
       super.data bag_item
       return Chef::DataBag.load "crowbar/#{bag_item}"
     rescue Exception => e
       Rails.logger.warn("Could not recover Chef Crowbar Data on load #{bag_item}: #{e.inspect}")
       return nil
     end
    end
    
    def client(name)
      begin
        return ClientObject.new Chef::ApiClient.load(name)
      rescue Exception => e
        Rails.logger.fatal("Failed to find client: #{name} #{e.message}")
        return nil
      end
    end
    
    def role(name)
      begin
        return RoleObject.new Chef::Role.load(name)
      rescue
        return nil
      end
    end
    
    def chef_escape(str)
     str.gsub("-:") { |c| '\\' + c }
    end
    
    def query_chef
      begin
        chef_init
        return Chef::Search::Query.new
      rescue
        return Chef::Node.new
      end
    end

end #ChefApi
end # module
