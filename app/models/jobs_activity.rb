class JobsActivity < ApplicationRecord
  has_paper_trail on: [:destroy]

  enum job_name: [:created_events, :successful_events, :cancelled_events, :bulk_cancel_events]
  enum job_type: [:past_data, :delta] # past means Historic data, Delta means Upto last request
  enum status: [:active, :completed, :failed, :terminate, :paused, :rejected], _default: :active

  before_save :validate_status_type, if: :status_changed?

  def self.last_event_time(event_type)
    event = self.where(job_name: "#{event_type}_events").completed.last
    return nil unless event.present?
    event.log["last_event_time"] && event.log["last_event_time"].to_datetime
  end

  private

  def validate_status_type
    self.status = "rejected" if self.status_was == "rejected"
  end

end
