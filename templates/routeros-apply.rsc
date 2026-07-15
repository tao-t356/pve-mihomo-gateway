# Review before pasting into RouterOS 7 terminal.
/export hide-sensitive file=before-pve-mihomo-gateway

:if ([:len [/ip dhcp-server option find where name="${ROS_GATEWAY_OPTION_NAME}"]] = 0) do={
  /ip dhcp-server option add code=3 name="${ROS_GATEWAY_OPTION_NAME}" value="'${MIHOMO_IP}'" comment="gateway_to_mihomo"
} else={
  /ip dhcp-server option set [find where name="${ROS_GATEWAY_OPTION_NAME}"] value="'${MIHOMO_IP}'" comment="gateway_to_mihomo"
}

:if ([:len [/ip dhcp-server option find where name="${ROS_DNS_OPTION_NAME}"]] = 0) do={
  /ip dhcp-server option add code=6 name="${ROS_DNS_OPTION_NAME}" value="'${AGH_IP}'" comment="dns_to_adguard"
} else={
  /ip dhcp-server option set [find where name="${ROS_DNS_OPTION_NAME}"] value="'${AGH_IP}'" comment="dns_to_adguard"
}

:if ([:len [/ip dhcp-server option sets find where name="${ROS_OPTION_SET_NAME}"]] = 0) do={
  /ip dhcp-server option sets add name="${ROS_OPTION_SET_NAME}" options="${ROS_GATEWAY_OPTION_NAME},${ROS_DNS_OPTION_NAME}"
} else={
  /ip dhcp-server option sets set [find where name="${ROS_OPTION_SET_NAME}"] options="${ROS_GATEWAY_OPTION_NAME},${ROS_DNS_OPTION_NAME}"
}

/ipv6 nd
set [find where interface="${ROS_LAN_INTERFACE}"] ra-lifetime=none dns=""
