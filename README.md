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

### Create new ProviderType

This Plugin empowers you to add support of a new backend VM- or Cloud-Platform yourself.
Follow these simple steps to do so:

#### Find OpenTofu Provider

Visit the OpenTofu Registry to find a suitable [provider supported by OpenTofu](https://search.opentofu.org/providers).
The Registry supplies the necessary Data Sources to read information from the Backend as well as Resources to create/update/destroy resources on the Backend.

#### Create Template

You may use the UI-Editor in Hosts -> Templates -> Provisioning Templates to create a new Template.
Either clone a pre-installed template or create one from scratch.
In the latter case be sure to select the correct Template Type: OpenTofu Script template.

#### Create Parameter Config

To define which Virtual Machine parameters can be set for a new Host a new config file under `/config` must be added.
Feel free to use either YAML or JSON (be sure to end the filename with `.json` or `.yaml`).
The config file defines an array of dicts, where each dict represents a configuration-parameter.

A config-parameter has the following values:

* `name`: the OpenTofu Provider Resource Arguments as stated on the OpenTofu Registry
* `label`: the label shown in the Foreman UI
* `type`: data-type of the value, supported values:
  * `string`
  * `number`
  * `bool`
  * `select`: requires setting `options`
* `help`: Tooltip describing what that value does and what values are allowed
* `mandatory`: `true`/`false` defines if omitting the value triggers an error
* `options`: array of strings representing the possible values
* `group`: define where the value should be configured
   * `vm`: ones per Host in the 'Virtual Machine' tab,
   * `disk`: for each defined disk/volume in the 'Virtual Machine' tab
   * `nic`: for each defined network-interface on the 'Interfaces' tab

A short config file might look like this:

```json
[
  { "name": "memory_size_mib", "type": "number", "group": "vm", "mandatory": false,
    "label": "Memory (MB)" },
  { "name": "boot_type", "type": "select", "group": "vm", "mandatory": false,
    "label": "Firmware", "options": [ "UEFI", "LEGACY", "SECURE_BOOT" ] },
  { "name": "disk_size_mib", "type": "number", "group": "disk", "mandatory": true,
    "label": "Size (MB)" },
  { "name": "model", "type": "select", "group": "nic", "mandatory": true,
    "options": [ "VIRTIO", "E1000" ] }
]
```

The name of the file must be the same as the provider-type name we set in the next step (e.g. `/config/nutanix.json`).

#### Create Provider Type

To let the Foreman OpenTofu Plugin know about your new Provider Type, one additional file has to be created in `/lib/foreman_opentofu/provider_types/`.

A very simple ProviderType file to add a new Provider named `nutanix` has to be located in `lib/foreman_opentofu/provider_types/nutanix.rb` and might look like this:

```ruby
ForemanOpentofu::ProviderTypeManager.register('nutanix') do
end
```

Additional informations about the ProviderType can be set within the `register`-block:

##### `default_attributes`

Define values that should be set as default for attributes.
The values do not have to be defined in the config-file.
If attributes are also defined in the config-file and therefore set during Host creation, the default\_attribute values will be overwritten.

```ruby
ForemanOpentofu::ProviderTypeManager.register('nutanix') do
  @default_attributes = {
    'enable_cpu_passthrough' => true,
    'num_threads_per_core' => 2,
  }
end
```


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
