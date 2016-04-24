name 'ops_resource_core_provisioning'
maintainer '${CompanyName} (${CompanyUrl})'
maintainer_email '${EmailDocumentation}'
license 'All rights reserved'
description 'Configures a server with the scripts and tools necessary to provide configuration and provisioning upon adding to an environment.'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version '${VersionSemantic}'

depends 'windows', '~>1.38.3'
depends 'ops_resource_core_meta', '~>${VersionSemantic}'
