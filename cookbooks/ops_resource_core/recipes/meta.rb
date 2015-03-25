#
# Cookbook Name:: ops_resource_core
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
  action :create
end

file "#{meta_directory}\\meta.json" do
  content IO.read(File.join(File.dirname(__FILE__), '..\\..\\..\\meta.json'))
end
