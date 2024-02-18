class AddTimestampsToBets < ActiveRecord::Migration[7.0]
  def change
    add_timestamps :bets, default: Time.zone.now
    change_column_default :bets, :created_at, nil
    change_column_default :bets, :updated_at, nil
  end
end
