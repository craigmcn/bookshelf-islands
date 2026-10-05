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
- Catalog and shelf browsing both support a single `?tag=` filter shared across all three categories (tag names are unique, so no category qualifier is needed)

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

### Social (in progress)
`doc/feature_roadmap.md`'s Social category (#51-#56 here) is being ported in dependency order, one PR per step, since each piece depends on the last: (1) `Notification` model — done; (2) Follow + minimal profile page — done; (3) Activity feed — done, see below; (4) review likes/comments as React islands; (5) buddy reads; (6) book clubs with spoiler-gated posts. The original Notifications category (#62-#65, #84 — triggers + bell/inbox UI) resumes once this lands.

- `Follow` (`follower`/`followed`, both `User`) creates a `new_follower` `Notification` on create, destroyed along with it (`has_one :notification, as: :notifiable, dependent: :destroy`) — `User#following?`/`#followers`/`#following` read through `active_follows`/`passive_follows`. Deleting either side of a follow relationship cascades cleanly through `dependent: :destroy` all the way to the notification, with no special-casing needed in `delete_account!` (verified empirically — see the corrected community_bookshelf#191).
- `User#favorite_genre_list` mirrors `Book#tag_list`'s virtual-attribute pattern exactly (comma-separated genre tag names, synced via `after_save`), reusing the same `Tag` model (category `genre`).
- `ProfilesController#show` (`/users/:id`) is a minimal port: bio/avatar/favorite genres, finished/currently-reading counts, up to 5 public reviews, a follow/unfollow button, and followers/following tabs. Deliberately omits `current_streak`/`badges`/`current_year_challenge` — Gamification roadmap category, not ported here. `User.excluding_deleted_placeholder` keeps the placeholder account's profile a 404.
- `Activity` (feed entries: `added_book`/`started_reading`/`finished_reading`/`reviewed`) is created by `Reading`'s own callbacks (`after_create`/`after_update`), not a separate service — `GET /feed` (`ActivitiesController`) shows `Activity.where(user: current_user.following)`. Omits the reference implementation's `skip_activity_logging` flag (used there to suppress entries during bulk import) since Import/export isn't ported here yet — add it back if/when that lands. `app/views/shared/_pagy_nav.html.erb` + the `pagination-nav` Stimulus controller (plain JS, no React — it only ever hides/shows existing server-rendered links on overflow, never builds hrefs in JS) are shared pagination UI, first used here.

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

namespace :admin
  /admin/dashboard       AdminDashboardController     (moderator+)
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

Existing islands: `BookSearch` (search-and-select, syncs hidden fields), `RatingPicker` (star picker, syncs a hidden field), `DeleteReadingControl` (admin moderation table — confirm + fetch DELETE + optimistic row fade, no hidden fields involved).

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
