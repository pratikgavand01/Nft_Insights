class Collection < ApplicationRecord
  has_paper_trail on: [:destroy]

  has_many :assets, dependent: :destroy
end
