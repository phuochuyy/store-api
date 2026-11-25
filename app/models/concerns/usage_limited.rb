# frozen_string_literal: true

# A use counter with an optional cap (used_count / usage_limit), shared by Discount and Promotion.
#
# Taking a use is a single conditional UPDATE, so concurrent requests can never push used_count
# past usage_limit, on PostgreSQL or MySQL. Reading used_count, checking it and saving it back
# (the old increment_usage!) let every concurrent request see the same free use.
module UsageLimited
  extend ActiveSupport::Concern

  def within_usage_limit?
    usage_limit.nil? || used_count < usage_limit
  end

  # Takes one use if any is left. Returns whether it did.
  def claim_usage!
    claimed = change_used_count(1, 'usage_limit IS NULL OR used_count < usage_limit') == 1
    refresh_used_count
    claimed
  end

  # Gives back a use taken with claim_usage!.
  def release_usage!
    change_used_count(-1, 'used_count > 0')
    refresh_used_count
  end

  private

  # One conditional UPDATE. Skipping validations and callbacks is the point: the database checks
  # the condition and changes the count in the same statement. Returns the number of rows changed.
  def change_used_count(delta, condition)
    # rubocop:disable-next Rails/SkipsModelValidations
    self.class.where(id: id).where(condition)
        .update_all(['used_count = used_count + ?, updated_at = ?', delta, Time.current])
  end

  def refresh_used_count
    self[:used_count] = self.class.where(id: id).pick(:used_count)
    clear_attribute_changes([:used_count])
  end
end
