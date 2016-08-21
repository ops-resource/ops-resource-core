#
# Cookbook Name:: ops_resource_core_consul
# Recipe:: consultemplate
#
# Copyright 2015, P. van der Velde
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'windows'

service_name = node['service']['consultemplate']
win_service_name = 'consultemplate_service'

# Create user
# - limited user
# - Reduce access to files. User should only have write access to consul dir
service_username = node['service']['consultemplate_user_name']
service_password = node['service']['consultemplate_user_password']
user service_username do
  password service_password
  action :create
end

# Grant the user the LogOnAsService permission. Following this anwer on SO: http://stackoverflow.com/a/21235462/539846
# With some additional bug fixes to get the correct line from the export file and to put the correct text in the import file
powershell_script 'consultemplate_user_grant_service_logon_rights' do
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

# CONFIGURE LOG DIRECTORIES
consultemplate_logs_directory = node['paths']['consultemplate_logs']
directory consultemplate_logs_directory do
  rights :modify, service_username, applies_to_children: true, applies_to_self: false
  action :create
end

# CONFIGURE CONSULTEMPLATE DIRECTORIES
consultemplate_base_directory = node['paths']['consultemplate_base']
directory consultemplate_base_directory do
  action :create
end

# CONFIGURE CONSUL CONFIG DIRECTORIES
consultemplate_config_directory = node['paths']['consultemplate_config']
directory consultemplate_config_directory do
  action :create
end

consultemplate_template_directory = node['paths']['consultemplate_templates']
directory consultemplate_template_directory do
  action :create
end

# CONFIGURE CONSULTEMPLATE EXECUTABLE
consultemplate_bin_directory = node['paths']['consultemplate_bin']
directory consultemplate_bin_directory do
  rights :read_execute, 'Everyone', applies_to_children: true, applies_to_self: false
  action :create
end

consultemplate_exe = 'consul-template.exe'
cookbook_file "#{consultemplate_bin_directory}\\#{consultemplate_exe}" do
  source consultemplate_exe
  action :create
end

consul_port = node['env_consul']['consul_http_port']
consul_bin_directory = node['paths']['consul_bin']
consul_config_file = node['file_name']['consul_config_file']
service_name_consul = node['service']['consul']

consul_bin_directory_escaped = consul_bin_directory.gsub('\\', '\\\\\\\\')
consultemplate_template_directory_escaped = consultemplate_template_directory.gsub('\\', '\\\\\\\\')
consultemplate_config_file = 'consultemplate_default.json'
file "#{consultemplate_bin_directory}\\#{consultemplate_config_file}" do
  content <<-JSON
consul = "127.0.0.1:#{consul_port}"

retry = "10s"
max_stale = "150s"
wait = "5s:10s"

log_level = "warn"

template {
    source = "#{consultemplate_template_directory_escaped}\\\\consul\\\\#{consul_config_file}.ctmpl"
    destination = "#{consul_bin_directory_escaped}\\\\#{consul_config_file}"

    command = "net stop service #{service_name_consul};net start service #{service_name_consul}"
    command_timeout = "60s"

    backup = false
}
  JSON
end

# INSTALL CONSULTEMPLATE AS SERVICE
cookbook_file "#{consultemplate_bin_directory}\\#{win_service_name}.exe" do
  source 'winsw.exe'
  action :create
end

file "#{consultemplate_bin_directory}\\#{win_service_name}.exe.config" do
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

file "#{consultemplate_bin_directory}\\#{win_service_name}.xml" do
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
    <description>This service runs the consul-template agent.</description>

    <executable>#{consultemplate_bin_directory}\\consul-template.exe</executable>
    <arguments>-config #{consultemplate_bin_directory}\\#{consultemplate_config_file}</arguments>

    <logpath>#{consultemplate_logs_directory}</logpath>
    <log mode="roll-by-size">
        <sizeThreshold>10240</sizeThreshold>
        <keepFiles>8</keepFiles>
    </log>
    <onfailure action="restart"/>
</service>
    XML
  action :create
end

powershell_script 'consultemplate_as_service' do
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
            -BinaryPathName '#{consultemplate_bin_directory}\\#{win_service_name}.exe' `
            -Credential $credential `
            -DisplayName '#{service_name}' `
            -StartupType Disabled `
            -DependsOn '#{service_name_consul}'
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

# STORE META INFORMATION
meta_directory = node['paths']['meta']
consultemplate_bin_directory_escaped = consultemplate_bin_directory.gsub('\\', '\\\\\\\\')
consultemplate_config_file_escaped = "#{consultemplate_bin_directory}\\#{consultemplate_config_file}".gsub('\\', '\\\\\\\\')

win_service_config_file_escaped = "#{consultemplate_bin_directory}\\#{win_service_name}.xml".gsub('\\', '\\\\\\\\')
file "#{meta_directory}\\service_consultemplate.json" do
  content <<-JSON
{
    "service" : {
        "application" : "#{consultemplate_exe}",
        "application_config" : "#{consultemplate_config_file_escaped}",

        "win_service" : "#{service_name}",
        "win_service_config" : "#{win_service_config_file_escaped}",

        "install_path": "#{consultemplate_bin_directory_escaped}",
        "template_path": "#{consultemplate_template_directory_escaped}"
    }
}
  JSON
  action :create
end
