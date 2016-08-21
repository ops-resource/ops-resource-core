#
# Cookbook Name:: ops_resource_core_consul
# Recipe:: consul_as_dns
#
# Copyright 2015, P. van der Velde
#
# All rights reserved - Do Not Redistribute
#

# set the IP address of the DNS server to the be local host address (i.e. pointing to the consul agent)
powershell_script 'localhost_as_primary_dns' do
  code <<-POWERSHELL
    # Get all the physical network adapters that provide IPv4 services, are enabled and are the preferred network interface (because that's what consul will be
    # transmitting on).
    $adapter = Get-NetAdapter -Physical | Where-Object { Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -AddressState Preferred -ErrorAction SilentlyContinue }

    # Get the IP addresses for the current DNS servers
    $currentDnsAddresses = Get-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4

    $localhost = '127.0.0.1'
    if ($currentDnsAddresses.ServerAddresses -notcontains $localhost)
    {
        # Add the consul IP address to the list of DNS servers and make sure it's the first one so that it gets the first go at
        # resolving all the DNS queries.
        # We'll keep the previously set DNS addresses so that in case of failure we still have a DNS server to resolve addresses against.
        $serverDnsAddresses = @( $localhost )
        $serverDnsAddresses += $currentDnsAddresses.ServerAddresses
        Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $serverDnsAddresses -Verbose
    }
  POWERSHELL
end

# Disable the caching of negative DNS responses because that would stop Consul from working as a DNS for a period of time
# if there is a failed DNS request (e.g. the Consul machine is busy or something)
registry_key 'HKLM\\SYSTEM\\CurrentControlSet\\Services\\Dnscache\\Parameters' do
  values [
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
    },
    {
      name: 'MaxNegativeCacheTtl',
      type: :dword,
      data: 0x0
    }]
  action :create
end
