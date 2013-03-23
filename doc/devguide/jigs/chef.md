### Chef Jig

The Chef Jig in the Chef Barclamp allows Crowbar to get data from Chef (inbound) and create roles / set attributes into Chef (outbound)

#### Adding Chef Jig into a dev system

bundle exec rake crowbar:chef:inject_conn url=http://127.0.0.1:4000 name=admin key_file=/etc/chef/client.pem