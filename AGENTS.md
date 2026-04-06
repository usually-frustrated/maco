# AGENTS

## Purpose

This file defines the operating rules for future implementation work on this repository.

## Core Principles

- Less is more in both code and docs.
- Reuse existing platform and protocol components.
- Prefer native macOS surfaces over custom UI.
- Keep the menu bar app small and focused.
- Avoid speculative abstraction.

## Architecture Rules

- Use Swift for app and extension code.
- Use Apple's `NetworkExtension` for VPN integration.
- Use `OpenVPN 3 Core` instead of reimplementing OpenVPN behavior.
- Treat the menu bar as the single app-owned control surface.
- Use notifications for passive information.
- Use macOS Keychain for persisted secrets.
- Never persist TOTP.
- Store imported profile files in `~/.config/...`.
- Treat imported profile files as user-visible, user-editable configuration.

## Product Rules

- Support `.ovpn` import in v1.
- Support multiple saved profiles.
- Allow multiple active profiles if the chosen `NetworkExtension` model supports it cleanly.
- Support username/password plus TOTP first.
- Keep certificate auth optional and minimal unless it falls out cleanly.
- No rich settings UI.
- No profile editing UI in v1.

## Code Size And Layout Rules

- Keep files around 180 lines.
- Split code before files become broad or multipurpose.
- Keep modules small and composable.
- Keep each type's public API narrow.
- Keep each function focused on one job.
- Prefer a few small files over large mixed-responsibility files.
- If a file grows, split by responsibility, not by arbitrary naming.

## API Design Guidelines

- Exposed APIs should be simple enough to understand quickly.
- Prefer plain data models over deep inheritance or protocol stacks.
- Hide platform-specific complexity behind small interfaces.
- Make side effects explicit in names and call sites.
- Avoid helper layers that only rename other helpers.
- If a module is hard to explain, its API is probably too broad.

## UI Guidelines

- The menu bar should do only what macOS does not already do well.
- Avoid duplicate controls for the same action.
- Keep prompts short and task-specific.
- Prefer status text and notifications over custom dashboards.
- Add UI only when a real workflow cannot happen natively.

## Docs Guidelines

- Only keep the docs that help someone continue implementation.
- Prefer updating an existing doc over adding a new one.
- Keep docs short, practical, and decision-focused.
- Do not create planning clutter.

## Implementation Guidelines

- Build in phases with a usable result at the end of each phase.
- Prefer vertical slices over scaffolding-heavy groundwork.
- Verify risky assumptions early.
- If a requirement depends on Apple platform behavior, validate it early rather than coding around guesses.
- Keep the repo handoff-friendly after each work session.

## Handoff Expectations

- Leave code building or clearly note what remains.
- Leave docs updated only where the actual behavior or decisions changed.
- Record blockers as concrete technical questions, not vague concerns.
- When using sub-agents, assign narrow, disjoint ownership and merge back into the same architectural rules.
- End every implementation session by updating the implementation logs and the handoff docs for the work that was actually completed, including pivots, blockers, and verification results.
- If the session changed implementation direction or produced a new durable checkpoint, add or update a phase worklog in `docs/worklogs/` and update `docs/implementation-logs.md` so the record is discoverable.
- Sub-agents must follow the same logging requirement for their assigned slice before handoff back to the main agent.
