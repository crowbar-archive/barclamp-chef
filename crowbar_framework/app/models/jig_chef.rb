# Copyright 2012, Dell
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

require 'monkeypatch/rest'

class JigChef < Jig

  has_one :jig_chef_conn_info, :dependent => :destroy

  def init
    Chef::Config.node_name CHEF_NODE_NAME
    Chef::Config.client_key CHEF_CLIENT_KEY
    Chef::Config.chef_server_url CHEF_SERVER_URL
    super.init  
  end


  def prepare_chef_api
    conn_info = self.jig_chef_conn_info
    logger.info("No Chef connection info") and return unless conn_info
    Chef::Config.node_name = conn_info.client_name
    Chef::Config.chef_server_url = conn_info.url
    ReplacementAuthMod.replace_authenticator(conn_info.client_name, conn_info.key)
  end



  def apply_proposal(new_config)    
    ## for now, just call super
    super.apply_proposal(new_config)
  end

  #### 
  # create the relevant structures in Chef that are needed before any run can be executed  
  def prepare_for_execution(event, config) 

    # find dependent proposals
    # for every proposal, ensure there's a config-role for the proposal

    # for every node config, ensure there's a node-role, that merges the config 
    # from all applicable configurations. The run list will be computed as 
    # runs are executed.

  end


  def create_event(config)
    evt = JigEvent.create(:type=>"JigEvent", :proposal_confing =>config, 
      :jig => self, :status => JigEvent::EVT_PENDING, :name=>"apply_#{config.id}")
    evt
  end

  def create_run_for(evt, nr,order)
    run = JigRunChef.create(:type=> "JigRunChef", :jig_event => evt, 
      :node_role => nr, :order=>order, :status => JigRun::RUN_PENDING, 
      :name=>"run_#{evt.id}_#{nr.id}_#{order}")
    run
  end

  def delete_node(node)
    name = node.name
    Rails.logger.info("Chef Jig #{self.name} is removing the node #{name} from the system")
    system("knife node delete -y #{name} -u chef-webui -k /etc/chef/webui.pem")
    system("knife client delete -y #{name} -u chef-webui -k /etc/chef/webui.pem")
    # TODO this may not be needed in the new Crowbar 2 design
    system("knife role delete -y crowbar-#{name.gsub(".","_")} -u chef-webui -k /etc/chef/webui.pem")
  end

  def node(name)
    begin 
      chef_init
      super.node name
      return Chef::Node.load(name)
    rescue Exception => e
      Rails.logger.warn("Could not recover Node on load #{name}: #{e.inspect}")
      return nil
    end
  end

  def data(bag_item)
    begin 
      chef_init
      super.data bag_item
      return Chef::DataBag.load "crowbar/#{bag_item}"
    rescue Exception => e
      Rails.logger.warn("Could not recover Chef Crowbar Data on load #{bag_item}: #{e.inspect}")
      return nil
    end
  end
  
  private
    
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
  
end


