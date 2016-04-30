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

describe 'ops_resource_core_consul::consultemplate' do
  consultemplate_logs_directory = 'c:\\logs\\consultemplate'

  meta_directory = 'c:\\meta'
  consultemplate_config_directory = 'c:\\meta\\consultemplate'
  consultemplate_template_directory = 'c:\\meta\\consultemplate\\templates'

  consultemplate_base_path = 'c:\\ops\\consultemplate'
  consultemplate_bin_directory = 'c:\\ops\\consultemplate\\bin'

  service_name = 'consultemplate'
  consultemplate_config_file = 'consultemplate_default.json'
  context 'create the log locations' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the consultemplate logs directory' do
      expect(chef_run).to create_directory(consultemplate_logs_directory)
    end
  end

  context 'create the config locations' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the consultemplate config directory' do
      expect(chef_run).to create_directory(consultemplate_config_directory)
    end

    it 'creates the consultemplate template directory' do
      expect(chef_run).to create_directory(consultemplate_template_directory)
    end
  end

  context 'create the consultemplate locations' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the consultemplate base directory' do
      expect(chef_run).to create_directory(consultemplate_base_path)
    end

    it 'creates the consultemplate bin directory' do
      expect(chef_run).to create_directory(consultemplate_bin_directory)
    end

    it 'creates consul-template.exe in the consultemplate ops directory' do
      expect(chef_run).to create_cookbook_file("#{consultemplate_bin_directory}\\consul-template.exe").with_source('consul-template.exe')
    end
  end

  context 'create the user to run the service with' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the consultemplate user' do
      expect(chef_run).to create_user('consultemplate_user')
    end
  end

  context 'install consul as service' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new do |node|
        node.set['env_consul']['consul_http_port'] = 2
        node.set['env_consul']['consul_bin'] = 'c:\\ops\\consul\\bin'
        node.set['file_name']['consul_config_file'] = 'consul_default.json'
        node.set['service']['consul'] = 'consul'
      end.converge(described_recipe)
    end

    win_service_name = 'consultemplate_service'
    it 'creates consultemplate_service.exe in the consultemplate ops directory' do
      expect(chef_run).to create_cookbook_file("#{consultemplate_bin_directory}\\#{win_service_name}.exe").with_source('winsw.exe')
    end

    consultemplate_service_exe_config_content = <<-XML
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
    it 'creates consultemplate_service.exe.config in the consul ops directory' do
      expect(chef_run).to create_file("#{consultemplate_bin_directory}\\#{win_service_name}.exe.config").with_content(consultemplate_service_exe_config_content)
    end

    consultemplate_service_xml_content = <<-XML
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
    it 'creates consultemplate_service.xml in the consul ops directory' do
      expect(chef_run).to create_file("#{consultemplate_bin_directory}\\#{win_service_name}.xml").with_content(consultemplate_service_xml_content)
    end

    it 'installs consul-template as service' do
      expect(chef_run).to run_powershell_script('consultemplate_as_service')
    end

    it 'creates the windows service event log' do
      expect(chef_run).to create_registry_key("HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\services\\eventlog\\Application\\#{service_name}").with(
        values: [{
          name: 'EventMessageFile',
          type: :string,
          data: 'c:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319\\EventLogMessages.dll'
        }])
    end

    consultemplate_default_config_content = <<-JSON
{
    consul = "127.0.0.1:2,

    retry = "10s",
    max_stale = "150s",
    wait = "5s:10s",

    log_level = "warn",

    template {
        source = "c:\\meta\\consultemplate\\templates\\consul\\consul_default.json.ctmpl",
        destination = "c:\\ops\\consul\\bin\\consul_default.json",

        command = "net stop service consul;net start service consul",
        command_timeout = "60s",

        backup = false,

        wait = "2s:6s"
    }
}
    JSON
    it 'creates consultemplate_default.json in the consul-template ops directory' do
      expect(chef_run).to create_file("#{consultemplate_bin_directory}\\#{consultemplate_config_file}").with_content(consultemplate_default_config_content)
    end
  end

  context 'store the meta' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    consultemplate_service_config_content = <<-JSON
{
    "service" : {
        "application" : "consul-template.exe",
        "application_config" : "c:\\\\ops\\\\consultemplate\\\\bin\\\\consultemplate_default.json",

        "win_service" : "consultemplate",
        "win_service_config" : "c:\\\\ops\\\\consultemplate\\\\bin\\\\consultemplate_service.xml",

        "install_path": "c:\\\\ops\\\\consultemplate\\\\bin",
        "template_path": "c:\\\\meta\\\\consultemplate\\\\templates"
    }
}
    JSON
    it 'creates the service_consul.json meta file' do
      expect(chef_run).to create_file("#{meta_directory}\\service_consultemplate.json").with_content(consultemplate_service_config_content)
    end
  end
end
