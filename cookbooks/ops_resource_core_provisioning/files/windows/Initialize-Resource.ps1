<#
    .SYNOPSIS

    Executes all configuration and provisioning steps necessary to link the current resource to a given environment.


    .DESCRIPTION

    The Initialize-Resource script executes all configuration and provisioning steps necessary to link the current resource to a given environment.
#>
[Cmdletbinding()]
param(
)

# READ CONFIGURATION FILE

# -> Configuration file has single URI
#    -> Call get on that URI to


# Get URL

# send request to URL. Request should contain:
# - container ID: e.g. machine MAC, container ID, etc. etc.
# - resource ID: e.g. ops-resource-core, webserver etc.



# GET CONFIGURATION FROM CONFIGURATION HOST



# INVOKE ALL POWERSHELL FILES IN THE PROVISIONING DIRECTORY THAT ARE NAMED: Initialize-XXXResource

