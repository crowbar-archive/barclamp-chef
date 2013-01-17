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
class CreateChefConnInfo < ActiveRecord::Migration
  def change
    create_table :jig_chef_conn_infos do |t|
      t.string :url
      t.string :client_name
      t.string :key
      t.string :key_file_name
      t.references :jig_chef
    end
  end
end
