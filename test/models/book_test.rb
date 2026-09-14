require "test_helper"

class BookTest < ActiveSupport::TestCase
  test "valid with title, author, and added_by" do
    assert Book.new(title: "Test", author: "Author", added_by: users(:member)).valid?
  end

  test "invalid without title" do
    assert_not Book.new(author: "Author", added_by: users(:member)).valid?
  end

  test "invalid without author" do
    assert_not Book.new(title: "Test", added_by: users(:member)).valid?
  end

  test "assigning tag_list creates and links tags, normalizing names" do
    book = Book.create!(title: "Test", author: "Author", added_by: users(:member))
    book.update!(tag_list: " Fantasy, coming-of-age , fantasy ")

    assert_equal ["coming-of-age", "fantasy"], book.tags.order(:name).pluck(:name)
  end

  test "assigning tag_list reuses existing tags instead of duplicating them" do
    book = Book.create!(title: "Test", author: "Author", added_by: users(:member))

    assert_no_difference "Tag.count" do
      book.update!(tag_list: tags(:one).name)
    end
    assert_equal [tags(:one)], book.tags
  end

  test "assigning an empty tag_list clears existing tags" do
    book = books(:one) # already tagged with tags(:one) via the taggings fixture
    book.update!(tag_list: "")

    assert_empty book.tags
  end

  test "not assigning tag_list on update leaves existing tags untouched" do
    book = books(:one) # already tagged with tags(:one) via the taggings fixture
    book.update!(title: "New Title")

    assert_equal [tags(:one)], book.reload.tags
  end

  test "tag_list reader returns comma-separated tag names when not assigned" do
    book = books(:one) # already tagged with tags(:one) via the taggings fixture
    assert_equal "fantasy", book.reload.tag_list
  end

  test "assigning mood_list creates and links mood tags separately from genres" do
    book = books(:one) # already tagged with tags(:one) (genre: fantasy) via the taggings fixture
    book.update!(mood_list: "dark, hopeful")

    assert_equal ["fantasy"], book.tags.genre.pluck(:name)
    assert_equal ["dark", "hopeful"], book.tags.mood.order(:name).pluck(:name)
  end

  test "assigning pace_list creates and links pace tags separately from genres and moods" do
    book = books(:one)
    book.update!(mood_list: "dark", pace_list: "fast-paced")

    assert_equal ["dark"], book.tags.mood.pluck(:name)
    assert_equal ["fast-paced"], book.tags.pace.pluck(:name)
  end

  test "mood_list reader returns comma-separated mood tag names when not assigned" do
    book = books(:one)
    book.update!(mood_list: "dark")

    assert_equal "dark", book.reload.mood_list
  end

  test "similar_books returns books sharing a tag, most-overlap first, excluding itself" do
    shared_tag = tags(:one) # genre: fantasy, already on books(:one)
    other_book = Book.create!(title: "Other Fantasy", author: "A. Uthor", added_by: users(:member))
    other_book.taggings.create!(tag: shared_tag)
    unrelated_book = Book.create!(title: "Unrelated", author: "B. Uthor", added_by: users(:member))

    similar = books(:one).similar_books

    assert_includes similar, other_book
    assert_not_includes similar, unrelated_book
    assert_not_includes similar, books(:one)
  end

  test "similar_books returns none when the book has no tags" do
    untagged = Book.create!(title: "Untagged", author: "A. Uthor", added_by: users(:member))
    assert_empty untagged.similar_books
  end

  test "recommended_for suggests books tagged like ones the user rated highly, excluding shelved books" do
    # reading(:one) rates books(:one) (tagged fantasy) a 4, which counts as "liked"
    recommended = Book.create!(title: "Recommended Fantasy", author: "A. Uthor", added_by: users(:admin), tag_list: "fantasy")

    assert_includes Book.recommended_for(users(:member)), recommended
    assert_not_includes Book.recommended_for(users(:member)), books(:one)
  end

  test "recommended_for returns none for a nil user" do
    assert_empty Book.recommended_for(nil)
  end

  test "recommended_for ignores a soft-deleted reading as a seed" do
    user = users(:member)
    reading = readings(:one)
    reading.update!(status: :finished)
    reading.soft_delete

    would_be_recommended = Book.create!(title: "Would Be Recommended", author: "A. Uthor", added_by: user, tag_list: "fantasy")

    assert_not_includes Book.recommended_for(user), would_be_recommended
  end
end
