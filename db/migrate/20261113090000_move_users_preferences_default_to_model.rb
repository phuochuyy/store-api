class MoveUsersPreferencesDefaultToModel < ActiveRecord::Migration[8.1]
  # MySQL rejects a literal default on a JSON column (error 1101), so the schema could not
  # load there. The {} default now lives in the User model, which covers every record the
  # app creates; existing rows keep their values.
  def change
    change_column_default :users, :preferences, from: {}, to: nil
  end
end
