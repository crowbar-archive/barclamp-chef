#!/bin/bash

if ! which chef-client; then
    if [[ -f /etc/redhat-release || -f /etc/centos-release ]]; then
        yum -y makecache
        yum install -y chef
    elif [[ -d /etc/apt ]]; then
        apt-get -y update
        # Our chef package does not need ruby, but it does need the cstruct gem.
        apt-get -y --force-yes install ruby1.9.1 ruby1.9.1-dev chef
        gem install cstruct
        service chef-client stop
    elif [[ -f /etc/SuSE-release ]]; then
        zypper install -y -l chef
    else
        die "Staged on to unknown OS media!"
    fi
fi


mkdir -p "/etc/chef"
url=$(read_attribute "chefjig/server/url")
clientname=$(read_attribute "chefjig/client/name")
cat > "/etc/chef/client.rb" <<EOF
log_level       :info
log_location    STDOUT
node_name       '$clientname'
chef_server_url '$url'
client_key      '/etc/chef/client.pem'
EOF

read_attribute "chefjig/client/key" > "/etc/chef/client.pem"
