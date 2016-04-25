# Attributes from the meta cookbook
logs_path = node['paths']['log']
ops_base_path = node['paths']['ops_base']

# Attributes for the current cookbook
provisioning_base_path = "#{ops_base_path}\\provisioning"
default['paths']['provisioning_base'] = provisioning_base_path
default['paths']['provisioning_service'] = "#{provisioning_base_path}\\service"

provisioning_logs_path = "#{logs_path}\\provisioning"
default['paths']['provisioning_logs'] = provisioning_logs_path

default['service']['provisioning'] = 'provisioning'
