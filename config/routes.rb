Rails.application.routes.draw do
  namespace :api do
    scope '(:apiv)',
      module: :v2,
      defaults: { apiv: 'v2' },
      apiv: /v1|v2/,
      constraints: ApiConstraints.new(version: 2, default: true) do
      match 'tf_states/:name', to: 'tf_states#create', via: :post, constraints: { name: %r{[^/]+} }
      match 'tf_states/:name', to: 'tf_states#show',    via: :get, constraints: { name: %r{[^/]+} }
      match 'tf_states/:name', to: 'tf_states#destroy', via: :delete, constraints: { name: %r{[^/]+} }
    end
  end
end
