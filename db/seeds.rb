# Roles
admin_role = Role.find_or_create_by!(name: "admin")
moderator_role = Role.find_or_create_by!(name: "moderator")
member_role = Role.find_or_create_by!(name: "member")

# Users
# ported from community_bookshelf db/seeds.rb (seed_user, skip_confirmation_email)
def seed_user(email)
  User.find_or_create_by!(email: email) do |u|
    u.password = User::DEFAULT_PASSWORD
    u.email_confirmed_at = Time.current
    u.skip_confirmation_email = true
  end
end

# Admins and moderators always have member permissions without requiring a member role assignment.
admin_user = seed_user("admin@communitybookshelf.org")
admin_user.roles = [admin_role, moderator_role]

mod_user = seed_user("moderator@communitybookshelf.org")
mod_user.roles = [moderator_role]

member1 = seed_user("alice@example.com")
member1.roles = [member_role]

member2 = seed_user("bob@example.com")
member2.roles = [member_role]

member3 = seed_user("carol@example.com")
member3.roles = [member_role]

all_users = [admin_user, mod_user, member1, member2, member3]

# Books
books = [
  {title: "The Great Gatsby", author: "F. Scott Fitzgerald", cover_url: "https://covers.openlibrary.org/b/id/10590366-M.jpg", tag_list: "classic, literary fiction"},
  {title: "To Kill a Mockingbird", author: "Harper Lee", cover_url: "https://covers.openlibrary.org/b/id/14351077-M.jpg", tag_list: "classic, literary fiction"},
  {title: "1984", author: "George Orwell", cover_url: "https://covers.openlibrary.org/b/id/9267242-M.jpg", tag_list: "classic, dystopian, sci-fi"},
  {title: "Pride and Prejudice", author: "Jane Austen", cover_url: "https://covers.openlibrary.org/b/id/14348537-M.jpg", tag_list: "classic, romance"},
  {title: "The Catcher in the Rye", author: "J.D. Salinger", tag_list: "classic, literary fiction"},
  {title: "Brave New World", author: "Aldous Huxley", tag_list: "classic, dystopian, sci-fi"},
  {title: "The Road", author: "Cormac McCarthy", tag_list: "literary fiction, post-apocalyptic"}
]

books.each_with_index do |attrs, i|
  book = Book.find_or_create_by!(title: attrs[:title]) do |b|
    b.author = attrs[:author]
    b.added_by = all_users[i % all_users.size]
  end
  book.update!(cover_url: attrs[:cover_url]) if attrs[:cover_url]
  book.update!(tag_list: attrs[:tag_list])
end

# Readings
statuses = Reading.statuses.keys
ratings = Reading.ratings.keys

Book.find_each do |book|
  all_users.each do |user|
    next if rand < 0.4  # not every user reads every book

    status = statuses.sample
    Reading.find_or_create_by!(user: user, book: book) do |r|
      r.status = status
      r.rating = ratings.sample if status == "finished"
    end
  end
end
