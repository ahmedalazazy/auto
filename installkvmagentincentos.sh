#!/bin/bash
if [  -n "$(uname -a | grep Ubuntu)" ]; then
    apt-get -y update && apt-get -y upgrade
    systemctl status qemu-guest-agent
    apt-get install -y qemu-guest-agent
    systemctl start qemu-guest-agent
    systemctl enable qemu-guest-agent 
else
    yum -y update && yum -y upgrade
    systemctl status qemu-guest-agent
    yum install -y qemu-guest-agent
    systemctl start qemu-guest-agent
    systemctl enable qemu-guest-agent
fi  
