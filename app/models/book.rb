class Book < ApplicationRecord
  belongs_to :added_by, class_name: "User"
  belongs_to :series, optional: true
  has_many :readings, dependent: :destroy
  has_many :taggings, dependent: :destroy
  has_many :tags, through: :taggings

  # Transient — carries the selected Open Library search result's work key from
  # the form through to #create, where it's used to fetch description/subjects.
  # Not persisted, so it round-trips through a failed save/re-render like any
  # other form field.
  # ported from community_bookshelf app/models/book.rb (open_library_key)
  attr_accessor :open_library_key

  validates :title, :author, presence: true
  # ported from community_bookshelf app/models/book.rb (page_count validation)
  validates :page_count, numericality: {only_integer: true, greater_than: 0}, allow_nil: true

  before_validation :clear_series_position_without_series
  after_save :sync_tag_list, if: -> { !@tag_list.nil? }
  after_save :sync_mood_list, if: -> { !@mood_list.nil? }
  after_save :sync_pace_list, if: -> { !@pace_list.nil? }

  # Virtual attributes: comma-separated strings of tag names, one per Tag
  # category, used by the book form instead of exposing the tags association
  # directly. Each only touches taggings for its own category when explicitly
  # assigned, so an update that omits it leaves that category's existing tags alone.
  # ported from community_bookshelf app/models/book.rb (tag_list/mood_list/pace_list + sync_*)
  attr_writer :tag_list, :mood_list, :pace_list

  def tag_list
    @tag_list || tags.genre.order(:name).pluck(:name).join(", ")
  end

  def mood_list
    @mood_list || tags.mood.order(:name).pluck(:name).join(", ")
  end

  def pace_list
    @pace_list || tags.pace.order(:name).pluck(:name).join(", ")
  end

  # Books sharing the most tags (any category) with this one, most-overlap first.
  # ported from community_bookshelf app/models/book.rb (similar_books)
  def similar_books(limit: 6)
    tag_ids = tags.ids
    return Book.none if tag_ids.empty?

    Book.includes(:added_by)
      .joins(:taggings)
      .where(taggings: {tag_id: tag_ids})
      .where.not(id: id)
      .group("books.id")
      .order(Arel.sql("COUNT(taggings.id) DESC"), "books.title ASC")
      .limit(limit)
  end

  # Books tagged like the ones a user rated highly or finished, excluding books
  # already on their shelf. Purely tag-overlap based — no ML/vector infra.
  # ported from community_bookshelf app/models/book.rb (recommended_for)
  def self.recommended_for(user, limit: 6)
    return none unless user

    user_readings = Reading.where(user_id: user.id)
    liked_book_ids = user_readings
      .where(status: :finished)
      .or(user_readings.where(rating: [:four, :five]))
      .distinct.pluck(:book_id)
    return none if liked_book_ids.empty?

    tag_ids = Tagging.where(book_id: liked_book_ids).distinct.pluck(:tag_id)
    return none if tag_ids.empty?

    shelved_book_ids = user_readings.distinct.pluck(:book_id)

    includes(:added_by)
      .joins(:taggings)
      .where(taggings: {tag_id: tag_ids})
      .where.not(id: shelved_book_ids)
      .group("books.id")
      .order(Arel.sql("COUNT(taggings.id) DESC"), "books.title ASC")
      .limit(limit)
  end

  private

  def sync_mood_list
    sync_tags_for_category("mood", @mood_list)
    @mood_list = nil
  end

  def sync_pace_list
    sync_tags_for_category("pace", @pace_list)
    @pace_list = nil
  end

  def sync_tag_list
    sync_tags_for_category("genre", @tag_list)
    @tag_list = nil
  end

  def sync_tags_for_category(category, raw_list)
    names = raw_list.to_s.split(",").filter_map { |name| name.strip.downcase.presence }.uniq
    desired_ids = names.map { |name| find_or_create_tag(name, category).id }
    current_ids = tags.where(category: category).pluck(:id)

    taggings.where(tag_id: current_ids - desired_ids).destroy_all
    (desired_ids - current_ids).each { |tag_id| taggings.create!(tag_id: tag_id) }
  end

  # find_or_create_by finds first, so it's correct for the common case where the
  # tag already exists. Under concurrent writes two requests can both miss that
  # find and race on the unique index; the rescue handles that without regressing
  # to create_or_find_by's behavior, which returns an invalid, unsaved record
  # (not the existing one) when Tag's own uniqueness validation — not a DB
  # conflict — is what catches the duplicate.
  def find_or_create_tag(name, category)
    Tag.find_or_create_by(name: name) { |tag| tag.category = category }
  rescue ActiveRecord::RecordNotUnique
    Tag.find_by!(name: name)
  end

  # ported from community_bookshelf app/models/book.rb (clear_series_position_without_series)
  def clear_series_position_without_series
    self.series_position = nil if series_id.blank?
  end
end
