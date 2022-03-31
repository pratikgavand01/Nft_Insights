class CreateJobsActivities < ActiveRecord::Migration[7.0]
  def change
    create_table :jobs_activities do |t|
      t.integer :job_name
      t.integer :job_type
      t.datetime :start_time
      t.datetime :end_time
      t.integer :status
      t.integer :records_count
      t.text :failed_reason

      t.timestamps
    end
  end
end
