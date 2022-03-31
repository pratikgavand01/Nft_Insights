class JobsActivity < ApplicationRecord
  enum job_name: [:created_events, :successful_events, :cancelled_events, :bulk_cancel_events]
  enum job_type: [:past_data, :delta] # past means Historic data, Delta means Upto last request
  enum status: [:active, :completed, :failed]
  
end
