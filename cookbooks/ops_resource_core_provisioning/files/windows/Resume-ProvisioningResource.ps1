<#
    .SYNOPSIS

    Resumes the provisioning service


    .DESCRIPTION

    The Resume-ProvisioningResource script resumes the provisioning service so that it is ready to start after the next reboot.
#>
[Cmdletbinding()]
param(
)

$ErrorActionPreference = 'Stop'

$commonParameterSwitches =
    @{
        Verbose = $PSBoundParameters.ContainsKey('Verbose');
        Debug = $false;
        ErrorAction = "Stop"
    }

Set-Service `
    -Name 'Provisioning' `
    -StartupType Automatic `
    @($this.commonParameterSwitches)
