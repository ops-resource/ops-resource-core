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

describe 'ops_resource_core::consul_as_dns' do
  let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

  it 'adds the localhost as the primary DNS address' do
    expect(chef_run).to run_powershell_script('localhost_as_primary_dns')
  end

  # Note the data values are the MD5 hash of the value '0'. For some reason Chef processes the
  # values before it gets to the test which means chef stores the MD5 hash, not the actual number.
  it 'disables the DNS caching of negative responses' do
    expect(chef_run).to create_registry_key('HKLM\\SYSTEM\\CurrentControlSet\\Services\\Dnscache\\Parameters').with(
      values: [
        {
          name: 'NegativeCacheTime',
          type: :dword,
          data: 'cfcd208495d565ef66e7dff9f98764da'
        },
        {
          name: 'NetFailureCacheTime',
          type: :dword,
          data: 'cfcd208495d565ef66e7dff9f98764da'
        },
        {
          name: 'NegativeSOACacheTime',
          type: :dword,
          data: 'cfcd208495d565ef66e7dff9f98764da'
        },
        {
          name: 'MaxNegativeCacheTtl',
          type: :dword,
          data: 'cfcd208495d565ef66e7dff9f98764da'
        }])
  end
end
