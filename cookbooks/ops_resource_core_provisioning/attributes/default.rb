logs_path = 'c:\\logs'
default['paths']['log'] = logs_path

meta_base_path = 'c:\\meta'
default['paths']['meta'] = meta_base_path

ops_base_path = 'c:\\ops'
default['paths']['ops_base'] = ops_base_path

provisioning_base_path = '#{ops_base_path}\\provisioning'
default['paths']['provisioning_base'] = provisioning_base_path
default['paths']['provisioning_service'] = "#{provisioning_base_path}\\service"

provisioning_logs_path = "#{logs_path}\\provisioning"
default['paths']['provisioning_logs'] = provisioning_logs_path

default['service']['provisioning'] = 'provisioning'
