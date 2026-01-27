Deface::Override.new(
  virtual_path: 'compute_resources/show',
  name: 'remove_virtual_machines_tab',
  replace: "li:has(a[href='#vms'])",
  text: '<% if @compute_resource.class != ForemanOpentofu::Tofu %><li><a href="#vms" data-toggle="tab"><%= _("Virtual Machines") %></a></li> <% end %>',
  original: '15da4ffe56b9d3155f0d037ddffb7653479ee0c8',
  namespaced: true
)
