require 'chefspec'
require 'socket'
require_relative '../libraries/consul_helper'

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

describe 'ops_resource_core_consul::consul' do
  logs_path = 'c:\\logs'
  consul_logs_directory = 'c:\\logs\\consul'

  meta_directory = 'c:\\meta'
  consul_config_directory = 'c:\\meta\\consul'
  consul_checks_directory = 'c:\\meta\\consul\\checks'

  ops_base_path = 'c:\\ops'
  consul_base_path = 'c:\\ops\\consul'
  consul_data_directory = 'c:\\ops\\consul\\data'
  consul_bin_directory = 'c:\\ops\\consul\\bin'

  service_name = 'consul'
  consul_config_file = 'consul_default.json'
  context 'create the log locations' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the logs base directory' do
      expect(chef_run).to create_directory(logs_path)
    end

    it 'creates the consul logs directory' do
      expect(chef_run).to create_directory(consul_logs_directory)
    end
  end

  context 'create the meta locations' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the consul config directory' do
      expect(chef_run).to create_directory(consul_config_directory)
    end

    consul_config_upload_file = 'Set-ConfigurationInConsulCluster.ps1'
    it 'creates Set-ConfigurationInConsulCluster.ps1 in the consul config directory' do
      expect(chef_run).to create_cookbook_file("#{consul_config_directory}\\#{consul_config_upload_file}").with_source(consul_config_upload_file)
    end

    it 'creates the consul checks directory' do
      expect(chef_run).to create_directory(consul_checks_directory)
    end
  end

  context 'create the consul locations' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the ops base directory' do
      expect(chef_run).to create_directory(ops_base_path)
    end

    it 'creates the consul base directory' do
      expect(chef_run).to create_directory(consul_base_path)
    end

    it 'creates the consul data directory' do
      expect(chef_run).to create_directory(consul_data_directory)
    end

    it 'creates the consul bin directory' do
      expect(chef_run).to create_directory(consul_bin_directory)
    end

    it 'creates consul.exe in the consul ops directory' do
      expect(chef_run).to create_cookbook_file("#{consul_bin_directory}\\#{service_name}.exe").with_source("#{service_name}.exe")
    end

    # it 'opens the TCP ports for consul in the firewall' do
    #   expect(chef_run).to create_windows_firewall_rule('Consul_TCP').with(
    #     values: [{
    #       dir: 'in',
    #       firewall_action: :allow,
    #       protocol: 'TCP',
    #       program: "#{consul_bin_directory}\\consul.exe",
    #       profile: 'domain'
    #     }])
    # end

    # it 'opens the UDP ports for consul in the firewall' do
    #   expect(chef_run).to create_windows_firewall_rule('Consul_UDP').with(
    #     values: [{
    #       dir: 'in',
    #       firewall_action: :allow,
    #       protocol: 'UDP',
    #       program: "#{consul_bin_directory}\\consul.exe",
    #       profile: 'domain'
    #     }])
    # end
  end

  context 'create the user to run the service with' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the consul user' do
      expect(chef_run).to create_user('consul_user')
      expect(chef_run).to modify_group('Performance Monitor Users').with(members: ['consul_user'])
    end
  end

  context 'install consul as service' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    win_service_name = 'consul_service'
    it 'creates consul_service.exe in the consul ops directory' do
      expect(chef_run).to create_cookbook_file("#{consul_bin_directory}\\#{win_service_name}.exe").with_source('winsw.exe')
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
    <arguments>agent -config-file=#{consul_bin_directory}\\#{consul_config_file} -config-dir=#{consul_config_directory}</arguments>

    <logpath>#{consul_logs_directory}</logpath>
    <log mode="roll-by-size">
        <sizeThreshold>10240</sizeThreshold>
        <keepFiles>8</keepFiles>
    </log>
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
  end

  context 'install consul as client' do
    let(:chef_run) do
      node.set['env_consul']['consul_as_server'] = false
      node.set['env_consul']['consul_datacenter'] = 'MyDatacenter'
      node.set['env_consul']['consul_dns_port'] = 1
      node.set['env_consul']['consul_http_port'] = 2
      node.set['env_consul']['consul_rpc_port'] = 3
      node.set['env_consul']['consul_serf_lan_port'] = 4
      node.set['env_consul']['consul_serf_wan_port'] = 5
      node.set['env_consul']['consul_server_port'] = 6
      node.set['env_external']['dns_server'] = '4.3.2.1,3.2.1.0'
      node.set['env_consul']['lan_server_node_dns'] = '5.4.3.2,6.5.4.3,7.6.5.4'
      node.set['env_consul']['consul_server_count'] = -1
      node.set['env_consul']['consul_domain'] = 'CONSUL_DOMAIN_NOT_SET'
      node.set['env_consul']['wan_server_node_dns'] = 'WAN_DNS_NOT_SET'
      ChefSpec::SoloRunner.converge(described_recipe)
    end

    consul_default_config_content = <<-JSON
{
  "data_dir": "c:\\\\ops\\\\consul\\\\data",



  "datacenter": "MyDatacenter",


  "ports": {
    "dns": 1
    "http": 2,
    "rpc": 3,
    "serf_lan": 4,
    "serf_wan": 5,
    "server": 6
  },

  "dns_config" : {
    "allow_stale" : true,
    "max_stale" : "150s",
    "node_ttl" : "300s",
    "service_ttl": {
      "*": "300s"
    }
  },

  "retry_join": ["5.4.3.2","6.5.4.3","7.6.5.4"],
  "retry_interval": "30s",

  "recursors": ["4.3.2.1","3.2.1.0"],

  "disable_remote_exec": true,
  "disable_update_check": true,

  "log_level" : "debug"
}
    JSON
    it 'creates consul_default.json in the consul ops directory' do
      expect(chef_run).to create_file("#{consul_bin_directory}\\#{consul_config_file}").with_content(consul_default_config_content)
    end
  end

  context 'install consul as server' do
    let(:chef_run) do
      node.set['env_consul']['consul_as_server'] = true
      node.set['env_consul']['consul_datacenter'] = 'MyDatacenter'
      node.set['env_consul']['consul_dns_port'] = 1
      node.set['env_consul']['consul_http_port'] = 2
      node.set['env_consul']['consul_rpc_port'] = 3
      node.set['env_consul']['consul_serf_lan_port'] = 4
      node.set['env_consul']['consul_serf_wan_port'] = 5
      node.set['env_consul']['consul_server_port'] = 6
      node.set['env_external']['dns_server'] = '4.3.2.1,3.2.1.0'
      node.set['env_consul']['lan_server_node_dns'] = 'LAN_DNS_NOT_SET'
      node.set['env_consul']['consul_server_count'] = 7
      node.set['env_consul']['consul_domain'] = 'MyDomain'
      node.set['env_consul']['wan_server_node_dns'] = '5.4.3.2,6.5.4.3,7.6.5.4'
      ChefSpec::SoloRunner.converge(described_recipe)
    end

    machine_ip = Consul::Helper.local_ip

    consul_default_config_content = <<-JSON
{
  "data_dir": "c:\\\\ops\\\\consul\\\\data",

  "bootstrap_expect" : 7,
  "server": true,
  "domain": "MyDomain",

  "datacenter": "MyDatacenter",

  "addresses": {
    "dns": "#{machine_ip}"
  },
  "ports": {
    "dns": 1
    "http": 2,
    "rpc": 3,
    "serf_lan": 4,
    "serf_wan": 5,
    "server": 6
  },

  "dns_config" : {
    "allow_stale" : true,
    "max_stale" : "150s",
    "node_ttl" : "300s",
    "service_ttl": {
      "*": "300s"
    }
  },


  "retry_join_wan": ["5.4.3.2","6.5.4.3","7.6.5.4"],
  "retry_interval_wan": "30s",
  "recursors": ["4.3.2.1","3.2.1.0"],

  "disable_remote_exec": true,
  "disable_update_check": true,

  "log_level" : "debug"
}
    JSON
    it 'creates consul_default.json in the consul ops directory' do
      expect(chef_run).to create_file("#{consul_bin_directory}\\#{consul_config_file}").with_content(consul_default_config_content)
    end
  end

  context 'store the meta' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    consul_service_config_content = <<-JSON
{
    "install_path": "c:\\\\ops\\\\consul\\\\bin",
    "config_path": "c:\\\\meta\\\\consul",
}
    JSON
    it 'creates the service_consul.json meta file' do
      expect(chef_run).to create_file("#{meta_directory}\\service_consul.json").with_content(consul_service_config_content)
    end
  end
end
