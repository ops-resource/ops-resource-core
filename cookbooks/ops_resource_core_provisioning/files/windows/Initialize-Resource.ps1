<#
    .SYNOPSIS

    Executes all configuration and provisioning steps necessary to link the current resource to a given environment.


    .DESCRIPTION

    The Initialize-Resource script executes all configuration and provisioning steps necessary to link the current resource to a given environment.


    .EXAMPLE

    Install-ApplicationsOnWindowsWithChef -configurationDirectory "c:\temp\configuration" -logDirectory "c:\temp\logs" -cookbookNames "myCookbook", "myOtherCookbook"
#>
[Cmdletbinding()]
param(
)

# READ CONFIGURATION FILE




# GET CONFIGURATION FROM CONFIGURATION HOST
#


# INVOKE ALL POWERSHELL FILES IN THE PROVISIONING DIRECTORY THAT ARE NAMED: Initialize-XXXResource

