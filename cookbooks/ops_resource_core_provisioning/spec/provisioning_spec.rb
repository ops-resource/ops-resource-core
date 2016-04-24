require 'chefspec'

RSpec.configure do |config|
  # Specify the path for Chef Solo to find cookbooks (default: [inferred from
  # the location of the calling spec file])
  # config.cookbook_path = File.join(File.dirname(__FILE__), '..', '..')

  # Specify the path for Chef Solo to find roles (default: [ascending search])
  # config.role_path = '/var/roles'

  # Specify the path for Chef Solo to find environments (default: [ascending search])
  # config.environment_path = '/var/environments'

  # Specify the Chef log_level (default: :warn)
  config.log_level = :debug

  # Specify the path to a local JSON file with Ohai data (default: nil)
  # config.path = 'ohai.json'

  # Specify the operating platform to mock Ohai data from (default: nil)
  config.platform = 'windows'

  # Specify the operating version to mock Ohai data from (default: nil)
  config.version = '2012'
end

describe 'ops_resource_core_provisioning::provisioning' do
  let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

  logs_path = 'c:\\logs'
  it 'creates the logs base directory' do
    expect(chef_run).to create_directory(logs_path)
  end

  ops_base_path = 'c:\\ops'
  it 'creates the ops base directory' do
    expect(chef_run).to create_directory(ops_base_path)
  end

  provisioning_base_path = 'c:\\ops\\provisioning'
  it 'creates the provisioning base directory' do
    expect(chef_run).to create_directory(provisioning_base_path)
  end

  provisioning_service_directory = 'c:\\ops\\provisioning\\service'
  it 'creates the provisioning service directory' do
    expect(chef_run).to create_directory(provisioning_service_directory)
  end

  provisioning_logs_directory = 'c:\\logs\\provisioning'
  it 'creates the provisioning logs directory' do
    expect(chef_run).to create_directory(provisioning_logs_directory)
  end

  provisioning_initialize_file = 'Initialize-Resource.ps1'
  it 'creates Initialize-Resource.ps1 in the provisioning directory' do
    expect(chef_run).to create_cookbook_file("#{provisioning_service_directory}\\#{provisioning_initialize_file}").with_source(consul_config_upload_file)
  end

  win_service_name = 'provisioning_service'
  it 'creates provisioning_service.exe in the provisioning ops directory' do
    expect(chef_run).to create_cookbook_file("#{provisioning_service_directory}\\#{win_service_name}.exe").with_source('winsw.exe')
  end

  service_exe_config_content = <<-XML
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
  it 'creates provisioning_service.exe.config in the provisioning ops directory' do
    expect(chef_run).to create_file("#{provisioning_service_directory}\\#{win_service_name}.exe.config").with_content(consul_service_exe_config_content)
  end

  service_xml_content = <<-XML
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
    <arguments>-NonInteractive -NoProfile -NoLogo -ExecutionPolicy RemoteSigned -File #{provisioning_service_directory}\\#{provisioning_initialize_file}</arguments>

    <logpath>#{provisioning_logs_directory}</logpath>
    <log mode="roll-by-size">
        <sizeThreshold>10240</sizeThreshold>
        <keepFiles>8</keepFiles>
    </log>
    <onfailure action="restart"/>
</service>
  XML
  it 'creates provisioning_service.xml in the provisioning ops directory' do
    expect(chef_run).to create_file("#{provisioning_service_directory}\\#{win_service_name}.xml").with_content(consul_service_xml_content)
  end

  it 'installs as service' do
    expect(chef_run).to run_powershell_script('provisioning_as_service')
  end

  it 'creates the windows service event log' do
    expect(chef_run).to create_registry_key("HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\services\\eventlog\\Application\\#{service_name}").with(
      values: [{
        name: 'EventMessageFile',
        type: :string,
        data: 'c:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319\\EventLogMessages.dll'
      }])
  end

  provisioning_service_config_content = <<-JSON
{
    "install_path": "c:\\\\ops\\\\provisioning",
}
  JSON
  it 'creates the service_provisioning.json meta file' do
    expect(chef_run).to create_file("#{meta_directory}\\service_provisioning.json").with_content(consul_service_config_content)
  end
end
