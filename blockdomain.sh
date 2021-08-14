#!/bin/evn bash
read -p "Enter Domanin Name You Need to blocking it :" $DOMAINNAME
echo "$DOMAINNAME : ALL" >> /etc/hosts.deny
yum install iptables-services
systemctl enable iptables
systemctl restart iptables
systemctl status iptables
iptables -A OUTPUT -j DROP -d $DOMAINNAME
iptables -A INPUT -j DROP -d $DOMAINNAME
iptables -A FORWARD -j DROP -d $DOMAINNAME
iptables -A INPUT -m string --algo bm --string "$DOMAINNAME" -j DROP
iptables -A FORWARD -m string --algo bm --string "$DOMAINNAME" -j DROP
iptables -A OUTPUT -m string --algo bm --string "$DOMAINNAME" -j DROP
/sbin/iptables-save > /etc/sysconfig/iptables
/sbin/iptables-save