Deface::Override.new(
  virtual_path: 'compute_resources_vms/form/_removable_layout',
  name: 'tofu_remove_new_vm_from_removable_layout',
  replace_contents: 'div.remove-button',
  partial: 'foreman_opentofu/compute_resources_vms/form/removable_layout',
  namespaced: true
)
