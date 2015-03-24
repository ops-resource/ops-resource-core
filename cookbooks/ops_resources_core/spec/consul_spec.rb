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

describe 'ops_resources_core'  do
  let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

  it 'creates the consul user' do
    expect(chef_run).to create_user('consul_user')
  end

  consul_base_path = 'c:\\ops\\consul'
  consul_data_directory = '#{consul_base_path}\\data'
  it 'creates the consul data directory' do
    expect(chef_run).to create_directory(consul_data_directory)
  end

  consul_checks_directory = '#{consul_base_path}\\checks'
  it 'creates the consul checks directory' do
    expect(chef_run).to create_directory(consul_checks_directory)
  end

  consul_bin_directory = "#{consul_base_path}\\bin"
  it 'creates the consul bin directory' do
    expect(chef_run).to create_directory(consul_bin_directory)
  end

  configuration_directory = 'c:/configuration'
  service_name = 'consul'
  it 'creates consul.exe in the consul ops directory' do
    expect(chef_run).to create_remote_file("#{consul_bin_directory}\\#{service_name}.exe").with_source("file:///#{configuration_directory}/consul.exe")
  end

  win_service_name = 'consul_service'
  it 'creates consul_service.exe in the consul ops directory' do
    expect(chef_run).to create_remote_file("#{consul_bin_directory}\\#{win_service_name}.exe").with_source("file:///#{configuration_directory}/winsw-1.16-bin.exe")
  end

  consul_service_exe_config_content = <<-XML
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
  it 'creates consul_service.exe.config in the consul ops directory' do
    expect(chef_run).to create_file("#{consul_bin_directory}\\#{win_service_name}.exe.config").with_content(consul_service_exe_config_content)
  end

  consul_config_directory = 'c:\\meta\\consul'
  ip_consul_entry_node = '${ConsulEntryPointIp}'
  consul_service_xml_content = <<-XML
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
    <arguments>agent -data-dir #{consul_data_directory} -config-dir #{consul_config_directory} -retry-join=#{ip_consul_entry_node} -retry-interval=30s</arguments>

    <!-- interactive flag causes the empty black Java window to be displayed. I'm still debugging this. <interactive /> -->
    <logmode>rotate</logmode>
    <onfailure action="restart"/>
</service>
  XML
  it 'creates consul_service.xml in the consul ops directory' do
    expect(chef_run).to create_file("#{consul_bin_directory}\\#{win_service_name}.xml").with_content(consul_service_xml_content)
  end

  it 'installs consul as service' do
    expect(chef_run).to run_powershell_script('consul_as_service')
  end

  it 'creates the windows service event log' do
    expect(chef_run).to create_registry_key("HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\services\\eventlog\\Application\\#{service_name}").with(
      values: [{
        name: 'EventMessageFile',
        type: :string,
        data: 'c:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319\\EventLogMessages.dll'
      }])
  end

  meta_directory = 'c:\\meta'
  it 'creates the meta directory' do
    expect(chef_run).to create_directory(meta_directory)
  end

  consul_service_config_content = <<-JSON
{
    "install_path": "#{consul_bin_directory}",
    "config_path": "#{consul_config_directory}",
}
  JSON
  it 'creates the service_consul.json meta file' do
    expect(chef_run).to create_file("#{meta_directory}\\service_consul.json").with_content(consul_service_config_content)
  end

  set_consul_metadata = 'Set-ConsulMetadata.ps1'
  it 'copies the Set-ConsulMetadata.ps1 file' do
    expect(chef_run).to create_cookbook_file("c:\\ops\\consul\\#{set_consul_metadata}").with(source: set_consul_metadata)
  end

  it 'creates the runonce registry value' do
    expect(chef_run).to create_registry_key('HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows\\CurrentVersion\\RunOnce').with(
      values: [{
        name: 'SetResourceMetadataInConsul',
        type: :string,
        data: "powershell.exe -NoProfile -NonInteractive -NoLogo -File #{consul_base_path}\\#{set_consul_metadata} -metaFile #{meta_directory}\\meta.json -consulServiceName #{service_name}"
      }])
  end
end
