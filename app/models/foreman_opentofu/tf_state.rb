module ForemanOpentofu
  class TfState < ApplicationRecord
    # DO we need this name or change it to foreman_opentofu_tf_states
    self.table_name = 'tf_states'

    validates :name, presence: true, uniqueness: true
  end
end
