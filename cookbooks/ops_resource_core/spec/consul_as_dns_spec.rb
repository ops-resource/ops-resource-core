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

describe 'ops_resource_core::consul_as_dns'  do
  let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

  it 'adds the localhost as the primary DNS address' do
    expect(chef_run).to run_powershell_script('localhost_as_primary_dns')
  end

  it 'disables the DNS caching of negative responses' do
    expect(chef_run).to create_registry_key('HKLM\\SYSTEM\\CurrentControlSet\\Services\\Dnscache\\Parameters').with(
      values: [
        {
          name: 'NegativeCacheTime',
          type: :dword,
          data: 0x0
        },
        {
          name: 'NetFailureCacheTime',
          type: :dword,
          data: 0x0
        },
        {
          name: 'NegativeSOACacheTime',
          type: :dword,
          data: 0x0
        }])
  end
end
