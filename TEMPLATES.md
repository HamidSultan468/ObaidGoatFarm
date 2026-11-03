# Record Templates

**Status: not started.** A cross-cutting feature referenced across multiple CLAUDE.md phases (Goat Farm §06, Land §07, Documents §08) rather than owned by one module.

## Concept

Ready-made templates for common record types (e.g. Sales Invoice, Purchase Invoice, Expense Voucher, Salary Record, Land Record, Asset Record — as shown in the reference dashboard mockup's "Add New Record" panel), plus support for custom, user-defined templates. A template pre-fills a record's structure so routine entries are fast to create without re-specifying every field.

## Planned scope

- A library of built-in templates, one set per module, maintained alongside that module's own document (e.g. goat farm templates live conceptually with [GOAT_FARM.md](GOAT_FARM.md), but this file is the index)
- Custom template creation by users
- A universal "Add New" entry point (CLAUDE.md §Phase 08) that lets a user pick a template regardless of which module they're in

## Notes for when this is built

- Templates are naturally data-driven (a schema per template, rendered into a dynamic form) rather than one hardcoded screen per template — worth designing generically once two or three real modules (Phase 05+) exist to generalize from, rather than guessing the abstraction now with zero real examples.
- This file will be split or expanded once templates for a specific module are actually designed; until then it's intentionally just an index of the concept.
