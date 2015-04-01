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

describe 'ops_resource_core'  do
  let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

  meta_path = 'c:\\meta'
  it 'creates the meta directory' do
    expect(chef_run).to create_directory(meta_path)
  end

  meta_file = 'meta.json'
  it 'creates the meta file' do
    expect(chef_run).to create_cookbook_file("#{meta_path}\\#{meta_file}").with(source: meta_file)
  end
end
