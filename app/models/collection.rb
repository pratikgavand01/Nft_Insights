class Collection < ApplicationRecord
  has_many :assets, dependent: :destroy
end
