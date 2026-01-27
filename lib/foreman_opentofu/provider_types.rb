Dir["#{File.expand_path('provider_types', __dir__)}/*.rb"].each do |file|
  load file
end
