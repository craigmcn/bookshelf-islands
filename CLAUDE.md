# Community Bookshelf

A Rails 8 community reading-list app where members track books, log readings, and write reviews. Moderators/admins manage content via a scoped admin dashboard.

## Project Goal

This started as a React-islands architecture demo — a Rails 8 + Hotwire/Stimulus port of `community_bookshelf` with select interactive widgets reimplemented as React islands. The goal has since expanded: **bookshelf-islands is working toward full feature parity with `community_bookshelf`, so it can serve as a drop-in replacement for a running `community_bookshelf` instance.**

`community_bookshelf` is the feature-complete reference implementation. Its full roadmap (`doc/feature_roadmap.md` there) and hardening/accessibility/observability work (see its GitHub issue tracker) define the target state here. GitHub Project #18 (`bookshelf-islands Roadmap`) tracks the outstanding gap, issue-for-issue against `community_bookshelf`'s closed issues.

**Porting approach:** where practical, copy code/files directly from `community_bookshelf` rather than reimplementing from scratch, and add a short comment noting the source (e.g. `# ported from community_bookshelf app/models/tag.rb`) so the two repos can be kept in sync as `community_bookshelf` evolves. The React-islands pattern (below) still applies to new self-contained interactive widgets, but is no longer the organizing constraint for the whole app — most of `community_bookshelf`'s remaining surface (models, controllers, Hotwire/Turbo views) should be ported as-is.

## Tech Stack

