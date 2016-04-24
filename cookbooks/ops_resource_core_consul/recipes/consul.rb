#
# Cookbook Name:: ops_resource_core_consul
# Recipe:: consul
#
# Copyright 2015, P. van der Velde
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'windows'
include_recipe 'windows_firewall'

log_directory = node['paths']['log']
directory log_directory do
  rights :read, 'Everyone', applies_to_children: true
  rights :modify, 'Administrators', applies_to_children: true
  action :create
end

service_name = node['service']['consul']
win_service_name = 'consul_service'

# Create user
# - limited user
# - Reduce access to files. User should only have write access to consul dir
service_username = 'consul_user'
service_password = SecureRandom.uuid
user service_username do
  password service_password
  action :create
end

group 'Performance Monitor Users' do
  action :modify
  members service_username
  append true
end

# Grant the user the LogOnAsService permission. Following this anwer on SO: http://stackoverflow.com/a/21235462/539846
# With some additional bug fixes to get the correct line from the export file and to put the correct text in the import file
powershell_script 'user_grant_service_logon_rights' do
  code <<-POWERSHELL
    $ErrorActionPreference = 'Stop'

    $userName = "#{service_username}"

    $tempPath = "c:\\temp"
    if (-not (Test-Path $tempPath))
    {
        New-Item -Path $tempPath -ItemType Directory | Out-Null
    }

    $import = Join-Path -Path $tempPath -ChildPath "import.inf"
    if(Test-Path $import)
    {
        Remove-Item -Path $import -Force
    }

    $export = Join-Path -Path $tempPath -ChildPath "export.inf"
    if(Test-Path $export)
    {
        Remove-Item -Path $export -Force
    }

    $secedt = Join-Path -Path $tempPath -ChildPath "secedt.sdb"
    if(Test-Path $secedt)
    {
        Remove-Item -Path $secedt -Force
    }

    $sid = ((New-Object System.Security.Principal.NTAccount($userName)).Translate([System.Security.Principal.SecurityIdentifier])).Value

    secedit /export /cfg $export
    $line = (Select-String $export -Pattern "SeServiceLogonRight").Line
    $sids = $line.Substring($line.IndexOf('=') + 1).Trim()

    if (-not ($sids.Contains($sid)))
    {
        Write-Host ("Granting SeServiceLogonRight to user account: {0} on host: {1}." -f $userName, $computerName)
        $lines = @(
                "[Unicode]",
                "Unicode=yes",
                "[System Access]",
                "[Event Audit]",
                "[Registry Values]",
                "[Version]",
                "signature=`"`$CHICAGO$`"",
                "Revision=1",
                "[Profile Description]",
                "Description=GrantLogOnAsAService security template",
                "[Privilege Rights]",
                "SeServiceLogonRight = $sids,*$sid"
            )
        foreach ($line in $lines)
        {
            Add-Content $import $line
        }

        secedit /import /db $secedt /cfg $import
        secedit /configure /db $secedt
        gpupdate /force
    }
    else
    {
        Write-Host ("User account: {0} on host: {1} already has SeServiceLogonRight." -f $userName, $computerName)
    }
  POWERSHELL
end

ops_base_directory = node['paths']['ops_base']
directory ops_base_directory do
  rights :read, 'Everyone', applies_to_children: true
  rights :modify, 'Administrators', applies_to_children: true
  action :create
end

consul_base_directory = node['paths']['consul_base']
directory consul_base_directory do
  action :create
end

consul_data_directory = node['paths']['consul_data']
directory consul_data_directory do
  rights :modify, service_username, applies_to_children: true, applies_to_self: false
  action :create
end

consul_logs_directory = node['paths']['consul_logs']
directory consul_logs_directory do
  rights :modify, service_username, applies_to_children: true, applies_to_self: false
  action :create
end

consul_config_directory = node['paths']['consul_config']
directory consul_config_directory do
  action :create
end

consul_config_upload_file = 'Set-ConfigurationInConsulCluster.ps1'
cookbook_file "#{consul_config_directory}\\#{consul_config_upload_file}" do
  source consul_config_upload_file
  action :create
end

consul_checks_directory = node['paths']['consul_checks']
directory consul_checks_directory do
  action :create
end

consul_bin_directory = node['paths']['consul_bin']
directory consul_bin_directory do
  rights :read_execute, 'Everyone', applies_to_children: true, applies_to_self: false
  action :create
end

