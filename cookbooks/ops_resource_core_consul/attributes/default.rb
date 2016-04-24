# Attributes from the meta cookbook
logs_path = node['paths']['log']
meta_base_path = node['paths']['meta']
ops_base_path = node['paths']['ops_base']

# Attributes for the current cookbook
consul_base_path = "#{ops_base_path}\\consul"
default['paths']['consul_base'] = consul_base_path
default['paths']['consul_bin'] = "#{consul_base_path}\\bin"
default['paths']['consul_data'] = "#{consul_base_path}\\data"

consul_logs_path = "#{logs_path}\\consul"
default['paths']['consul_logs'] = consul_logs_path

consul_config_path = "#{meta_base_path}\\consul"
default['paths']['consul_config'] = consul_config_path
default['paths']['consul_checks'] = "#{consul_config_path}\\checks"

default['service']['consul'] = 'consul'
