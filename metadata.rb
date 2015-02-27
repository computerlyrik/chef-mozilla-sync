name              'mozilla-sync'
maintainer        'computerlyrik, Christian Fischer'
maintainer_email  'chef-cookbooks@computerlyrik.de'
license           'All rights reserved'
description       'Installs/Configures sync-1.5'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version           '0.2.1'
source_url "https://github.com/computerlyrik/chef-mozilla-firefox-sync.git"

depends 'nginx'
depends 'certificate'
depends 'git'

supports 'debian'