consul_exe = 'consul.exe'
cookbook_file "#{consul_bin_directory}\\#{consul_exe}" do
  source consul_exe
  action :create
end

# Getting a comma separed set of IP addresses that are the IP addresses of the DNS recusors
# For the consul configuration we want a formatted string that looks like:
# "recursor_IP_1","recursor_IP_2","recursor_IP_3"
recusors_formatted = node['env_external']['dns_server'].gsub(',', '\",\"')
consul_config_recursors = "\"#{recursors_formatted}\""

consul_config_datacenter = node['consul']['datacenter']
consul_config_entry_node_dns = node['consul']['entry_node_dns']
consul_config_recursors = node['consul']['dns_server_url']

consul_config_file = 'consul_default.json'
# We need to multiple-escape the escape character because of ruby string and regex etc. etc. See here: http://stackoverflow.com/a/6209532/539846
consul_data_directory_json_escaped = consul_data_directory.gsub('\\', '\\\\\\\\')
file "#{consul_bin_directory}\\#{consul_config_file}" do
  content <<-JSON
{
  "data_dir": "#{consul_data_directory_json_escaped}",

  "datacenter": "#{consul_config_datacenter}",

  "ports": {
    "dns": 53
  },

  "dns_config" : {
    "allow_stale" : true,
    "max_stale" : "150s",
    "node_ttl" : "300s",
    "service_ttl": {
      "*": "300s"
    }
  },

  "retry_join": ["#{consul_config_entry_node_dns}"],
  "retry_interval": "30s",

  "recursors": [#{consul_config_recursors}],

  "disable_remote_exec": true,
  "disable_update_check": true,

  "log_level" : "debug"
}
  JSON
end

# add the winsw binaries
# Copy the service runner & rename to consul.exe
cookbook_file "#{consul_bin_directory}\\#{win_service_name}.exe" do
  source 'winsw.exe'
  action :create
end

file "#{consul_bin_directory}\\#{win_service_name}.exe.config" do
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

file "#{consul_bin_directory}\\#{win_service_name}.xml" do
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
    <description>This service runs the consul agent.</description>

    <executable>#{consul_bin_directory}\\consul.exe</executable>
    <arguments>agent -config-file=#{consul_bin_directory}\\#{consul_config_file} -config-dir=#{consul_config_directory}</arguments>

    <logpath>#{consul_logs_directory}</logpath>
    <log mode="roll-by-size">
        <sizeThreshold>10240</sizeThreshold>
        <keepFiles>8</keepFiles>
    </log>
    <onfailure action="restart"/>
</service>
    XML
  action :create
end

# Install consul_service.exe as service
powershell_script 'consul_as_service' do
  code <<-POWERSHELL
    $ErrorActionPreference = 'Stop'

    $securePassword = ConvertTo-SecureString "#{service_password}" -AsPlainText -Force

    # Note the .\\ is to get the local machine account as per here:
    # http://stackoverflow.com/questions/313622/powershell-script-to-change-service-account#comment14535084_315616
    $credential = New-Object pscredential((".\\" + "#{service_username}"), $securePassword)

    $service = Get-Service -Name '#{service_name}' -ErrorAction SilentlyContinue
    if ($service -eq $null)
    {
        New-Service `
            -Name '#{service_name}' `
            -BinaryPathName '#{consul_bin_directory}\\#{win_service_name}.exe' `
            -Credential $credential `
            -DisplayName '#{service_name}' `
            -StartupType Disabled
    }

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

# Add file to meta directory containing information about consul install
meta_directory = node['paths']['meta']
consul_bin_directory_escaped = consul_bin_directory.gsub('\\', '\\\\\\\\')
consul_config_directory_escaped = consul_config_directory.gsub('\\', '\\\\\\\\')
file "#{meta_directory}\\service_consul.json" do
  content <<-JSON
{
    "install_path": "#{consul_bin_directory_escaped}",
    "config_path": "#{consul_config_directory_escaped}",
}
  JSON
  action :create
end

windows_firewall_rule 'Consul_TCP' do
    dir 'in'
    firewall_action :allow
    protocol 'TCP'
    program "#{consul_bin_directory}\\consul.exe"
    profile 'domain'
    action :create
end

windows_firewall_rule 'Consul_UDP' do
    dir 'in'
    firewall_action :allow
    protocol 'UDP'
    program "#{consul_bin_directory}\\consul.exe"
    profile 'domain'
    action :create
end
