#
# Cookbook Name:: ops_resource_core_meta
# Recipe:: meta
#
# Copyright 2015, P. van der Velde
#
# All rights reserved - Do Not Redistribute
#

# Add the meta data file that contains:
# - Cookbooks that were executed
# - Applications that were installed + versions
meta_directory = node['paths']['meta']
directory meta_directory do
  rights :read, 'Everyone', applies_to_children: true, applies_to_self: false
  rights :modify, 'Administrators', applies_to_children: true
  action :create
end

meta_file = 'meta.json'
cookbook_file "#{meta_directory}\\#{meta_file}" do
  source meta_file
  action :create
end
