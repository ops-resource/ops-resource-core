ops_resource_core_provisioning Cookbook
======================
This cookbook installs scripts and tools to handle the configuration of the machine as it is added to an environment.

Requirements
------------

#### cookbooks
- `windows`

Attributes
----------

#### ops_resource_core_provisioning::default
<table>
  <tr>
    <th>Key</th>
    <th>Type</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td><tt>['paths']['consul_base']</tt></td>
    <td>String</td>
    <td>The path to the directory that contains the consul directories.</td>
    <td><tt>c:\ops\consul</tt></td>
  </tr>
</table>

Usage
-----
#### ops_resource_core_provisioning::default
Just include `ops_resource_core_provisioning` in your node's `run_list`:

```json
{
  "name":"my_node",
  "run_list": [
    "recipe[ops_resource_core_provisioning]"
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
