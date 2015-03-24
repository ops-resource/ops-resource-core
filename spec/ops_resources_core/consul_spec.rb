require File.join(File.dirname(__FILE__), '..', 'spec_helper')
require 'json'
require 'ruby-wmi'
require 'rest-client'

describe file('c:/ops') do
  it { should be_directory }
end

describe file('c:/ops/consul') do
  it { should be_directory }
end

describe file('c:/ops/consul/bin') do
  it { should be_directory }
end

describe file('c:/ops/consul/data') do
  it { should be_directory }
end

describe file('c:/ops/consul/checks') do
  it { should be_directory }
end

describe file('c:/ops/consul/bin/consul_service.exe') do
  it { should be_file }
end

describe file('c:/ops/consul/bin/consul_service.exe.config') do
  it { should be_file }
end

describe file('c:/ops/consul/bin/consul_service.xml') do
  it { should be_file }
end

describe file('c:/ops/consul/bin/consul.exe') do
  it { should be_file }
end

describe service('Consul') do
  it { should be_installed }
  it { should be_enabled }
  it { should have_start_mode('automatic')  }
  it { should be_running }
end

# Verify that the service is running as the consul_user user
describe 'consul service' do
  wmi_service = WMI::Win32_Service.find('consul')
  it 'runs as consul_user user' do
    expect(wmi_service.startname).to eq('.\\consul_user')
  end
end

describe port(8500) do
  it { should be_listening.with('tcp') }
end

# Query the version of consul that is running
describe 'consul webservice' do
  begin
    response = RestClient.get 'http://localhost:8500/v1/agent/self'
    obj = JSON.parse(response.to_str)
    it 'is active an returns the correct version' do
      expect(obj['Config']['Version']).to eq('0.5.0')
    end
  rescue
    it 'fails' do
      # this always fails because there was an exception of some kind
      expect(false).to be true
    end
  end
end
