class Asset < ApplicationRecord
  belongs_to :collection
  scope :listed, -> { where(last_event_type: "created") }
end
