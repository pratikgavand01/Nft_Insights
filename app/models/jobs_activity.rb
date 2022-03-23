class JobsActivity < ApplicationRecord
  enum job_type: [:events]
  enum status: [:active, :completed, :failed]
  
end
