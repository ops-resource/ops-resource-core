name 'ops_resource_core_consul'
maintainer '${CompanyName} (${CompanyUrl})'
maintainer_email '${EmailDocumentation}'
license 'Apache v2.0'
description 'Configures a server with a consul service'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version '${VersionSemantic}'

depends 'windows', '~>1'
depends 'windows_firewall', '~>3'
depends 'ops_resource_core_meta', '~>${VersionMajor}'
depends 'ops_resource_core_provisioning', '~>${VersionMajor}'
