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

require 'barclamp_chef/chef_api'

module BarclampChef 
  class Jig < Jig
  
    has_one :jig_chef_conn_info, :dependent => :destroy
  
    def create_event(config)
      evt = JigEvent.create(:type=>"JigEvent", :proposal_confing =>config, 
        :jig => self, :status => JigEvent::EVT_PENDING, :name=>"apply_#{config.id}")
      evt
    end
  
    def create_run_for(evt, nr,order)
      run = JigRunChef.create(:type=> "JigRunChef", :jig_event => evt, 
        :role => nr, :order=>order, :status => JigRun::RUN_PENDING, 
        :name=>"run_#{evt.id}_#{nr.id}_#{order}")
      run
    end

    def create_node(node)
      # Evil, dirty hack to create a Chef version of the node as well.
      # This should be replaced with a direct API call once the API is working well enough.
      Rails.logger.info(%x{knife node create #{node.name} --defaults -d})
      Rails.logger.info(%x{knife role create "crowbar-#{node.name.tr('.','_')}" --defaults -d})
      dest = node.admin ? "/etc/chef" : "/updates/#{node.name}" 
      Rails.logger.info(%x{sudo mkdir -p "#{dest}"})
      Rails.logger.info(%x{sudo knife client create #{node.name} --defaults -d -f "#{dest}/client.pem"})
    end

    def delete_node(node)
      # Ditto.
      raise "Cannot delete admin node #{node.name}" if node.admin
      Rails.logger.info(%x{knife node delete -y #{node.name}})
      Rails.logger.info(%x{knife client delete -y #{node.name}})
      if File.exists?("/updates/#{node.name}/client.pem")
        Rails.logger.info(%x{sudo rm -rf "/updates/#{node.name}"})
      end
      Rails.logger.info(%x{knife role delete -y "crowbar-#{node.name.tr('.','_')}"})
    end

=begin
  Defined by the framework #Jig base class. Return a JSON representation of the 
  information this jig knows about this node.
=end    
    def read_node_data(node)
      BarclampChef::ChefAPI.prepare_chef_api(jig_chef_conn_info)
      n= BarclampChef::ChefAPI.load_node(node.name)
      return JSON.parse('{}') unless n
      n.merged_attributes.to_json
    end   
  end # class
end # module
