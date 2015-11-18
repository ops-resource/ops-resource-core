#
# Cookbook Name:: ops_resource_core
# Recipe:: consul_start
#
# Copyright 2015, P. van der Velde
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'windows'

service_name = node['service']['consul']

# Finally start the service
service service_name do
  action :start
end
