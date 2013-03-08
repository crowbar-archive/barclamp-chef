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

  class ChefAPI

=begin
    Prepare the chef objects for use, by injecting the appropriate authentication 
    info from the DB.
=end
    def self.prepare_chef_api(conn_info)
      logger.info("No Chef connection info") and return unless conn_info
      #Chef::Config.node_name = conn_info.client_name
      #Chef::Config.chef_server_url = conn_info.url
      #Chef::Config.client_key='/home/crowbar/.chef/crowbar.pem'
      ReplacementAuthMod.replace_authenticator(conn_info.url,conn_info.client_name, conn_info.key)
    end

  end

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
       return Chef::Search::Query.new
     rescue
       return Chef::Node.new
     end
    end

end
