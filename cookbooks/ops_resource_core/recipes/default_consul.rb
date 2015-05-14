#
# Cookbook Name:: ops_resource_core
# Recipe:: default_consul
#
# Copyright 2015, P. van der Velde
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'ops_resource_core::consul'
include_recipe 'ops_resource_core::consul_config'
include_recipe 'ops_resource_core::consul_health_checks'
include_recipe 'ops_resource_core::consul_as_dns'
include_recipe 'ops_resource_core::consul_start'
