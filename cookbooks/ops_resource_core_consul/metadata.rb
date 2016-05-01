name 'ops_resource_core_consul'
maintainer '${CompanyName} (${CompanyUrl})'
maintainer_email '${EmailDocumentation}'
license 'Apache v2.0'
description 'Configures a server with a consul service'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version '${VersionSemantic}'

depends 'windows', '~>1.38.3'
depends 'windows_firewall', '~>3.0.0'
depends 'ops_resource_core_meta', '~>${VersionSemantic}'
depends 'ops_resource_core_provisioning', '~>${VersionSemantic}'
