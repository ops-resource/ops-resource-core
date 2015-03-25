#
# Cookbook Name:: ops_resouce_core
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
