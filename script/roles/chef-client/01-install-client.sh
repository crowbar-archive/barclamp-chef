#!/bin/bash
which chef-client && exit 0

if [[ -f /etc/redhat-release || -f /etc/centos-release ]]; then
    yum install -y chef
elif [[ -d /etc/apt ]]; then
    apt-get -y install chef
elif [[ -f /etc/SuSE-release ]]; then
    OS=suse
    exit 1
else
    die "Staged on to unknown OS media!"
fi
