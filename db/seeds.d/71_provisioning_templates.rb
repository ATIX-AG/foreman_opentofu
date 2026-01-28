# frozen_string_literal: true

User.as_anonymous_admin do
  ProvisioningTemplate.without_auditing do
    # Create TemplateKind
    Foreman::Plugin.find(:foreman_opentofu).get_template_labels.keys.map(&:to_sym).each do |type|
      kind ||= TemplateKind.unscoped.find_or_create_by(name: type)
      # kind.description = TemplateKind.default_template_descriptions[kind.name]
      kind.save!
    end

    SeedHelper.import_templates(
      Dir[File.join("#{ForemanOpentofu::Engine.root}/app/views/templates/provisioning/**/*.erb")],
      'ForemanOpentofu'
    )
  end
end
