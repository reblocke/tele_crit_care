# AGENTS

## Project Purpose
Analysis of tele-critical care transfers during COVID

## Public and Data-Safety Rules
- Treat this repository as public. Do not add PHI, restricted datasets, credentials, private drafts, or publisher-formatted article text.
- Clinical operations data likely restricted; verify no PHI
- Manuscript status: No manuscript version public yet; keep to repo summary

## How to Orient Quickly
- Start with `README.md` for project scope, workflow, data notes, citation, and license information.
- Use `CITATION.cff` for structured citation metadata when present.
- Inspect scripts/notebooks before running them; do not assume generated outputs are current.

## Workflow
The legacy entry points are `Tele Crit Care Data Wrangling.do` followed by `Tele Crit Care Analysis.do`. Their input paths and execution prerequisites are not documented as a portable command. Inspect the affected script and approved local input configuration before an authorized run; do not treat “Review Stata workflow” as executable shell text. Report the unresolved runtime setup rather than substituting clinical inputs.

## Verification Before Publishing Changes
- Run `git diff --check`.
- Validate `CITATION.cff` as YAML after citation edits.
- Do not commit generated outputs, logs, caches, virtual environments, `.DS_Store`, or checkpoint files unless intentionally released.
- For clinical or collaborator data, confirm that no row-level restricted data or identifiers are included.
