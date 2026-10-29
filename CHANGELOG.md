# Changelog

## 0.4.4 — 2026-10-29

Cache complete state-reference scopes once per cell, and index user declarations
by separate name/parent components. Prevent repeated out-of-scope diagnostics and
reject declared simple attributes written with complex syntax. Infer bus member
bounds only from explicit width, one endpoint and direction; reject negative
members and inferred negative endpoints. Reject negative SI transition results
after extrapolation while retaining legal negative propagation delay. Add thirteen
focused regressions, 4096-item workloads and output-failure preservation checks.
Public APIs, nine commands and physical evaluation scope remain unchanged; full
Liberty 2017.06 conformance remains incomplete.

## 0.4.3 — 2026-10-29

Raise the compiler floor to moonc 0.10.16 and pin SDK/core 0.10.16+b1a0e846e
for the updated acceptance guide. Add an isolated Windows SDK installer,
terminal activation and compiler/core checks; CI now runs both examples as well
as strict check/build/test and independent checks. Migrate deprecated to_json
calls to Json(value), plus the SDK formatter's Int32/default-argument spelling.
No domain algorithms or evaluation scope are added. Recorded representative
JSON and written-file outputs remain identical; full standard conformance
remains incomplete.

## 0.4.2 — 2026-10-28

Conservative parser and correctness patch. Accept one initial UTF-8 BOM in a
library or explicit include fragment without stripping embedded text or bypassing
resource limits; emit ordinary UTF-8. Handle continuation immediately after bare
values, reject NUL consistently in comments, resolve statetable internal nodes
within their cell, and avoid false overflow during representable extrapolation.
Public APIs, nine commands and physical evaluation scope remain unchanged.
Add eleven targeted regressions and expand CLI/Decimal cross-checks. Full Liberty
2017.06 conformance remains incomplete.

## 0.4.1 — 2026-10-26

Conservative validation fixes; public APIs, commands and evaluation scope are
unchanged. Share table-format validation between the reader and evaluator, reject
missing/empty axes instead of silently returning a scalar, and enforce resolved
declared dimensions. Parse CLI budgets as decimal integer literals before range
checks. Validate selected latch paired attributes and state enums while retaining
the SR-latch exception. Add eight focused regressions and CLI rejection cases.

## 0.4.0 — 2026-10-26

Expand directly declared scalar pin aliases such as pin(A,B), with explicit
per-library pin and validation-work budgets. Warn when bus/bundle containers
remain outside the typed inventory. Resolve cell-local bus types with lexical
shadowing, require flip-flop next-state/clock equations, and avoid copying the
global type map per cell.

Preserve quoted numeric/special Boolean signal identities through formatting and
semantic diff. Stabilize finite extreme-value interpolation, keep SI prefix case
significant, validate caller-supplied units/numeric fields, and never drop an
inherited third table axis or hide malformed 3-D data behind an unsupported warning.
Add a fixed-seed Decimal oracle and CLI invariants to CI. Full 2017.06 conformance
remains incomplete; the new checks do not claim exhaustive standard coverage.

## 0.3.0 — 2026-10-25

Add 18 traceable standard-rule families for selected group/attribute, template,
table, bus and sequential structures. Validate scalar through 3-D table format
data independently of numerical evaluation, including thirty 2017.06 LVF moment
table kinds. Full standard conformance remains false and explicitly non-exhaustive.

Correct Liberty XOR-before-AND Boolean precedence and support quoted numeric pin
names. Preserve exact decimal differences beyond Double precision and related-pin
order. Accept unquoted bus ranges, reject swallowed attribute separators, enforce
writer allocation budgets, and refuse unsupported SI delay models and negative
transition values. Add independent Nangate/Yosys roundtrips and 72 Nangate numeric
queries; retain unmodified ASAP7 missing-semicolon inputs as negative cases.

## 0.2.0 — 2026-10-21

Declare Liberty 2017.06 as the fixed compatibility target. Add bounded include resolution, extension declaration/type checks, exact integer literal validation, compat/expand CLI commands, executable format/evaluation boundary cases and a versioned conformance roadmap. Full standard conformance remains incomplete and is reported separately from implemented checks.


## 0.1.0 — 2026-10-19

Initial original MoonBit implementation: bounded Liberty syntax and writer, physical unit parsing, cell/pin/timing models and diagnostics, Boolean functions, scalar/1D/2D NLDM lookup, explicit SI combinational queries, structural semantic diff and context-preserving extraction. Native CLI, independent IHP fixture checks, three core backends, automated acceptance and measured benchmarks.

Known scope: not a full Liberty standard implementation, STA engine, electrical equivalence checker or foundry signoff tool. See docs/SUPPORT.md.
