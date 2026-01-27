# frozen_string_literal: true

User.as_anonymous_admin do
  ProvisioningTemplate.without_auditing do
    SeedHelper.import_templates(
      Dir[File.join("#{ForemanOpentofu::Engine.root}/app/views/templates/provisioning/**/*.erb")]
    )
  end
end
