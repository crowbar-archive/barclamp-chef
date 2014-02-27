# Copyright 2014, Dell
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

class BarclampChef::Role < Role

  BERKSHELF_PATH="/opt/dell/barclamps/openstack/chef-solo/berkshelf"

  def on_proposed(nr)
    chef_path = "/opt/dell/barclamps/#{nr.role.barclamp.name}/chef-solo"
    berksfile = "#{chef_path}/Berksfile"
    dest_package = "#{chef_path}/cookbooks/#{BarclampChef::SoloJig::BERKSHELF_PACKAGE}"

    if File.exists?(berksfile) && !File.exists?(dest_package)
      result = %x(cd #{chef_path}; BERKSHELF_PATH=#{BERKSHELF_PATH} berks package 2>&1)
      unless $?.exitstatus == 0
        raise "Unable to berks package #{chef_path}: #{result}"
      end

      File.rename("#{chef_path}/#{BarclampChef::SoloJig::BERKSHELF_PACKAGE}",
          "#{chef_path}/cookbooks/#{BarclampChef::SoloJig::BERKSHELF_PACKAGE}")
    end
  end
end
