<#
    This file contains the 'verification tests' for the 'consul' section of the ops_resource_core cookbook. These tests are executed
    using Pester (https://github.com/pester/Pester).
#>

# Load the consul utilities script
. $(Join-Path (Split-Path $PSScriptRoot -Parent) 'consul.ps1')

Describe 'Consul installation:' {

    Context 'The install location' {
        It 'has the directories' {
            'c:\ops' | Should Exist
            'c:\ops\consul' | Should Exist
            'c:\ops\consul\bin' | Should Exist
            'c:\ops\consul\data' | Should Exist
        }

        It 'has the Consul binaries' {
            'c:\ops\consul\bin\consul_service.exe' | Should Exist
            'c:\ops\consul\bin\consul_service.xml' | Should Exist
            'c:\ops\consul\bin\consul_service.exe.config' | Should Exist
            'c:\ops\consul\bin\consul.exe' | Should Exist
        }

        It 'has a valid default consul configuration file' {
            $consulConfiguration = 'c:\ops\consul\bin\consul_default.json'
            $consulConfiguration | Should Exist
            { Get-Content $consulConfiguration | Out-String | ConvertFrom-Json } | Should Not Throw
        }
    }

    Context 'The meta install location' {
        It 'has the directories' {
            'c:\meta' | Should Exist
            'c:\meta\consul' | Should Exist
            'c:\meta\consul\checks' | Should Exist
        }

        It 'has the Consul checks' {
            'c:\meta\consul\checks\Test-Disk.ps1' | Should Exist
        }

        It 'has a valid check_server file' {
            $checkServer = 'c:/meta/consul/check_server.json'
            $checkServer | Should Exist
            { Get-Content $checkServer | Out-String | ConvertFrom-Json } | Should Not Throw
        }
    }

    Context 'The consul service' {
        $service = Get-WmiObject win32_service | Where {$_.name -eq 'consul'} | Select -First 1
        It 'is running as consul_user' {
            $service | Should Not BeNullOrEmpty
            $service.StartName | Should Be '.\consul_user'
        }

        It 'starts automatically' {
            $service.StartMode | Should Be 'Auto'
        }

        It 'responds to queries' {
            $service.Started | Should Be 'True'

            $response = Invoke-WebRequest -Uri 'http://localhost:8500/v1/agent/self' -UseBasicParsing -UseDefaultCredentials
            $json = ConvertFrom-Json -InputObject $response
            $json.Config.Version | Should Be '0.6.4'
        }
    }
}
