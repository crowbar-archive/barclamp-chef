# Copyright 2013, Dell
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
class CreateChefAdminInstance < ActiveRecord::Migration
  def up
    ### this will soon  move to be created as part of applying the chef proposal...
    BarclampChef::Jig.find_or_create_by_name :name =>'admin_chef', :order => 100
    BarclampChef::Jig.find_or_create_by_name :name =>'chef', :order => 200
  end

  def down
    Jig.delete(BarclampChef::Jig.delete_all)
  end
end


