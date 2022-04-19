class CreateJobsActivities < ActiveRecord::Migration[7.0]
  TEXT_BYTES = 1_073_741_823
  def change
    create_table :jobs_activities do |t|
      t.integer :job_name
      t.integer :job_type
      t.datetime :start_time, default: -> { 'CURRENT_TIMESTAMP' }
      t.datetime :end_time
      t.integer :status
      t.integer :records_count, default: 0
      t.jsonb :log, default: {}
      t.text :failed_reason, limit: TEXT_BYTES

      t.timestamps
    end
    add_index :jobs_activities, :id, unique: true
    add_index :jobs_activities, :created_at
    add_index :jobs_activities, :updated_at
  end
end
