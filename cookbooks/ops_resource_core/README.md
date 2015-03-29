ops_resource_core Cookbook
======================
This cookbook installs the applications and files that should be present on all machines that are created. Default installed are:
* The c:\meta\meta.json file describing which cookbooks were used to configure the machine.
* The [consul](https://consul.io/) client application which provides monitoring of the machine and a distributed key store that is used to indicate which services are installed on the machine and what environment the machine belongs to.

Requirements
------------

#### cookbooks
- `chef_handler`
- `windows`
- `windows_firewall`

Attributes
----------
TODO: List your cookbook attributes here.

e.g.
#### ops_resource_core::default
<table>
  <tr>
    <th>Key</th>
    <th>Type</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td><tt>['paths']['meta']</tt></td>
    <td>String</td>
    <td>The path to the directory that contains the meta data.</td>
    <td><tt>c:\meta</tt></td>
  </tr>
  <tr>
    <td><tt>['paths']['consul_base']</tt></td>
    <td>String</td>
    <td>The path to the directory that contains the consul directories.</td>
    <td><tt>c:\ops\consul</tt></td>
  </tr>
  <tr>
    <td><tt>['paths']['consul_bin']</tt></td>
    <td>String</td>
    <td>The path to the directory that contains the consul executable.</td>
    <td><tt>c:\ops\consul</tt></td>
  </tr>
  <tr>
    <td><tt>['paths']['consul_data']</tt></td>
    <td>String</td>
    <td>The path to the directory that contains the consul data files.</td>
    <td><tt>c:\ops\consul</tt></td>
  </tr>
  <tr>
    <td><tt>['paths']['consul_checks']</tt></td>
    <td>String</td>
    <td>The path to the directory that contains the consul checks files.</td>
    <td><tt>c:\ops\consul</tt></td>
  </tr>
  <tr>
    <td><tt>['paths']['consul_config']</tt></td>
    <td>String</td>
    <td>The path to the directory that contains the consul configuration files.</td>
    <td><tt>c:\meta\consul</tt></td>
  </tr>
</table>

Usage
-----
#### ops_resource_core::default
Just include `ops_resource_core` in your node's `run_list`:

```json
{
  "name":"my_node",
  "run_list": [
    "recipe[ops_resource_core]"
  ]
}
```

Contributing
------------
In order to contribute please see contribution guidelines at [github](https://github.com/pvandervelde/ops-resource-core)

License and Authors
-------------------
Authors: Patrick van der Velde

Licensed under the Apache 2.0 license
