#
# Cookbook Name:: ops_resource_core_provisioning
# Recipe:: provisioning
#
# Copyright 2015, P. van der Velde
#
# All rights reserved - Do Not Redistribute
#

log_directory = node['paths']['log']
directory log_directory do
  rights :read, 'Everyone', applies_to_children: true
  rights :modify, 'Administrators', applies_to_children: true
  action :create
end

provisioning_logs_directory = node['paths']['provisioning_logs']
directory consul_logs_directory do
  rights :modify, consul_username, applies_to_children: true, applies_to_self: false
  action :create
end

# CREATE USER
service_username = 'provisioning_user'
service_password = SecureRandom.uuid
user service_username do
  password service_password
  action :create
end

# CREATE BASE DIRECTORIES
ops_base_directory = node['paths']['ops_base']
directory ops_base_directory do
  rights :read, 'Everyone', applies_to_children: true
  rights :modify, 'Administrators', applies_to_children: true
  action :create
end

provisioning_base_directory = node['paths']['provisioning_base']
directory provisioning_base_directory do
  rights :read, 'Everyone', applies_to_children: true
  rights :modify, 'Administrators', applies_to_children: true
  action :create
end

# STORE PROVISIONING SCRIPT
provisioning_service_directory = node['paths']['provisioning_service']
directory provisioning_service_directory do
  action :create
end

provisioning_script = 'Initialize-Resource.ps1'
cookbook_file "#{provisioning_service_directory}\\#{provisioning_script}" do
  source provisioning_script
  action :create
end

# CONFIGURE SERVICE
service_name = node['service']['provisioning']
win_service_name = 'provisioning_service'

cookbook_file "#{provisioning_service_directory}\\#{win_service_name}.exe" do
  source 'winsw.exe'
  action :create
end

file "#{provisioning_service_directory}\\#{win_service_name}.exe.config" do
  content <<-XML
<configuration>
    <runtime>
        <generatePublisherEvidence enabled="false"/>
    </runtime>
    <startup>
        <supportedRuntime version="v4.0" />
        <supportedRuntime version="v2.0.50727" />
    </startup>
</configuration>
  XML
  action :create
end

file "#{provisioning_service_directory}\\#{win_service_name}.xml" do
  content <<-XML
<?xml version="1.0"?>
<!--
    The MIT License Copyright (c) 2004-2009, Sun Microsystems, Inc., Kohsuke Kawaguchi Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
    subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
    PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
    OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
-->

<service>
    <id>#{service_name}</id>
    <name>#{service_name}</name>
    <description>This service executes the environment provisioning for the current resource.</description>

    <executable>powershell.exe</executable>
    <arguments>-NonInteractive -NoProfile -NoLogo -ExecutionPolicy RemoteSigned -File #{provisioning_service_directory}\\#{provisioning_script}</arguments>

    <logpath>#{provisioning_logs_directory}</logpath>
    <log mode="roll-by-size">
        <sizeThreshold>10240</sizeThreshold>
        <keepFiles>8</keepFiles>
    </log>
    <onfailure action="restart"/>
</service>
    XML
  action :create
end

powershell_script 'provisioning_as_service' do
  code <<-POWERSHELL
    $ErrorActionPreference = 'Stop'

    $securePassword = ConvertTo-SecureString "#{service_password}" -AsPlainText -Force

    # Note the .\\ is to get the local machine account as per here:
    # http://stackoverflow.com/questions/313622/powershell-script-to-change-service-account#comment14535084_315616
    $credential = New-Object pscredential((".\\" + "#{service_username}"), $securePassword)

    # Create the new service
    New-Service `
        -Name '#{service_name}' `
        -BinaryPathName '#{provisioning_service_directory}\\#{win_service_name}.exe' `
        -Credential $credential `
        -DisplayName '#{service_name}' `
        -StartupType Automatic

    # Set the service to restart if it fails
    sc.exe failure #{service_name} reset=86400 actions=restart/5000
  POWERSHELL
end

# Create the event log source for the jenkins service. We'll create it now because the service runs as a normal user
# and is as such not allowed to create eventlog sources
registry_key "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\services\\eventlog\\Application\\#{service_name}" do
  values [{
    name: 'EventMessageFile',
    type: :string,
    data: 'c:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319\\EventLogMessages.dll'
  }]
  action :create
end

# STORE CONFIGURATION INFORMATION
meta_directory = node['paths']['meta']
bin_directory_escaped = provisioning_base_directory.gsub('\\', '\\\\\\\\')
file "#{meta_directory}\\service_provisioning.json" do
  content <<-JSON
{
    "install_path": "#{bin_directory_escaped}",
}
  JSON
  action :create
end

# push up information to provisioning server
