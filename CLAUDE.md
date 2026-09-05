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
- **books** — `title`, `author`, `cover_url`, `added_by_id` (FK → users)
- **readings** — `user_id`, `book_id`, `status` (enum), `rating` (enum), `review`, `deleted_at` (soft delete)
- **users** — Clearance authentication (email, encrypted_password, tokens)
- **roles** — `name`: `member | moderator | admin`
- **role_assignments** — join table users ↔ roles (users can hold multiple roles)

### Enums
```ruby
# Reading#status
want_to_read: 0, reading: 1, finished: 2

# Reading#rating
one: 1, two: 2, three: 3, four: 4, five: 5
```

### Soft Deletes
Readings use `deleted_at` for soft deletes. Default scopes exclude deleted records; use `Reading.unscoped` or `with_deleted` if you need them.

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

GET  /book_search        BookSearchController#index   (Turbo Frame search)

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
`OpenLibraryService.search(query)` returns an array of hashes with `:title`, `:author`, `:cover_url`. `BookSearchController#index` (`/book_search.json`) serves results as JSON, consumed directly by the React `BookSearch` component (`app/javascript/components/BookSearch.tsx`), which debounces input at 300ms client-side.

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

Note: `config/database.yml` still names the test/dev/prod databases
`community_bookshelf_*` (inherited from the fork) — this repo and `community_bookshelf`
share the same local Postgres databases, so don't run both repos' `bin/e2e_server` at
the same time locally.

**Known gap:** `RatingPicker` renders into an empty `<div>` with a hidden field that
only gets a value once React mounts — unlike `community_bookshelf`'s native `<select>`,
a reading's rating can't be set if JS fails to load. Not yet fixed.
