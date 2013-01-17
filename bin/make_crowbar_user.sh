#!/bin/bash

[[ $DEBUG ]] && { echo "debug on"; set -x; }
export EDITOR=/bin/true 
export HOME=/root

## only do this on real installs.
[[ -d /opt/dell ]] || { echo "No /opt/dell, not creating client"; exit 0; }
knife client show crowbar -a admin -u chef-webui -k /etc/chef/webui.pem  &>/dev/null || CREATE=1

if [[ $CREATE ]]; then
  echo "Creating crowbar user"
  knife client create crowbar -a --file /opt/dell/crowbar_framework/config/client.pem -u chef-webui -k /etc/chef/webui.pem
fi