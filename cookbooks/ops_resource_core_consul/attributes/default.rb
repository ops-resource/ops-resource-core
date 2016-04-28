# Attributes from the meta cookbook
logs_path = node['paths']['log']
meta_base_path = node['paths']['meta']
ops_base_path = node['paths']['ops_base']

# BIN PATHS
consul_base_path = "#{ops_base_path}\\consul"
default['paths']['consul_base'] = consul_base_path
default['paths']['consul_bin'] = "#{consul_base_path}\\bin"
default['paths']['consul_data'] = "#{consul_base_path}\\data"

default['file_name']['consul_config_file'] = 'consul_default.json'

consultemplate_base_path = "#{ops_base_path}\\consultemplate"
default['paths']['consultemplate_base'] = consultemplate_base_path
default['paths']['consultemplate_bin'] = "#{consultemplate_base_path}\\bin"

default['file_name']['consultemplate_config_file'] = 'consul_default.json'

# LOG PATHS
default['paths']['consul_logs'] = "#{logs_path}\\consul"
default['paths']['consultemplate_logs'] = "#{logs_path}\\consultemplate"

# CONFIG PATHS
consultemplate_config_path = "#{meta_base_path}\\consultemplate"
default['paths']['consultemplate_config'] = consultemplate_config_path

consultemplate_templates_path = "#{consultemplate_config_path}\\templates"
default['paths']['consultemplate_templates'] = consultemplate_templates_path

consul_config_path = "#{meta_base_path}\\consul"
default['paths']['consul_config'] = consul_config_path
default['paths']['consul_checks'] = "#{consul_config_path}\\checks"
default['paths']['consul_template'] = "#{consultemplate_templates_path}\\consul"

# SERVICE NAMES
default['service']['consul'] = 'consul'
default['service']['consultemplate'] = 'consultemplate'
