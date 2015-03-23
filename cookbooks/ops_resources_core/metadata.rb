name 'ops_resources_core'
maintainer '${CompanyName} (${CompanyUrl})'
maintainer_email '${EmailDocumentation}'
license 'All rights reserved'
description 'Configures a server with the standard core applications'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version '${VersionSemantic}'

depends 'windows'
depends 'windows_firewall'
