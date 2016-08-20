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

        It 'has the binaries' {
            'c:\ops\consul\bin\consul_service.exe' | Should Exist
            'c:\ops\consul\bin\consul_service.xml' | Should Exist
            'c:\ops\consul\bin\consul_service.exe.config' | Should Exist
            'c:\ops\consul\bin\consul.exe' | Should Exist
        }

        It 'has a valid default configuration file' {
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

        It 'has the checks' {
            'c:\meta\consul\checks\Test-Disk.ps1' | Should Exist
        }

        It 'has a valid check_server file' {
            $checkServer = 'c:/meta/consul/check_server.json'
            $checkServer | Should Exist
            { Get-Content $checkServer | Out-String | ConvertFrom-Json } | Should Not Throw
        }
    }

    Context 'The logs install location' {
        It 'has the directories' {
            'c:\logs' | Should Exist
            'c:\logs\consul' | Should Exist
        }
    }

    Context 'The service' {
        $wmiSservice = Get-WmiObject win32_service | Where-Object {$_.name -eq 'consul'} | Select-Object -First 1
        It 'is running as the correct user' {
            $wmiSservice | Should Not BeNullOrEmpty
            $wmiSservice.StartName | Should Be '.\consul_user'
        }

        $psService = Get-Service 'consul'
        It 'starts automatically' {
            $psService.StartType | Should Be [System.ServiceProces.ServiceStartMode]::Automatic

            # There is no sensible way to get the restart options, only to set them so
            # we'll have to assume they're set correctly ...???
        }

        It 'is running' {
            $psService.Status | Should Be 'Running'
        }

        It 'has the correct version number' {
            $response = Invoke-WebRequest -Uri 'http://localhost:8500/v1/agent/self' -UseBasicParsing -UseDefaultCredentials
            $json = ConvertFrom-Json -InputObject $response
            $json.Config.Version | Should Be '0.6.4'
        }

        It 'has the correct configuration' {
            $response = Invoke-WebRequest -Uri 'http://localhost:8500/v1/agent/self' -UseBasicParsing -UseDefaultCredentials
            $json = ConvertFrom-Json -InputObject $response

            # This assumes that these values are only set for the duration of the test
            $json.Config.Server | Should Be $true
            $json.Config.Datacenter | Should be 'TestHyperVImage'
            $json.Config.Domain | Should be 'imagetest'

            $recursors = @($json.Config.DNSRecursors)
            $recursors.Length -ge 1 | Should Be $true
        }
    }
}

Describe 'Consul-template installation:' {

    Context 'The install location' {
        It 'has the directories' {
            'c:\ops' | Should Exist
            'c:\ops\consultemplate' | Should Exist
            'c:\ops\consultemplate\bin' | Should Exist
        }

        It 'has the binaries' {
            'c:\ops\consultemplate\bin\consultemplate_service.exe' | Should Exist
            'c:\ops\consultemplate\bin\consultemplate_service.xml' | Should Exist
            'c:\ops\consultemplate\bin\consultemplate_service.exe.config' | Should Exist
            'c:\ops\consultemplate\bin\consul-template.exe' | Should Exist
        }

        It 'has a valid default configuration file' {
            $consulConfiguration = 'c:\ops\consultemplate\bin\consultemplate_default.json'
            $consulConfiguration | Should Exist
            { Get-Content $consulConfiguration | Out-String | ConvertFrom-Json } | Should Not Throw
        }
    }

    Context 'The meta install location' {
        It 'has the directories' {
            'c:\meta' | Should Exist
            'c:\meta\consultemplate' | Should Exist
            'c:\meta\consultemplate\templates' | Should Exist
        }
    }

    Context 'The logs install location' {
        It 'has the directories' {
            'c:\logs' | Should Exist
            'c:\logs\consultemplate' | Should Exist
        }
    }

    Context 'The service' {
        $wmiSservice = Get-WmiObject win32_service | Where-Object {$_.name -eq 'consultemplate'} | Select-Object -First 1
        It 'is running as the correct user' {
            $wmiSservice | Should Not BeNullOrEmpty
            $wmiSservice.StartName | Should Be '.\consultemplate_user'
        }

        $psService = Get-Service 'consultemplate'
        It 'starts automatically' {
            $psService.StartType | Should Be [System.ServiceProces.ServiceStartMode]::Automatic

            # There is no sensible way to get the restart options, only to set them so
            # we'll have to assume they're set correctly ...???
        }

        It 'depends on consul' {
             # Should doesn't work with array's so do this the nasty way
            $dependencies = $psService.ServicesDependedOn | Select-Object -Property Name

            $dependencies.Length | Should Be 1
            $dependencies.Contains('consul') | Should Be $true
        }

        It 'is running' {
            $psService.Status | Should Be [System.ServiceProcess.ServiceControllerStatus]::Running
        }
    }
}
