[![Ruby Tests](https://github.com/ATIX-AG/foreman_opentofu/actions/workflows/ruby.yml/badge.svg)](https://github.com/ATIX-AG/foreman_opentofu/actions/workflows/ruby.yml)

# Foreman OpenTofu

[Foreman](http://theforeman.org/) plugin that adds that adds a generic OpenTofu-based compute resource, enabling host provisioning through OpenTofu scripts instead of provider-specific SDK integrations such as fog-vsphere.

This plugin introduces a new provisioning model where Foreman remains responsible for host lifecycle and orchestration, while OpenTofu handles infrastructure creation using its provider ecosystem.

The plugin is designed to be easily extendable and can support multiple infrastructure platforms (for example Nutanix, Hetzner) without requiring a dedicated Foreman compute resource plugin per provider.

## Installation

Install the rubygem as usual or use the RPM/Deb package for your distribution.

If you use the rubygem, make sure to create the folllowing directory and set the correct permissions:

```shell

mkdir -p /var/lib/foreman-opentofu
mkdir -p /var/lib/foreman-opentofu/plugin-cache
mkdir -p /var/lib/foreman-opentofu/tmp

chown -R foreman:foreman /var/lib/foreman-opentofu
chmod 755 /var/lib/foreman-opentofu
chmod 755 /var/lib/foreman-opentofu/plugin-cache
chmod 700 /var/lib/foreman-opentofu/tmp
```

## SELinux

If you have installed the rubygem manually, you need to set the correct SELinux context for the plugin to work properly.
Re-use the selinux directives defined in the selinux directory of the plugin.

```shell
cd selinux
make clean && make all
mkdir -p /usr/share/selinux/targeted/
install -m 0600 foreman_opentofu.pp /usr/share/selinux/targeted/
/usr/sbin/semodule -i /usr/share/selinux/targeted/foreman_opentofu.pp
/sbin/restorecon -ri /var/lib/foreman-opentofu/
```


## Usage
Create a OpenTofu compute resource and set:
  * Provider: OpenTofu
  * OpenTofu Provider: Select desired hypervisor supported by OpenTofu plugin
  * URL: Hypervisor specific URL
    

Then add all necessary information to the form.

Provisioning workflow:

 * Create a host in Foreman using the OpenTofu based compute resource

 * Foreman passes host parameters to the plugin

 * The plugin renders and executes OpenTofu plans

 * OpenTofu provisions the infrastructure

 * Foreman continues with OS provisioning and configuration

Provider-specific details (for example Nutanix, Hetzner) are handled entirely through OpenTofu scripts.

### Add support for a new Tofu-Provider

This Plugin empowers you to add support of a new backend VM- or Cloud-Platform yourself.
Follow these simple steps to do so:

#### Find OpenTofu Provider

Visit the OpenTofu Registry to find a suitable [provider supported by OpenTofu](https://search.opentofu.org/providers).
The Registry supplies the necessary Data Sources to read information from the Backend as well as Resources to create/update/destroy resources on the Backend.

#### Create Template

You may use the UI-Editor in Hosts -> Templates -> Provisioning Templates to create a new Template.
Either clone a pre-installed template or create one from scratch.
In the latter case be sure to select the correct Template Type: OpenTofu Script template.


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

#### Create Parameter Config

To define which Virtual Machine parameters can be set for a new Host the `self.provider_attrs` variable must be defined within the `register`-block.
The `provider_attrs`-variable defines an Array of Dicts/Hashes, where each Dict/Hash represents a configuration-parameter.

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
* `default`: default-value should be specified if parameter is mandatory and options is empty
* `group`: define where the value should be configured
   * `vm`: ones per Host in the 'Virtual Machine' tab,
   * `disk`: for each defined disk/volume in the 'Virtual Machine' tab
   * `nic`: for each defined network-interface on the 'Interfaces' tab

A short definition might look like this:

```ruby
self.provider_attrs = [
  { name: 'memory_size_mib', type: 'number', group: 'vm', mandatory: false,
    label: 'Memory (MB)' },
  { name: 'boot_type', type: 'select', group: 'vm', mandatory: false,
    label: 'Firmware', options: [ 'UEFI', 'LEGACY', 'SECURE_BOOT' ] },
  { name: 'disk_size_mib', type: 'number', group: 'disk', mandatory: true,
    label: 'Size (MB)' },
  { name: 'model', type: 'select', group: 'nic', mandatory: true,
    options: [ 'VIRTIO', 'E1000' ] }
]
```

##### Dynamic Config Parameter

Sometimes it is necessary to provide a list of possible values that are defined by the backend-service.
Curating the 'options'-Array is tedious at best or not possible if multiple instances of the backend service are in use.
This can be addressed by specifiying an OpenTofu provider's [DataSource](https://opentofu.org/docs/language/data-sources/) in the following way:

```ruby
{
  name: 'volume_group', type: 'select', group: 'disk', mandatory: true, label: 'Volume Group',
  options: {
    data_source: {
      name: 'nutanix_volume_groups_v2',
      arguments: {
        filter: 'name eq 'volume_group_test'',
        limit: 20
      },
      entity: {
        id: 'metadata.uuid'
      }
    },
    output_path_postfix: 'volume_groups'
  }
}

```
The GUI requires a list of objects that at least contains a name and an id for each select-option.
The `entity` section can be used to define a specific value from an object within the list that the DataSource returns.
If the object already has `name` and `id` entries, these will automatically used.
In the above example `name` exists in the object and can be used.
For the `id` however, a different value must be selected from the object.

This requests the data via OpenTofu in the following construct:

```hcl
data "nutanix_volume_groups_v2" "all" {
  filter = "name eq 'volume_group_test'"
  limit = 20
}
output "resources" {
  value = [ for e in data.nutanix_volume_groups_v2.all.volume_groups: {
    id = e.metadata.uuid
    name = e.name
  } ]
}
```

##### Special Parameter

Some config parameter names have special meanings.
For instance, Image-based Deployment requires binding images available on the backend-service with Operating Systems configured in Foreman.

###### available\_images

To enable Foreman OpenTofu to display the available images, a `select`-parameter with the name `available_images` must be specified.
It is recommended to tie this to a data-source available in the OpenTofu provider.

```ruby
{
  name: 'available_images', type: 'select',
  options: {
    data_source: {
      name: 'hcloud_images',
      arguments: { with_architecture: ['x86'] }
    },
    output_path_postfix: 'images'
  }
}
```

###### available\_ssh\_keys

Cloud-based Providers usually require an SSH key pair to configure image-based hosts.
This dynamic data-source should provide a list of SSH keys known to the cloud-provider.

```ruby
{
  name: 'available_ssh_keys', type: 'select',
  label: 'SSH-Deployment-Keys', options: {
    data_source: {
      name: 'hcloud_ssh_keys',
    },
    entity: {
      fingerprint: 'fingerprint',
    },
    output_path_postfix: 'ssh_keys',
  }
}
```


## Development

### Dev prerequisites

> See [Foreman dev setup](https://github.com/theforeman/foreman/blob/develop/developer_docs/foreman_dev_setup.asciidoc)

* You need a OpenTofu installed on your machine.
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

* In the `foreman_opentofu` directory, check code syntax with rubocop and foreman rules:

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
