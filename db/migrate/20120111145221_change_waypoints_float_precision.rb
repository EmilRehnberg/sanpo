class ChangeWaypointsFloatPrecision < ActiveRecord::Migration
  def up
    change_column :waypoints, :latitude, :float, :precision => 12, :scale => 16
    change_column :waypoints, :longitude, :float, :precision => 12, :scale => 16
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
