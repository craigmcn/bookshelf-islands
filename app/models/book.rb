class Book < ApplicationRecord
  belongs_to :added_by, class_name: "User"
  has_many :readings, dependent: :destroy
  has_many :taggings, dependent: :destroy
  has_many :tags, through: :taggings

  validates :title, :author, presence: true

  after_save :sync_tag_list, if: -> { !@tag_list.nil? }

  # Virtual attribute: a comma-separated string of genre tag names, used by the
  # book form instead of exposing the tags association directly. Only touches
  # taggings when explicitly assigned, so an update that omits it leaves the
  # book's existing tags alone.
  # ported from community_bookshelf app/models/book.rb (tag_list + sync_tag_list)
  attr_writer :tag_list

  def tag_list
    @tag_list || tags.genre.order(:name).pluck(:name).join(", ")
  end

  private

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
end
