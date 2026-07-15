/ip dhcp-server option
set [find where name="${ROS_GATEWAY_OPTION_NAME}"] value="'${OLD_GATEWAY_IP}'" comment="rollback_gateway"
set [find where name="${ROS_DNS_OPTION_NAME}"] value="'${OLD_GATEWAY_IP}'" comment="rollback_dns"

/ipv6 nd
set [find where interface="${ROS_LAN_INTERFACE}"] ra-lifetime=30m dns=2400:3200::1,2400:3200:baba::1

