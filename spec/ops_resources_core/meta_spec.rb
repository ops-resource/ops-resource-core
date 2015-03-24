require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe file('c:/meta') do
  it { should be_directory }
end

describe file('c:/meta/meta.json') do
  it { should be_file }
end
