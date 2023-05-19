#!/bin/sh


IPTABLES=/sbin/iptables

#Setting the EXTERNAL and INTERNAL interfaces and addresses for the network
EXTIF="ens3"
EXTIP1="91.80.99.106"

UNIVERSE="0.0.0.0/0"

#Clearing any previous configuration

$IPTABLES -P INPUT DROP
$IPTABLES -F INPUT
$IPTABLES -P OUTPUT ACCEPT
$IPTABLES -F OUTPUT
$IPTABLES -P FORWARD ACCEPT
$IPTABLES -F FORWARD
# Otherwise, I can not seem to delete it later on
$IPTABLES -F add-to-connlimit-list
# Delete user defined chains
$IPTABLES -X
# Reset all IPTABLES counters
$IPTABLES -Z

echo "...load xt_recent..."
modprobe -r xt_recent
modprobe xt_recent ip_list_tot=5000 ip_pkt_list_tot=128
echo "...load list limitation..."
#######################################################################
# USER DEFINED CHAIN SUBROUTINES:
#
# add-to-connlimit-list
# To many connections from an IP address has been detected.
$IPTABLES -N add-to-connlimit-list
$IPTABLES -A add-to-connlimit-list -m recent --set --name BADGUY_CONN
$IPTABLES -A add-to-connlimit-list -j DROP
echo "...Accept incomming traffic..."

# loopback interfaces are valid.
#
$IPTABLES -A INPUT -i lo -s $UNIVERSE -d $UNIVERSE -j ACCEPT
$IPTABLES -A INPUT -p tcp ! --syn -m state --state NEW -j REJECT

# Just DROP invalid packets.
$IPTABLES -A INPUT -i $EXTIF -p tcp -m state --state INVALID -j DROP


# external interface, from any source, for any remaining ICMP traffic is valid
$IPTABLES -A INPUT -i $EXTIF -p ICMP -s $UNIVERSE -j DROP

#allow TcpPorts
$IPTABLES -A INPUT -i $EXTIF -m recent --update --hitcount 1 --seconds 432000 --name BADGUY_CONN -j DROP
$IPTABLES -A INPUT -i $EXTIF -d $EXTIP1 -p tcp -m connlimit --connlimit-above 20 -j add-to-connlimit-list

$IPTABLES -A INPUT -i $EXTIF -d $EXTIP1 -m state --state NEW -p tcp -j ACCEPT

echo "protect all tcp ports"

#udp

$IPTABLES -A INPUT -i $EXTIF -d $EXTIP1 -p udp -m connlimit --connlimit-above 20 -j add-to-connlimit-list
$IPTABLES -A INPUT -i $EXTIF -d $EXTIP1 -m state --state NEW -p udp -j ACCEPT

echo "Protect all udp ports"


$IPTABLES -A INPUT -i $EXTIF -s $UNIVERSE -d $EXTIP1 -m state --state ESTABLISHED,RELATED -j ACCEPT

echo "Allow any related traffic"



$IPTABLES -A INPUT -i $EXTIF -p udp -m multiport --dport 33434:33448 -j DROP
$IPTABLES -A INPUT -i $EXTIF -p tcp -m multiport --dport 23,2323 -j DROP


$IPTABLES -A INPUT -s $UNIVERSE -d $UNIVERSE -j DROP
