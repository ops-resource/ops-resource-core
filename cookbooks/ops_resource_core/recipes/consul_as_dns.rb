#
# Cookbook Name:: ops_resource_core
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

    # Add the consul IP address to the list of DNS servers and make sure it's the first one so that it gets the first go at
    # resolving all the DNS queries.
    # We'll keep the previously set DNS addresses so that in case of failure we still have a DNS server to resolve addresses against.
    $serverDnsAddresses = @( '127.0.0.1' )
    $serverDnsAddresses += $currentDnsAddresses.ServerAddresses
    Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $serverDnsAddresses -Verbose
  POWERSHELL
end
