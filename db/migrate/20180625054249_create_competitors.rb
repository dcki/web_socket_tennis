class CreateCompetitors < ActiveRecord::Migration[5.2]
  def change
    create_table :competitors do |t|
      t.integer :user_id
      t.integer :min_velocity
      t.integer :max_velocity
      t.timestamps
    end
  end
end
