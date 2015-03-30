# ops-resource-core
The ops_resource_core repository contains all the scripts and cookbooks required to provide some base services on a machine. 

At the moment the following services / files are installed as part of the application of the ops_resource_core scripts:

* The c:\meta\meta.json file describing which cookbooks were used to configure the machine.
* The [consul](https://consul.io/) client application which provides monitoring of the machine and a distributed key store that is used to indicate which services are installed on the machine and what environment the machine belongs to.

Besides the cookbook a set of initialization scripts are provided that can be used to connect to an existing networked windows machine or to create a new windows machine in the Azure cloud.

## Usage

It is assumed that the configuration of the machine can easily done through the provided powershell scripts. These scripts will connect to the machine that should be configured, copy all the cookbooks, configuration scripts and other files across and then execute the cookbooks in the correct order.

There are currently scripts for connecting to machines that are attached to a local network and for the creation of machines in the Azure cloud.

In order to collect all the cookbooks and configuration scripts in the correct location execute the `distribute.core.msbuild` script passing the following parameters:

* **DirOrigin** - The directory that contains the additional cookbooks and scripts that should be used for the machine configuration. It is assumed that:
    * Cookbooks will be found in `<DirOrigin>\cookbooks`
    * Server spec files will be found in `<DirOrigin>\spec` 
    * All client scripts will be found in `<DirOrigin>\scripts\client`
    * All host scripts will be found in `<DirOrigin>\scripts\host`
* **DirOutput** - The directory where all the scripts and cookbooks should be placed in.
* **DirExternalInstallers** - The directory that contains all the external files, e.g. for consul. It is assumed that the following directories and files exist:
    * **`<DirExternalInstallers>\chef`** - The directory that contains the chef client installer. The scripts are currently expecting `chef-client-12.1.2-1.msi`.
    * **`<DirExternalInstallers>\consul`** - The directory that contains the [consul](https://consul.io/) executable in zipped form.
    * **`<DirExternalInstallers>\winsw`** - The directory that contains the [winsw](https://github.com/kohsuke/winsw/) executable. The cookbooks are currently expecting version 1.17
* **ConsulEntryPointIp** - The IP address of one of the consul nodes on the network.

Upon completion of the msbuild script the `DirOutput` will contain two directories, one containing all the configuration files and one containing all the verification files (e.g. the [serverspec](http://serverspec.org/) scripts)

From there on the initialization scripts can be called.

## Installation instructions

The cookbooks and required scripts can be found on [NuGet.org](https://nuget.org).

## Contributing

To build the project invoke MsBuild on the `build.msbuild` script in the repository root directory. This will package the scripts and create the NuGet packages and ZIP archives. Final artifacts will be placed in the `build\deploy` directory.

The build script assumes that:

* The connection to the repository is available so that the version number can be obtained via [GitVersion](https://github.com/ParticularLabs/GitVersion).
* The NuGet command line executable is available from the PATH
* Ruby 2.0 is installed with the following gems
    * chef (>= 12.0.3)
    * chef-zero (>= 3.2.1)
    * chefspec (>= 4.2.0)
    * foodcritic (>= 4.0.0)
    * rubocop (>= 0.28.0)