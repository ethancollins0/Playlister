class CreateSongs < ActiveRecord::Migration[5.2]
  def change
    create_table :songs do |t|
      t.string :title
      t.string :artist
      t.string :album
      t.string :genre
      t.string :year
      t.string :track_id
      t.string :track_url
      t.string :track_sample_url
    end
  end
end
