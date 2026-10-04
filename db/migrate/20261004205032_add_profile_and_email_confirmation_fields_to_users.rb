# ported from community_bookshelf db/migrate/20260821230727_add_profile_fields_to_users.rb
# and db/migrate/20260822030539_add_email_confirmation_sent_at_to_users.rb
class AddProfileAndEmailConfirmationFieldsToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :name, :string
    add_column :users, :bio, :text
    add_column :users, :email_confirmed_at, :datetime
    add_column :users, :email_confirmation_token, :string
    add_column :users, :email_confirmation_sent_at, :datetime
    add_index :users, :email_confirmation_token, unique: true

    # Confirmation is informational-only (not enforced), but backfilling
    # existing accounts as confirmed avoids showing every pre-existing user
    # a "please confirm your email" nudge the day this feature ships.
    execute "UPDATE users SET email_confirmed_at = created_at WHERE email_confirmed_at IS NULL"
  end

  def down
    remove_index :users, :email_confirmation_token
    remove_column :users, :email_confirmation_sent_at
    remove_column :users, :email_confirmation_token
    remove_column :users, :email_confirmed_at
    remove_column :users, :bio
    remove_column :users, :name
  end
end
