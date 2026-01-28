[![Ruby Tests](https://github.com/ATIX-AG/foreman_opentofu/actions/workflows/ruby.yml/badge.svg)](https://github.com/ATIX-AG/foreman_opentofu/actions/workflows/ruby.yml)

# ForemanOpenTOFU

[Foreman](http://theforeman.org/) plugin that adds that adds a generic openTOFU-based compute resource, enabling host provisioning through openTOFU scripts instead of provider-specific SDK integrations such as fog-vsphere.

This plugin introduces a new provisioning model where Foreman remains responsible for host lifecycle and orchestration, while openTOFU handles infrastructure creation using its provider ecosystem.

The plugin is designed to be easily extendable and can support multiple infrastructure platforms (for example Nutanix, Hetzner) without requiring a dedicated Foreman compute resource plugin per provider.

## Installation


## Usage
Create a openTofu compute resource and set:
  * Provider: openTofu
  * Opentofu Provider: Select desired hypervisor supported by openTofu plugin
  * URL: Hypervisor specific URL
    

Then add all necessary information to the form.

Provisioning workflow:

 * Create a host in Foreman using the openTOFU based compute resource

 * Foreman passes host parameters to the plugin

 * The plugin renders and executes openTOFU plans

 * openTOFU provisions the infrastructure

 * Foreman continues with OS provisioning and configuration

Provider-specific details (for example Nutanix, Hetzner) are handled entirely through openTOFU scripts.

## Development

### Dev prerequisites

> See [Foreman dev setup](https://github.com/theforeman/foreman/blob/develop/developer_docs/foreman_dev_setup.asciidoc)

* You need a openTOFU installed on your machine.
* You need ruby 2.7. You can install it with [asdf-vm](https://asdf-vm.com).

### Platform

* Fork this github repo.
* Clone it on your local machine
* Install foreman v2.5+ on your machine:

```shell
git clone https://github.com/theforeman/foreman -b develop
```

* Create a Gemfile.local.rb file in foreman/bundler.d/
* Add this line:

```ruby
gem 'foreman_opentofu', :path => '../../theforeman/foreman_opentofu'
```

* In foreman directory, install dependencies:

```shell
gem install bundler
# prerequisites libraries on Ubuntu OS:
bundle install
```

* You can reset and change your admin password if needed:

```shell
RAILS_ENV=development bundle exec bin/rake permissions:reset password=changeme
```

* In foreman_openTofu source directory, check code syntax with rubocop and foreman rules:

```shell
bundle exec rubocop
```

safe autocorrect:

```shell
bundle exec rubocop -a
```

Temporary ignore offenses:

```shell
bundle exec rubocop --auto-gen-config
```

* See deface overrides result:

```shell
bundle exec bin/rake deface:get_result['hosts/_compute_detail']
```

* In foreman directory, after you modify foreman_opentofu translations (language, texts in new files, etc) you have to compile it:

Prerequisites: [Transifex CLI](https://github.com/transifex/cli)

```shell
bundle exec bin/rake plugin:gettext\[foreman_opentofu\]
```

* In foreman directory, run rails server:

```shell
bundle exec bin/rails server
```

* Or you can launch all together:

```shell
bundle exec foreman start
```

See details in [foreman plugin development](https://projects.theforeman.org/projects/foreman/wiki/How_to_Create_a_Plugin)

## Contributing

Fork and send a Pull Request or create Issue. Thank you.

## Copyright
Copyright (c) 2026 ATIX AG - http://www.atix.de

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.
