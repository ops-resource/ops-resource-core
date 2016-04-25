# Run as server or as client
default['env_consul']['consul_as_server'] = '${ConsulAsServer}'

# Shared
default['env_consul']['consul_datacenter'] = '${ConsulDataCenterName}'

default['env_consul']['consul_dns_port'] = 53
default['env_consul']['consul_http_port'] = 8530
default['env_consul']['consul_rpc_port'] = 8430
default['env_consul']['consul_serf_lan_port'] = 8331
default['env_consul']['consul_serf_wan_port'] = 8332
default['env_consul']['consul_server_port'] = 8330

default['env_external']['dns_server'] = '${ConsulExternalDnsServers}'

# Client
default['env_consul']['lan_server_node_dns'] = '${ConsulLanServerAddress}'

# Server
default['env_consul']['consul_server_count'] = '${ConsulServerCount}'
default['env_consul']['consul_domain'] = '${ConsulDomain}'

default['env_consul']['wan_server_node_dns'] = '${ConsulWanServerAddress}'
