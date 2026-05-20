# AGENTS

This repository is a Phoenix + LiveView Scrum Poker app.

## Project Layout

- `lib/poker/coordinator.ex` - in-memory room coordinator and room process logic.
- `lib/poker_web/live/page_live.ex` + `page_live.html.leex` - room list page.
- `lib/poker_web/live/room_live.ex` + `room_live.html.leex` - room page and voting flow.
- `lib/poker_web/controllers/login.ex` + `templates/controller/login/login.html.eex` - login/auth flow.
- `priv/gettext/**` - translations.

## Run Locally

- Preferred: `./run-local.sh`
- Manual:
  - `mix deps.get`
  - `yarn --cwd assets install --frozen-lockfile`
  - `yarn --cwd assets deploy`
  - `mix phx.server`

## Coding Notes

- Keep UI strings in Russian by default.
- Keep the main header text exactly: `Simple Scrum Poker`.
- For owner-only actions, always enforce permissions in LiveView handlers, not only in templates.
- If new translatable strings are added, update gettext files under `priv/gettext`.
- Avoid changing unrelated behavior in room state handling (`Poker.Room`) unless required.

## Verification

- Run `mix compile` after backend changes.
- Run `mix test` when behavior is changed.
- For UI changes, manually verify:
  - login flow,
  - room creation,
  - owner actions (open/close/reset/timer),
  - rejoin with same owner name.
