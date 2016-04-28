#
# Cookbook Name:: ops_resource_core_meta
# Recipe:: meta
#
# Copyright 2015, P. van der Velde
#
# All rights reserved - Do Not Redistribute
#

# CONFIGURE OPS DIRECTORY
ops_base_directory = node['paths']['ops_base']
directory ops_base_directory do
  rights :read, 'Everyone', applies_to_children: true
  rights :modify, 'Administrators', applies_to_children: true
  action :create
end


# CONFIGURE LOG DIRECTORY
log_directory = node['paths']['log']
directory log_directory do
  rights :read, 'Everyone', applies_to_children: true
  rights :modify, 'Administrators', applies_to_children: true
  action :create
end


# CONFIGURE META DIRECTORY
meta_directory = node['paths']['meta']
directory meta_directory do
  rights :read, 'Everyone', applies_to_children: true, applies_to_self: false
  rights :modify, 'Administrators', applies_to_children: true
  action :create
end

# Add the meta data file that contains:
# - Cookbooks that were executed
# - Applications that were installed + versions
meta_file = 'meta.json'
cookbook_file "#{meta_directory}\\#{meta_file}" do
  source meta_file
  action :create
end
