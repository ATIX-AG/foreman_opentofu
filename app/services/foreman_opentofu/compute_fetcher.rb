module ForemanOpentofu
  class ComputeFetcher
    def self.fetch_subnets(compute_resource)
      return [] unless compute_resource == 'Nutanix'
      attrs = []
      Dir.mktmpdir('opentofu_') do |dir|
        tofu = ForemanOpentofu::AppWrapper.new(dir)
        tofu.main_configuration = tf_content(compute_resource)
        tofu.init
        tofu.apply
        attrs = tofu.output('subnets')
      end
      attrs.map { |h| OpenStruct.new(h) }
    rescue StandardError => e
      Rails.logger.error("Failed to fetch subnets: #{e}")
      []
    end

    def self.tf_content(compute_resource)
      <<~HCL
        terraform {
          required_providers {
            nutanix = {
              source  = "nutanix/nutanix"
              version = ">=1.6.0"
            }
          }
        }

        provider "nutanix" {
          username = "#{compute_resource.user}"
          password = "#{compute_resource.password}"
          endpoint = "#{compute_resource.url}"
          insecure = true
        }

        # Fetch all subnets
        data "nutanix_subnets" "all" {}

        output "subnets" {
          value = [
            for s in data.nutanix_subnets.all.entities : {
              id = s.metadata.uuid
              name = s.name
            }
          ]
        }
      HCL
    end
  end
end
