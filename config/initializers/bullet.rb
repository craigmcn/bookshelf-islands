# ported from community_bookshelf config/initializers/bullet.rb
if Rails.env.local?
  Rails.application.config.after_initialize do
    Bullet.enable = true
    Bullet.bullet_logger = true

    if Rails.env.development?
      Bullet.alert = true
      Bullet.console = true
      Bullet.rails_logger = true
      Bullet.add_footer = true
    end

    if Rails.env.test?
      Bullet.raise = true
    end

    # SeriesController#index eager-loads :books for each series' book count. With
    # only a couple of fixture rows, Bullet sees too few records to justify it and
    # flags it as unused, though it's needed once a series has real books.
    Bullet.add_safelist type: :unused_eager_loading, class_name: "Series", association: :books

    # ShelvesController#index eager-loads :shelf_books for each shelf's book count;
    # same low-fixture-count false positive as Series above.
    Bullet.add_safelist type: :unused_eager_loading, class_name: "Shelf", association: :shelf_books

    # The inbox and bell eager-load :notifiable for #message, which only reads it for
    # non-follower types, so an all-new_follower page looks like an unused include.
    Bullet.add_safelist type: :unused_eager_loading, class_name: "Notification", association: :notifiable
  end
end
