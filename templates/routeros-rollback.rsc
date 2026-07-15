/ip dhcp-server option
set [find where name="${ROS_GATEWAY_OPTION_NAME}"] value="'${OLD_GATEWAY_IP}'" comment="rollback_gateway"
set [find where name="${ROS_DNS_OPTION_NAME}"] value="'${OLD_GATEWAY_IP}'" comment="rollback_dns"
