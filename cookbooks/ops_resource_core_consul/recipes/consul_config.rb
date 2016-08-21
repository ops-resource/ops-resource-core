#
# Cookbook Name:: ops_resource_core_consul
# Recipe:: consul_config
#
# Copyright 2015, P. van der Velde
#
# All rights reserved - Do Not Redistribute
#

consul_config_directory = node['paths']['consul_config']
directory consul_config_directory do
  rights :read_execute, 'Everyone', applies_to_children: true, applies_to_self: false
  rights :modify, 'Administrators', applies_to_children: true
  action :create
end

# STORE PROVISIONING SCRIPT
provisioning_directory = node['paths']['provisioning_base']
directory provisioning_directory do
  action :create
end

provisioning_script = 'Initialize-ConsulResource.ps1'
cookbook_file "#{provisioning_directory}\\#{provisioning_script}" do
  source provisioning_script
  action :create
end
