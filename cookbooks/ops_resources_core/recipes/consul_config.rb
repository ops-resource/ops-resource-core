#
# Cookbook Name:: ops_resources_core
# Recipe:: consul_config
#
# Copyright 2015, P. van der Velde
#
# All rights reserved - Do Not Redistribute
#

consul_config_directory = node['paths']['consul_config']
directory consul_config_directory do
  action :create
end
