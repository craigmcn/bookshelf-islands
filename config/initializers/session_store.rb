# Be sure to restart your server when you modify this file.

# ported from community_bookshelf config/initializers/session_store.rb
# Tied directly to config.force_ssl (set per-environment in
# config/environments/*.rb, already resolved by the time this initializer
# runs) rather than re-derived from Rails.env — so secure: can't drift out
# of sync with the actual SSL enforcement if force_ssl is ever toggled.
Rails.application.config.session_store :cookie_store,
  key: "_bookshelf_islands_session",
  secure: Rails.application.config.force_ssl,
  same_site: :lax
