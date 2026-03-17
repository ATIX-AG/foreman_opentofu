Deface::Override.new(
  virtual_path: 'compute_resources_vms/form/_networks',
  name: 'tofu_indexed_networks_fields',
  replace_contents: 'div.children_fields',
  partial: 'foreman_opentofu/compute_resources_vms/indexed_networks_fields',
  namespaced: true
)