- **Ruby** 4.0.5 / **Rails** 8.1.3
- **Database**: PostgreSQL
- **Authentication**: Clearance gem
- **Authorization**: Pundit (policy classes)
- **Frontend**: Hotwire (Turbo + Stimulus), Bootstrap 5, esbuild + Sass via propshaft
- **External API**: Open Library (book search + cover images via Faraday)
- **Background jobs / Cache**: solid_queue, solid_cache (DB-backed)
- **Testing**: Minitest + Capybara (system tests); Playwright for cross-app e2e parity checks (see below)
- **N+1 detection**: `bullet` in development and test (`config/initializers/bullet.rb`, ported from community_bookshelf). It raises in test, so controller tests and the e2e suite (also `RAILS_ENV=test`) fail on an N+1 or unused eager load. Safelisted: `Series#books`, `Shelf#shelf_books` (low fixture counts), and `Notification#notifiable` (an all-follower page doesn't dereference it).
- **CI**: GitHub Actions (Brakeman, bundler-audit, StandardRB, full test suite vs PostgreSQL, Playwright e2e)
- **Deployment**: Docker + Kamal + Thruster

## Setup

```sh
bin/setup          # install deps, create/migrate DB, seed
bin/dev            # start web + esbuild watch + CSS watch (via Procfile.dev)
```

## Common Commands

```sh
bin/rails test                          # full test suite
bin/rails test test/models/user_test.rb # single file
bin/rails test:system                   # Capybara system tests

bin/rails routes                        # list all routes
bin/rails db:migrate                    # run pending migrations
bin/rails db:rollback                   # undo last migration
bin/rails db:seed                       # seed roles + users

bin/rubocop                             # lint (StandardRB via standard + standard-rails)
bin/rubocop -a                          # auto-correct safe offenses
bin/rubocop -A                          # auto-correct all offenses (includes unsafe)
bundle exec brakeman                    # security scan

yarn build                              # compile JS
yarn build:css                          # compile Sass

yarn test:e2e                           # Playwright e2e (starts its own server, see below)
```

## Domain Model

### Core Tables
- **books** — `title`, `author`, `cover_url`, `added_by_id` (FK → users), `isbn`, `page_count`, `published_on`, `description`, `subjects` (array), `series_id` (FK → series, optional), `series_position`
- **series** — `name` (unique); a book's `series_position` is cleared automatically if its `series_id` is blank
- **readings** — `user_id`, `book_id`, `status` (enum), `rating` (enum), `review`, `is_review_public`, `format` (enum), `started_on`, `finished_on`, `progress_percent`, `deleted_at` (soft delete)
- **users** — Clearance authentication (email, encrypted_password, tokens), plus `name`, `bio`, `email_confirmed_at`, `email_confirmation_token`, `email_confirmation_sent_at`; `has_one_attached :avatar` (Active Storage)
- **roles** — `name`: `member | moderator | admin`
- **role_assignments** — join table users ↔ roles (users can hold multiple roles)

### Enums
```ruby
# Reading#status
want_to_read: 0, reading: 1, finished: 2, dnf: 3

# Reading#rating
one: 1, two: 2, three: 3, four: 4, five: 5

# Reading#format
physical: 0, ebook: 1, audiobook: 2
```

### Soft Deletes
Readings use `deleted_at` for soft deletes. Default scopes exclude deleted records; use `Reading.unscoped` or `with_deleted` if you need them.

### Tags
- **tags** — `name` (unique across all categories), `category` (`genre | mood | pace`, default `genre`)
- **taggings** — join table books ↔ tags
- `Book#tag_list` / `#mood_list` / `#pace_list` — comma-separated virtual attributes, one per category, backing the `TagInput` island on the book form
- `Book#similar_books` — books sharing the most tags (any category), most-overlap first
- `Book.recommended_for(user)` — books tagged like ones the user rated 4-5★ or finished, excluding already-shelved books (tag-overlap only, no ML/vector infra); shown as "Recommended for You" on My Shelf
- Catalog and shelf browsing both support a single `?tag=` filter shared across all three categories (tag names are unique, so no category qualifier is needed). Tag chips in `CatalogBrowser`/`ShelfBrowser` are real `<a href>` links that navigate (community_bookshelf#224 #12), not in-place buttons — the island re-hydrates from the URL params

### Cataloging & Metadata
- `isbn`, `page_count`, `published_on` are plain fields on the book form (like `format`/dates on `Reading`, no island needed); catalog sort gains a `published` option ordering by `published_on` desc
- Series are their own resource (`resources :series`, moderator+ to create/edit/destroy, public to browse) — a book optionally belongs to one via `series_id`/`series_position`; a series' show page lists its books ordered by position
- `Book#open_library_key` is a transient (non-persisted) attribute carrying the selected Open Library search result's work key from the form through to `#create`, which calls `OpenLibraryService.work_detail(key)` to backfill `description`/`subjects` before saving — it round-trips through a failed create/re-render like any other form field
- The `BookSearch` island's selection now carries `openLibraryKey` alongside title/author/cover, synced to a hidden field the same way as the others

### Account & Profile
- `User#display_name` falls back to `email` when `name` is blank — used everywhere a user's contributions are attributed (book cards, book show, community readings, navbar); admin views still show `.email` directly since admins need the real account identity
- Self-service profile edit/avatar upload/account deletion live under `resource :account` (`AccountsController#edit/update/destroy`, `app/views/accounts/edit.html.erb`) — plain form fields and a native file input, no React island
- Avatar: `has_one_attached :avatar` (Active Storage, local disk service in dev/test/production — see `config/storage.yml`), validated for size (`User::MAX_AVATAR_BYTES`, 5MB) and content type (`User::ALLOWED_AVATAR_TYPES`: PNG/JPEG/WEBP) in `avatar_is_a_supported_image_under_the_size_limit`; rendered directly with `image_tag`, no variants/processing
- `User#delete_account!` reassigns the user's catalog books to a shared placeholder account (`User.deleted_placeholder`, memoized by a well-known email) so the catalog survives, explicitly destroys their soft-deleted readings first (the default scope would otherwise hide them from `dependent: :destroy` and leave a dangling FK), then destroys the user; raises `User::SoleAdminError` if the user is `sole_admin?` (the last admin — deleting would lock every `/admin` route)
- Email confirmation is informational-only, not enforced: `send_email_confirmation` (fired `after_create` unless `skip_confirmation_email`, set by seeds/the deleted placeholder) emails a `confirm_email/:token` link via `UserMailer`; `EmailConfirmationsController#create` resends with a 1-minute cooldown (`User::RESEND_COOLDOWN`)

### Social (done)
`doc/feature_roadmap.md`'s Social category (#51-#56 here) was ported in dependency order, one PR per step, since each piece depended on the last: (1) `Notification` model; (2) Follow + minimal profile page; (3) Activity feed; (4) review likes/comments as React islands; (5) buddy reads; (6) book clubs with spoiler-gated posts. The Notifications category (community_bookshelf#65-#68 — triggers + bell/inbox UI/digest emails) was ported next, see below.

- `Follow` (`follower`/`followed`, both `User`) creates a `new_follower` `Notification` on create, destroyed along with it (`has_one :notification, as: :notifiable, dependent: :destroy`) — `User#following?`/`#followers`/`#following` read through `active_follows`/`passive_follows`. Deleting either side of a follow relationship cascades cleanly through `dependent: :destroy` all the way to the notification, with no special-casing needed in `delete_account!` (verified empirically — see the corrected community_bookshelf#191).
- `User#favorite_genre_list` mirrors `Book#tag_list`'s virtual-attribute pattern exactly (comma-separated genre tag names, synced via `after_save`), reusing the same `Tag` model (category `genre`).
- `ProfilesController#show` (`/users/:id`) is a minimal port: bio/avatar/favorite genres, finished/currently-reading counts, up to 5 public reviews, a follow/unfollow button, and followers/following tabs. Deliberately omits `current_streak`/`badges`/`current_year_challenge` — Gamification roadmap category, not ported here. `User.excluding_deleted_placeholder` keeps the placeholder account's profile a 404.
- `Activity` (feed entries: `added_book`/`started_reading`/`finished_reading`/`reviewed`) is created by `Reading`'s own callbacks (`after_create`/`after_update`), not a separate service — `GET /feed` (`ActivitiesController`) shows `Activity.where(user: current_user.following)`. Omits the reference implementation's `skip_activity_logging` flag (used there to suppress entries during bulk import) since Import/export isn't ported here yet — add it back if/when that lands. `app/views/shared/_pagy_nav.html.erb` + the `pagination-nav` Stimulus controller (plain JS, no React — it only ever hides/shows existing server-rendered links on overflow, never builds hrefs in JS) are shared pagination UI, first used here.
- `ReviewLike` (unique `[user_id, reading_id]`) and `ReviewComment` (`body`, max 1000 chars, triggers a `review_comment` `Notification` to the reading's owner unless commenting on your own review) are both reachable only through `ReviewLikePolicy`/`ReviewCommentPolicy`, which independently re-check `reading.is_review_public? && reading.review.present?` rather than trusting `ReadingPolicy#show?` — a moderator can view a private review's page but must not be able to like/comment on it as if it were public. Likes have no moderator override on destroy (only the liker can unlike); comments allow author-or-moderator delete, matching the general comment-moderation pattern. `Reading#soft_delete` explicitly destroys both before soft-deleting, since the default scope would otherwise hide the reading from their `dependent: :destroy`.
- Porting this required two small fixes to reach parity with the reference implementation, since nothing here could previously navigate to another user's reading at all: `ReadingPolicy#show?` gained the `is_review_public? && review.present?` clause (only the owner or a moderator could view a reading's show page before); and the Community Readings table on a book's show page now gates each review's visibility by privacy/ownership and links a public one to its reading page (it previously showed every review's text unconditionally, including private ones).
- `ReviewLikeButton` and `ReviewComments` are the first React islands with no Hotwire/Turbo equivalent to port from community_bookshelf (its own version is plain `button_to`/`form_with` round-trips) — `reading_review_like_path`/`reading_review_comments_path` respond `format.json` alongside `format.html` so a signed-in browser session can drive them (the token-scoped `Api::V1` endpoints require a bearer token). Mounted on `readings/show.html.erb`, bootstrapped from server-rendered `data-*-value` attributes the same way `RatingPicker`'s options are.
- `BuddyRead` (`book`, `initiator`/`partner`, both `User`, `status` enum `pending/accepted/declined/cancelled/completed`, default `pending`) is its own standalone entity, not a wrapper around `Reading` — each participant's own `Reading` still tracks their personal status/progress independently; a buddy read is purely a pairing/invite/chat layer alongside it. A DB check constraint (`initiator_id <> partner_id`) backs the model validation against self-pairing, matching `Follow`'s established belt-and-suspenders pattern. `BuddyReadPolicy`/`BuddyReadMessagePolicy` have no moderator override anywhere — deliberately a private two-person space, unlike reviews. `BuddyReadsController#update` is a fixed state machine driven by a `status` param (accept/decline only by the invited partner while pending; cancel by either participant while pending or accepted; complete by either while accepted) where an invalid transition is a silent no-op, not an error. `BuddyReadMessage#messageable?` stays true through `completed` — only `declined`/`cancelled` close the thread to new messages.
- Deliberate deviation from the reference implementation: `BuddyRead#create` fires a `buddy_read_invite` `Notification` to the invited partner. community_bookshelf itself never notifies on a buddy read invite at all — discoverable only by visiting `/buddy_reads` — which is inconsistent with how `Follow`/`ReviewComment` already use `Notification` there; filed as community_bookshelf#199 to bring the reference back in line rather than silently diverging. No React island here — like PRs 1-3, this is a plain Turbo/`button_to`/`form_with` port, since the reference has no JS for it either.
- `Club` centers on one `book` (not a general standing group) — creating one auto-joins the creator via an `after_create` callback (`ClubMembership`), so `club.members` is never empty. `ClubPolicy#index?`/`#show?` are open to any signed-in member (clubs are discoverable/joinable by anyone, unlike `BuddyRead`); `#update?`/`#destroy?` are creator-or-moderator, the same pattern as comment/post moderation elsewhere. `ClubPost` has no `update?`/edit at all — only create/destroy.
- Spoiler gating on `ClubPost#visible_to?(user, viewer_has_finished_book: nil)` is **status-based**, not page/chapter-based — a post flagged `spoiler` stays hidden from a member until they have a `Reading` with `status: finished` for the club's book (checked live via `Reading.exists?`, not cached on the membership). This was a deliberate scope decision in the reference implementation: `Reading` only has a status enum, no page/percent-threshold field fine-grained enough to gate per-chapter. The post's own author and moderators always see it regardless of their reading status. `ClubsController#show` precomputes `@viewer_has_finished_book` once and passes it into every post's `visible_to?` call, avoiding a `Reading.exists?` query per spoiler post on the page.
- `ClubPost#notify_other_members` fans out one `club_post` `Notification` per *other* club member (`find_each` over `club.members.where.not(id: user_id)`), not a single `has_one :notification` like `Follow`/`ReviewComment`/`BuddyRead` — a club post is visible to the whole membership, so everyone but the poster gets notified. `Notification`'s `club_post` enum value and `message`/`target_type`/`target_id` branches were already in place from the start of the Social port (see the model's top comment), so no changes to `Notification` itself were needed here.
- `ClubsController#index` computes member counts with one grouped `ClubMembership.where(club_id: ...).group(:club_id).count` query rather than `club.members.count` per row in the view — same N+1-avoidance pattern as the `@viewer_has_finished_book` precompute above.
- `User#delete_account!` reassigns `created_clubs` to the deleted-user placeholder, the same treatment as `books` — without it, `destroy!` would hit `ActiveRecord::InvalidForeignKey` via `clubs.created_by_id` for anyone who'd ever created a club. `User has_many :club_posts, dependent: :destroy` closes the same failure mode via `club_posts.user_id` for anyone who'd ever posted in one.
- No private/invite-only clubs, no club-level moderator role, no post editing, no "mute"/"remove member" — moderators can only delete clubs/posts outright, the same blunt-instrument moderation pattern used elsewhere in this app. No React island — pure ERB/Bootstrap `button_to`/`form_with`, matching the reference (which has no JS for this feature either).
- Deliberate deviation from the reference implementation: `Book has_many :clubs, dependent: :destroy`. community_bookshelf's own `Book` model has no `clubs` association at all, so destroying a book with a club there hits an uncaught `ActiveRecord::InvalidForeignKey` via `clubs.book_id` (`BooksController#destroy` uses `destroy!`) — the same class of latent crash as the account-deletion FK gap community_bookshelf fixed once (486eb89) but missed here. Closed proactively rather than reproduced; filed as community_bookshelf#200 to bring the reference back in line.

### Notifications (done)
`NotificationsController` (`index`/`update`/`mark_all_read`) has no Pundit policy — like `ActivitiesController` (`/feed`), it's inherently scoped via `current_user.notifications.find(...)`/`current_user.notifications...`, so a cross-user access attempt naturally 404s rather than needing an explicit authorization check. `NotificationsHelper#notification_path_for`/`#notification_url_for`/`#notification_icon_for` are the single source of per-`notification_type` routing/iconography (controller redirect, inbox view, mailer template all read through it), with a `buddy_read_invite` branch added alongside the three ported from community_bookshelf (`new_follower`/`review_comment`/`club_post`) since that type has no reference equivalent. Reading a notification (`PATCH /notifications/:id`) and digesting it (`digested_at`, set only by the nightly job) are fully independent timestamps — visiting the inbox or dropdown never sets `digested_at`, and a digest run never sets `read_at`, so a user who reads everything in-app before 8am still gets that morning's digest listing the same items (reference's own deliberate design, ported as-is).
- Deliberate deviation from the reference implementation: the navbar bell is a dropdown with the 5 most recent notifications (icon, message, relative time, read/unread shading) plus "mark all as read" and "view all", not community_bookshelf's plain link straight to `/notifications`. Still a fully server-rendered partial computed per-request in the layout (`unread_notifications_count`/`recent_notifications` locals) — no Turbo Frame/Stream/polling, so it still only updates on the next full-page load, same as the reference. Filed as community_bookshelf#201 to bring the reference forward to the same dropdown rather than silently diverging.
- `SendNotificationDigestsJob` (daily via `config/recurring.yml`, `solid_queue`) queries `Notification.not_yet_digested`, batches by recipient, and passes each batch's notification ids explicitly into `NotificationsMailer.digest(user, notification_ids)` rather than letting the mailer re-derive the same scope — `deliver_later` only enqueues the call, so by the time the queued mailer job actually runs, the job's own `update_all(digested_at: ...)` (issued right after enqueuing, not after delivery) has already run; a scope re-query at that point would find nothing and silently drop the email. `User.excluding_deleted_placeholder` keeps the digest job from ever emailing the synthetic deleted-account placeholder.
- `Notification.preload_notifiable_details` preloads the nested association each `#message` branch reaches for beyond `notifiable` itself (`reading.book` for `review_comment`, `club` for `club_post`, `book` for `buddy_read_invite`, `buddy_read.book` for `buddy_read_message`) — a polymorphic `includes(:notifiable)` can't preload these since the notifiable types don't share an association name, so `NotificationsController#index` and the navbar dropdown both run it once per request instead of N+1ing per row. Mirrors community_bookshelf#204, found there after its own bell-dropdown PR shipped the same gap.
- Deliberate deviation from the reference implementation: `BuddyReadMessage#create` fires a `buddy_read_message` `Notification` to the other participant. community_bookshelf never notifies on a new buddy read message at all (the same gap class as the invite notification, community_bookshelf#199) — tracked there as community_bookshelf#190.

### Gamification (done)
Three features ported together from one community_bookshelf commit, since `Badge` depends on both of the others: annual reading challenges, reading streaks, badges/achievements.
- `ReadingChallenge` (`user`, `year`, `goal`, unique per user+year) stores only the goal — progress (`books_finished_count`/`progress_percent`/`completed?`) is computed live from `Reading` rows every call, memoized only per-instance (not cached in the DB). `ReadingChallengePolicy`/`ReadingChallengesController` scope everything through `current_user.reading_challenges`, same 404-before-authorize pattern as other owner-only resources here; `year` is only accepted on create (split into separate create/update param methods) so it can't be changed after the fact via a crafted update.
- `User#current_streak` is **purely computed, no stored column, no callback** — consecutive finished books (most recent first) where each pair of finishes is no more than `User::STREAK_GAP_DAYS` (30) apart; a most-recent finish older than that itself means a streak of 0. Recomputed from `readings.finished.finished_on` on every call.
- `Badge` is **not an ActiveRecord model** — a plain Ruby class holding a frozen registry of `Definition` structs (books-finished/reviews-written/streak tiers, plus challenge-completed), each with a criteria lambda checked against a `User`. `UserBadge` is the only persisted badge record (`user`, `badge_key` unique per user, `awarded_at`), validated against `Badge.list`'s keys.
- `User#award_badges!` re-checks every `Badge` definition and creates any newly-qualifying `UserBadge` rows; badges are **permanent once earned** (nothing ever removes one, even if a streak later breaks). Triggered from `Reading#after_save` (finishing a book or adding a review) and `ReadingChallenge#after_save` — not a background job or schedule. A duplicate-insert race (two saves both passing the already-earned check before either commits) is rescued inside a `transaction(requires_new: true)` savepoint, so the rescued `RecordNotUnique` doesn't abort the outer save transaction `award_badges!` is running inside.
- Bug fix beyond the reference, found via a test the reference itself lacks (no community_bookshelf test asserts `challenge_completed` is actually awarded): the `challenge_completed` criteria must call `user.reading_challenges.reload`, not a bare `user.reading_challenges` — when triggered from a *brand-new* `ReadingChallenge`'s own `after_save`, Rails doesn't append that record to the owner's cached association target until after the whole create (and its callbacks) finishes, so an unreloaded read inside that same callback never sees the very challenge that just completed. Filed as community_bookshelf#206 and fixed there too, since the reference has the identical ported code and bug.
- No React island, no JSON API controller for `ReadingChallenge` — matches the reference (plain ERB/Bootstrap; bookshelf-islands has no JSON API namespace yet, a separate unstarted roadmap item).

### Stats & insights (done)
Both items (`[parity: solo]` in `doc/feature_roadmap.md` — net-new surface, not part of the shared Playwright e2e contract) are 100% live `ActiveRecord` queries; nothing is cached or persisted, no background job.
- `User#genre_breakdown`/`#books_finished_by_month`/`#pages_read_by_month` back the personal `/stats` page (`StatsController`, no Pundit policy — same `current_user`-only exemption as `ActivitiesController`/`NotificationsController`). Month-bucketing uses the `groupdate` gem (`group_by_month`), not hand-rolled SQL date truncation. "Pace" is simply **books finished per calendar month**, not pages/day or any other measure.
- Charts are rendered by the `chartkick` gem (paired with the `chartkick`/`chart.js` npm packages, wired into `app/javascript/application.js` as `window.Chartkick = Chartkick`) — a view calls `pie_chart`/`column_chart`/`line_chart` with a plain Ruby Hash, and chartkick's own bundled JS finds the generated chart divs and draws them with Chart.js on page load. No Stimulus controller, no React component — chartkick isn't app interaction logic, it's a rendering helper, so it doesn't fit the React-islands carve-out (closer in spirit to the `pagination-nav` Stimulus controller's plain-JS exemption than to `BookSearch`/`RatingPicker`).
- `Admin::DashboardController` gained three `group_by_month` trend queries (new users, books added, readings logged), rendered as three more `line_chart`s under a "Trends" heading — still gated by the dashboard's own `before_action :require_admin` (stricter than the rest of `/admin`, which is moderator+).
- Bug fix found and fixed along the way: `@total_users` on the admin dashboard was `User.count`, including the synthetic deleted-account placeholder — community_bookshelf's own `@total_users`/new-users trend both use `User.excluding_deleted_placeholder`, caught porting that controller's test verbatim (it asserts the placeholder is excluded) and fixed here to match.
- Also added two navbar links ("Reading Challenges", "My Stats") that should have landed with the Gamification PR but were missed — `/reading_challenges` was reachable only via the account page's "Manage" button until now.

## Authentication & Authorization

### Clearance
- `ApplicationController` includes `Clearance::Controller`
- Use `require_login` before_action to protect routes
- `current_user` is always available (nil if signed out)
- Test helper: `sign_in_as(user)` (defined in test_helper.rb)
- Test fixture password: `"correct-horse-shelf"` (all fixture users)

### Pundit
- `ApplicationController` includes `Pundit::Authorization` and calls `verify_authorized`
- One policy per model in `app/policies/` — all default to `false`
- Roles checked via `current_user.member?`, `.moderator?`, `.admin?`, `.moderator_or_above?`
- Pundit errors are rescued in ApplicationController (renders 403)

### Role Hierarchy
```
admin > moderator > member (default for new users)
```
Users can hold multiple roles simultaneously. Helper methods on User:
- `member?` / `moderator?` / `admin?` — checks for that specific role
- `moderator_or_above?` — moderator OR admin

## Routes

```
GET  /books              BooksController#index       (public)
GET  /books/:id          BooksController#show        (public)
POST /books              BooksController#create      (member+)
PATCH /books/:id         BooksController#update      (moderator+)
DELETE /books/:id        BooksController#destroy     (moderator+)

resources :readings      ReadingsController           (owner or moderator+)
resources :series        SeriesController             (public read, moderator+ write)

resource :account        AccountsController           (edit/update/destroy own account)
resource :email_confirmation  EmailConfirmationsController#create (resend)
GET  /confirm_email/:token    EmailConfirmationsController#confirm

GET  /users/:id          ProfilesController#show      (any signed-in user)
GET  /users/:id/followers, /following  ProfilesController#followers/#following
POST/DELETE /users/:user_id/follow     FollowsController#create/#destroy

GET  /book_search        BookSearchController#index   (Turbo Frame search)
GET  /feed               ActivitiesController#index   (signed-in users; followed users' reading activity)

resources :buddy_reads   BuddyReadsController         (index/new/create/show/update; participants only)
  resources :messages    BuddyReadMessagesController#create (path: buddy_reads/:buddy_read_id/messages)

resources :clubs         ClubsController              (any signed-in user; update/destroy creator-or-moderator)
  resource :membership   ClubMembershipsController#create/#destroy (path: clubs/:club_id/membership)
  resources :posts       ClubPostsController#create/#destroy (path: clubs/:club_id/posts)

resources :reading_challenges  ReadingChallengesController (index/new/create/edit/update; owner only)
resource :stats          StatsController#show         (signed-in users; own stats only)

namespace :admin
  /admin/dashboard       Admin::DashboardController   (admin only)
  /admin/readings        AdminReadingsController      (moderator+)
  /admin/users           AdminUsersController         (admin only)
```

## Testing Conventions

- **Framework**: Minitest (test/unit style, not RSpec)
- **Fixtures** over factories — all fixtures in `test/fixtures/`
- **Parallel** test execution (parallel workers = CPU count)
- Controller tests use `sign_in_as(users(:member))` / `sign_in_as(users(:admin))`
- Always test the three permission tiers: unauthenticated, member, moderator/admin
- System tests use Capybara + Selenium

### Fixture Users
| Fixture | Role | Password |
|---|---|---|
| `users(:member)` | member | correct-horse-shelf |
| `users(:moderator)` | moderator | correct-horse-shelf |
| `users(:admin)` | admin | correct-horse-shelf |

## Key Patterns

### Adding a new policy check
1. Add method to `app/policies/<model>_policy.rb`
2. Call `authorize @record` (or `authorize @record, :custom_action?`) in controller
3. Add fixture-based tests in `test/controllers/<model>s_controller_test.rb`

### Admin-only features
Inherit from `Admin::BaseController` — it enforces `moderator_or_above?` and provides `require_admin!`.

### Open Library integration
`OpenLibraryService.search(query)` returns an array of hashes with `:title`, `:author`, `:cover_url`, `:open_library_key`. `BookSearchController#index` (`/book_search.json`) serves results as JSON, consumed directly by the React `BookSearch` component (`app/javascript/components/BookSearch.tsx`), which debounces input at 300ms client-side. `OpenLibraryService.work_detail(key)` fetches a work's `description`/`subjects` (capped at `MAX_SUBJECTS`) for `BooksController#create` to backfill once a book is selected.

### React islands
For page-level navigation, default to out-of-the-box Rails + Hotwire/Stimulus, with React reserved for self-contained interaction islands — Stimulus is used only as a thin mount/bridge, never for the interaction logic itself. This pattern still governs any *new* interactive widget; it isn't a constraint on porting the rest of `community_bookshelf`'s Hotwire/Turbo views as-is (see Project Goal above). Pattern (see `book_search_controller.tsx` + `BookSearch.tsx`):
1. A Stimulus controller (`app/javascript/controllers/<name>_controller.tsx`) targets a mount `<div>` and any hidden form fields or DOM side effects it needs to handle.
2. `connect()` creates a React root on the mount target and renders the component; `disconnect()` unmounts it.
3. The React component owns all interaction state; it reports changes back via a callback prop (e.g. `onChange`, `onDeleted`), which the Stimulus controller uses to write hidden form fields or make a DOM change outside the React tree (e.g. fading the containing table row).
4. The component talks to Rails via a JSON endpoint (e.g. `/book_search.json`, or an existing HTML endpoint that also responds to `format.json`) rather than Turbo Frames/Streams.

Existing islands: `BookSearch` (search-and-select, syncs hidden fields), `RatingPicker` (star picker, syncs a hidden field), `DeleteReadingControl` (inline Yes/Cancel confirm + fetch DELETE, no hidden fields involved — used by the admin moderation table, which fades the row, and by the `ShelfBrowser` shelf row as an icon-only "Remove reading" control via `iconLabel`, which drops the row and shows a "Reading was removed." alert). `ReadingPolicy#destroy?` is owner-or-moderator (community_bookshelf#238); there's no audit log here yet (#76), so CB's "audit only when deleting someone else's reading" rule has nothing to port into.

### Asset builds
Changes to JS or CSS require `yarn build` / `yarn build:css` (or keep `bin/dev` running). Compiled output lands in `app/assets/builds/`.

## Playwright e2e (cross-app parity)

`yarn test:e2e` runs the Playwright suite in `e2e/`. `playwright.config.ts`'s `webServer`
boots `bin/e2e_server`, which builds JS/CSS, resets the test DB (`db:test:prepare
db:fixtures:load`), backfills `remember_token` for fixture users (fixtures skip AR
callbacks, so Clearance's `before_create` token generator never runs — without this,
a real browser sign-in can never authenticate), and starts Rails on port 3000 in
`RAILS_ENV=test` with `OPEN_LIBRARY_STUB=1`. That env var makes
`config/initializers/open_library_stub.rb` register a WebMock stub for
`openlibrary.org/search.json` so book search doesn't depend on the live API.

These specs are one half of a shared parity contract also implemented in
`community_bookshelf` (same scenarios, Turbo Frame/native-select UI instead of React
islands) and, against a real backend, in `bookshelf-spa`/`bookshelf-api`. Same fixture
data across all four repos (`member@example.com` / `moderator@example.com` /
`admin@example.com`, password `correct-horse-shelf`, books "The Great Gatsby"/"1984") —
keep spec *outcomes* aligned across repos when adding new scenarios here. The
`RatingPicker` island is driven via its `role="group"` star buttons (e.g. `getByRole("group",
{ name: "Rating" }).getByRole("button", { name: "Five" })`) rather than `selectOption`.

Runs single-worker/serial (tests mutate a shared Postgres DB, unlike Minitest's
per-test fixtures — there's no transaction rollback between Playwright tests). Tests
that change fixture-owned state revert it before finishing (see the role-edit test in
`e2e/admin.spec.ts`) so re-running the suite against the same DB stays idempotent.
Multi-user scenarios get a second signed-in page from the `pageAs(user)` fixture
(`e2e/support/fixtures.ts`, ported from community_bookshelf#236), which closes its
contexts at teardown — import `test`/`expect` from there, not `browser.newContext()`.
There's no `shelf_books` fixture here (community_bookshelf seeds The Great Gatsby on
Favorites; aligning seeds/fixtures is #124), so list specs add the book themselves.
Because e2e shares the test DB, a later `bin/rails test` can fail fixture loading with
an `activities` FK violation from e2e-created rows — `bin/rails db:test:prepare` clears it.

`config/database.yml`'s dev/test databases are named `bookshelf_islands_*` — separate
from `community_bookshelf`'s own `community_bookshelf_*` databases on the same local
Postgres server. They were briefly named `community_bookshelf_*` (inherited from the
fork) until 2026-09-06, when running `bin/rails test` here was found to wipe
`community_bookshelf_test` via `maintain_test_schema!` (it reset the shared database to
this repo's much smaller schema). Production still targets `community_bookshelf_production`
deliberately — the drop-in-replacement goal means eventually deploying against the same
production data, not a copy of it.

**Known gap:** `RatingPicker` renders into an empty `<div>` with a hidden field that
only gets a value once React mounts — unlike `community_bookshelf`'s native `<select>`,
a reading's rating can't be set if JS fails to load. Not yet fixed.
