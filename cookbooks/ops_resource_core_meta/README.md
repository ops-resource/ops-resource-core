ops_resource_core_meta Cookbook
======================
This cookbook installs the c:\meta\meta.json file describing which cookbooks were used to configure the machine.

Requirements
------------

#### cookbooks

Attributes
----------

#### ops_resource_core_meta::default
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
</table>

Usage
-----
#### ops_resource_core_meta::default
Just include `ops_resource_core_meta` in your node's `run_list`:

```json
{
  "name":"my_node",
  "run_list": [
    "recipe[ops_resource_core_meta]"
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
