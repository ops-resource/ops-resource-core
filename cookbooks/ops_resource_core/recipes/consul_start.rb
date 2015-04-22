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

meta_directory = node['paths']['meta']
consul_bin_directory = node['paths']['consul_bin']
consul_config_directory = node['paths']['consul_config']
consul_checks_directory = node['paths']['consul_checks']

consul_config_upload_file = 'Set-ConfigurationInConsulCluster.ps1'

# Finally start the service
service service_name do
  action :start
end

# upon reboot connect to the join node and set the meta data for the current resource to be equal to the data in the configuration files
powershell_script 'upload_metadata_to_consul_cluster' do
  code <<-POWERSHELL
    $ErrorActionPreference = 'Stop'

    $consulServiceName = '#{service_name}'
    $filesToUpload = @{
        '#{meta_directory}\\meta.json' = 'node';
        '#{consul_bin_directory}\\consul_default.json' = 'consul/ops/consul/bin/consul_default.json';
        '#{consul_config_directory}\\check_server.json' = 'consul/meta/consul/check_server.json';
        '#{consul_checks_directory}\\Test-Disk.ps1' = 'consul/meta/consul/checks/test-disk.ps1';
        '#{consul_checks_directory}\\Test-Load.ps1' = 'consul/meta/consul/checks/test-load.ps1';
        '#{consul_checks_directory}\\Test-Memory.ps1' = 'consul/meta/consul/checks/test-memory.ps1';
    }

    #{consul_config_directory}\\#{consul_config_upload_file} -filesToUpload $filesToUpload -consulServiceName $consulServiceName
  POWERSHELL
end
