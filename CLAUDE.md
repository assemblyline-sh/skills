# CLAUDE.md

Public repo of Claude Code skills for Assembly Line (assemblyline.sh), shipped as one plugin
(`assemblyline`) that is also its own marketplace. Rules for writing skills are in
CONTRIBUTING.md; follow them.

- Everything here is public: fictional examples only (acme, globex, hooli), no customer or
  person names, hostnames, IPs, org ids or keys. Grep before committing.
- Skills follow the skill-writing principles at
  https://github.com/alexjv89/engineering-standards/blob/main/principles/skills.md: thin
  skill, deep references, no run state.
- `claude plugin validate .` must pass before a commit.
- Skills mature in real use first (Assembly Line's own factories); change the skill after
  every run that taught something, and log it in CHANGELOG.md.
- Commit to the checked-out branch.
