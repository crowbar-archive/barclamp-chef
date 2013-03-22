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
# Author: aabes


#####
# This job class creates within chef the configuration for a deployment/snapshot
# in the form of a "config" role, that will be added to each node participating
# in the deployment.

class BarclampChef::JobSnapshotConfig < Jobs::SnapshotJigConfig 

  def perform
    try 
      r = Chef::Role.load(full_name)      
    rescue
      r = Chef::Role.new(full_name)
    end

    configAttrs = {}
    find_config.each { |attr|
      configAttrs[attr.attrib_type.name] = attr.value_request
    }
    r.override_attributes = configAttrs
    r.save
  end

end

