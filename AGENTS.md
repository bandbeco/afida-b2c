# Repository Guidelines

## Project Structure & Module Organization
Rails code stays inside `app/` (controllers, models, jobs, mailers, middleware) while service objects go in `app/services` and reusable helpers that skip autoloading live in `lib/`. Vite assets sit under `app/frontend`—`entrypoints/` feed Vite, `javascript/controllers/` stores Stimulus code, and `stylesheets/` holds Tailwind layers. Reference docs live in `docs/`, user-story specs in `specs/`, static assets in `public/`, and automated tests mirror the runtime layout inside `test/`.

## Build, Test, and Development Commands
- `bin/setup` installs gems, npm packages, and seeds PostgreSQL.
- `bin/dev` runs Rails + Vite via Foreman (`Procfile.dev`).
- `bin/rails db:migrate db:seed` applies schema changes.
- `bin/rails test` runs the Minitest suite; scope with `TEST=test/models/product_test.rb`.
- `bin/rails test:system` executes Selenium + Capybara coverage for storefront flows.
- `bin/vite build` verifies the production asset bundle before deployment.

## Coding Style & Naming Conventions
Ruby code follows `rubocop-rails-omakase`; run `bundle exec rubocop`, keep two-space indentation, snake_case files, and predicate methods ending with `?`. Name services/jobs after the action they perform (e.g., `app/services/send_sample_kit.rb`). Stimulus controllers follow the `snake_case_controller.js` pattern with matching `data-controller="snake-case"` hooks, and Tailwind utilities should replace bespoke CSS; shared styles live in `app/frontend/stylesheets`. After upgrading npm dependencies, rerun `npx patch-package` to refresh the diffs under `patches/`.

## Testing Guidelines
`test/test_helper.rb` starts SimpleCov, producing reports in `coverage/`; keep new code at or above the baseline. Place tests beside their runtime counterparts (`test/services`, `test/jobs`, etc.) and reuse fixtures in `test/fixtures` or helpers in `test/support`. System suites (`bin/rails test:system`) need Selenium + Chrome, so install `chromedriver` locally and stub third-party calls with WebMock payloads that match the samples captured in `specs/`.

## Commit & Pull Request Guidelines
History favors short, imperative subjects (“Fix email not submitted…”, “Add tests for US2-US5”) with optional phase tags; match that style and call out schema or ENV impacts in the body. Pull requests should describe the change, link the relevant spec or issue, share reproduction steps, and attach screenshots/logs for UI or API tweaks while highlighting any new credentials, Stripe webhooks, or Solid Queue jobs that ops must configure.

## Security & Configuration Tips
Manage secrets with `rails credentials:edit` (Stripe, Mailgun, AWS, Sentry) and keep runtime overrides in a local `.env`. Never commit files from `log/`, CSV exports, or local storage; scrub them or extend `.gitignore`, and document webhook URLs, cron timings, or environment knobs in `docs/` whenever integrations or background jobs change so deployers can update production safely.
