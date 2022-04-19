class Asset < ApplicationRecord
  has_paper_trail on: [:destroy]

  belongs_to :collection
  scope :sales, -> { where(last_event_type: "successful") }
  scope :listed, -> { where(last_event_type: "created") }
end
