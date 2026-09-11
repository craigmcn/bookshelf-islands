# ported from community_bookshelf db/migrate (adds started_on/finished_on/
# progress_percent/format/is_review_public to readings)
class AddTrackingFieldsToReadings < ActiveRecord::Migration[8.1]
  def change
    add_column :readings, :started_on, :date
    add_column :readings, :finished_on, :date
    add_column :readings, :progress_percent, :integer
    add_column :readings, :format, :integer
    add_column :readings, :is_review_public, :boolean, default: true, null: false

    add_check_constraint :readings,
      "progress_percent IS NULL OR progress_percent >= 0 AND progress_percent <= 100",
      name: "readings_progress_percent_range"
  end
end
