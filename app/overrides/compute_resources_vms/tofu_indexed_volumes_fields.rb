Deface::Override.new(
  virtual_path: 'compute_resources_vms/form/_volumes',
  name: 'tofu_indexed_volumes_fields',
  replace_contents: 'div.children_fields',
  partial: 'foreman_opentofu/compute_resources_vms/indexed_volumes_fields',
  original: '7d0607bbae4c5123e89fff9968e2740a3d0eb323',
  namespaced: true
)
