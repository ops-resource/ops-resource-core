# ops-resource-core
The ops_resource_core repository contains all the scripts and cookbooks required to provide some base services on a machine. 

At the moment the following services / files are installed as part of the application of the ops_resource_core scripts:

* The c:\meta\meta.json file describing which cookbooks were used to configure the machine.
* The [consul](https://consul.io/) client application which provides monitoring of the machine and a distributed key store that is used to indicate which services are installed on the machine and what environment the machine belongs to.

Besides the cookbook a set of initialization scripts are provided that can be used to connect to an existing networked windows machine or to create a new windows machine in the Azure cloud.

## Usage

The ops_resource_core scripts and cookbooks should be added to 


## Installation instructions

The cookbooks and required scripts can be found on [NuGet.org](https://nuget.org).

## Contributing
