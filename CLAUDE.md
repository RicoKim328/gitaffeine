# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Status

The repository has no source code yet (only `LICENSE`). There are no build, lint, or test commands. Update this file once a project skeleton exists.

## What gitaffeine is

A macOS menu bar app. Clicking the menu bar icon opens a popup that shows:

- The user's git contributions for the last ~2 months as a contribution ("grass") grid, computed from local repositories using the system-installed `git`.
- API usage graphs for AI providers the user configures (e.g. OpenAI/Codex, Anthropic/Claude, xAI/Grok), fetched from each provider's own API.

## Known constraints

- The current development machine runs Linux. A macOS app cannot be built or run here, so building and UI verification must happen on a Mac. Platform-independent logic (git log parsing, usage API response decoding) can be tested anywhere if it lives in a separate SwiftPM target.
- Provider usage/cost APIs need org-level admin credentials: OpenAI's Usage/Costs API needs an Admin key, and Anthropic's Usage & Cost Admin API needs an `sk-ant-admin…` key (not available to individual accounts). xAI usage endpoints have not been verified against official docs. Check the official docs before you implement a provider.
- Store API keys in the macOS Keychain only.

## Proposed (not yet confirmed) direction

Swift + SwiftUI `MenuBarExtra`, macOS 14+, Swift Charts for usage graphs. Core logic lives in a SwiftPM package tested with `swift test`, and a thin app target sits on top. Keep the design minimal: add one `UsageProvider` protocol per provider, with no plugin system.
