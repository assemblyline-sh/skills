# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the plugin version follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- `migrate-worker-to-factory`, from the first three migrations:
  - The survey checks the worker's git state (uncommitted, untracked, unpushed) and asks to
    compare it with the checkout on the machine that runs the worker.
  - A second cutover path: stop the worker and move every line at once, when all lines go to
    one factory session.
  - Switching a schedule on runs a missed slot at once; the cutover steps say so.
  - Stopping the worker also carries `temp/work_records/`, and a new retire step checks
    nothing is left behind, backs up, archives the repo and deletes every copy.
  - Troubleshooting: missed-slot runs, transient `Poll error: fetch failed`, code missing
    from the copy, leftover run logs.

## [0.1.0] - 2026-10-19

### Added
- `migrate-worker-to-factory`: converts a FinOpsBricks `worker-*` repo to an Assembly Line
  `factory-*` repo and moves its lines live one at a time. Scripts `scan-worker.sh` (survey)
  and `apply-renames.sh` (mechanical renames).
- Claude Code plugin and marketplace manifests (`assemblyline@assemblyline`).
