#!/bin/bash

ensure_service_running () {
    service="$1"
    regexp="${2:-running}"
    if service $service status | egrep -q "$regexp"; then
        echo "$service is already running - no need to start."
    else
        service $service start
    fi
}

die() {
    echo "$(date '+%F %T %z'): $@"
    exit 1
}

if [[ -f /etc/redhat-release || -f /etc/centos-release ]] && [[ ! -d /etc/chef-server ]]; then
    OS=redhat
    yum install -y chef chef-server
elif [[ -d /etc/apt ]]; then
    OS=ubuntu
    apt-get -y install chef chef-server
elif [[ -f /etc/SuSE-release ]]; then
    if grep -q openSUSE /etc/SuSE-release; then
        OS=opensuse
        zypper install -y -l chef chef-server
    else
        OS=suse
    fi
else
    die "Staged on to unknown OS media!"
fi

if [[ $OS = ubuntu || $OS = redhat || $OS = opensuse ]] && [[ ! -x /etc/init.d/chef-server ]]; then
    # Set up initial config
    chef-server-ctl reconfigure
    mkdir -p /etc/chef-server
    chef-server-ctl test || {
        echo "Could not bring up valid chef server!"
        exit 1
    }
    mkdir -p /etc/chef
    ln -s /etc/chef-server/chef-webui.pem /etc/chef/webui.pem
    ln -s /etc/chef-server/chef-validator.pem /etc/chef/validation.pem
    cat > /etc/init.d/chef-server <<EOF
#!/bin/bash
### BEGIN INIT INFO
# Provides:          chef-server
# Required-Start:    \$syslog \$network \$named
# Required-Stop:     \$syslog \$network \$named
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start chef-server at boot time
# Description:       Enable chef server
### END INIT INFO

# chkconfig 2345 10 90
# description Chef Server wrapper
exec chef-server-ctl "\$@"
EOF
    chmod 755 /etc/init.d/chef-server
    if [[ $OS = ubuntu ]]; then
        update-rc.d chef-server defaults
        update-rc.d chef-server enable
    else
        chkconfig chef-server on
    fi
elif [[ $OS = suse ]]; then
    # Default password in chef webui to password
    sed -i 's/web_ui_admin_default_password ".*"/web_ui_admin_default_password "password"/' \
        /etc/chef/webui.rb
    chkconfig rabbitmq-server on
    if ! rabbitmqctl status > /dev/null 2>&1; then
	echo "RabbitMQ not running. Starting..."
	chkconfig rabbitmq-server on
	ensure_service_running rabbitmq-server || \
            die "Cannot start rabbitmq-server. Aborting."
        sleep 5
    fi
    rabbitmqctl list_vhosts | grep -q '^/chef' || \
        rabbitmqctl add_vhost /chef || \
        die "Could not create default rabbitmq Chef vhost"
    rabbitmqctl list_users | grep -q chef || {
        rabbitmqctl add_user chef "$rabbit_chef_password"
        # Update "amqp_pass" in  /etc/chef/server.rb and solr.rb
        sed -i 's/amqp_pass ".*"/amqp_pass "'"$rabbit_chef_password"'"/' /etc/chef/{server,solr}.rb
    } || die "Could not create rabbitmq Chef user"
    rabbitmqctl list_permissions |grep -q chef || \
	rabbitmqctl set_permissions -p /chef chef ".*" ".*" ".*" || \
        die "Could not set proper rabbitmq Chef permissions."
    echo "Starting CouchDB..."
    chkconfig couchdb on
    ensure_service_running couchdb

    services='solr expander server server-webui'
    for service in $services; do
        chkconfig chef-${service} on
    done

    for service in $services; do
        ensure_service_running chef-${service}
    done

    # chef-server-webui won't start if /etc/chef/webui.pem doesn't exist, which
    # may be the case (chef-server generates it if not present, and if the webui
    # starts too soon, it won't be there yet).
    for ((x=1; x<6; x++)); do
        sleep 10
        service chef-server-webui status >/dev/null && { chef_webui_running=true; break; }
        service chef-server-webui start
    done
    if [[ ! $chef_webui_running ]]; then
        echo "WARNING: unable to start chef-server-webui"
    fi
    perl -i -pe 's{<maxFieldLength>.*</maxFieldLength>}{<maxFieldLength>200000</maxFieldLength>}' /var/lib/chef/solr/conf/solrconfig.xml

    service chef-solr restart
fi

if [[ ! -e $HOME/.chef/knife.rb ]]; then
    echo "Creating chef client for root on admin node"
    mkdir -p "$HOME/.chef"
    EDITOR=/bin/true knife client create root -a --file "$HOME/.chef/client.pem" -u chef-webui -k /etc/chef-server/chef-webui.pem -s "https://$(hostname --fqdn)"
    cat > "$HOME"/.chef/knife.rb <<EOF
log_level                :info
log_location             STDOUT
node_name                'root'
client_key               '$HOME/.chef/client.pem'
validation_client_name   'chef-validator'
validation_key           '/etc/chef-server/chef-validator.pem'
chef_server_url          'https://$(hostname --fqdn)'
syntax_check_cache_path  '$HOME/.chef/syntax_check_cache'
EOF
fi

# Create a client for the Crowbar user.
if [[ ! -e /home/crowbar/.chef/knife.rb ]]; then
    echo "Creating chef client for Crowbar on admin node"
    mkdir /home/crowbar/.chef
    KEYFILE="/home/crowbar/.chef/crowbar.pem"
    EDITOR=/bin/true knife client create crowbar -a --file $KEYFILE -u chef-webui -k /etc/chef-server/chef-webui.pem
    cat > /home/crowbar/.chef/knife.rb <<EOF
log_level                :info
log_location             STDOUT
node_name                'crowbar'
client_key               '$KEYFILE'
validation_client_name   'chef-validator'
validation_key           '/etc/chef-server/chef-validator.pem'
chef_server_url          'https://$(hostname --fqdn)'
syntax_check_cache_path  '/home/crowbar/.chef/syntax_check_cache'
EOF
    chown -R crowbar:crowbar /home/crowbar/.chef/
fi
