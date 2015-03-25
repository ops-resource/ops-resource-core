#
# Cookbook Name:: ops_resouce_core
# Recipe:: default
#
# Copyright 2015, P. van der Velde
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'ops_resouce_core::consul'
include_recipe 'ops_resouce_core::consul_config'
include_recipe 'ops_resouce_core::consul_health_checks'
include_recipe 'ops_resouce_core::meta'
