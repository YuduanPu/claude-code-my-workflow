---
paths:
  - "**/*.jl"
  - "explorations/**/*.jl"
---

# Julia Code Standards

**Standard:** Senior research-engineer + PhD-researcher quality. Reproducible, environment-pinned, publication-ready output.

> **Scope:** General standards for the project's Julia scripts (the mean-field maps and stochastic replications). Monte-Carlo-specific discipline (DGP, truth, MCSE, per-rep seeding) lives in [`simulation-conventions.md`](simulation-conventions.md). The numerical discipline in §7 applies to both.

---

## 1. Reproducibility & environment

- Pin the environment: commit **`Project.toml` and `Manifest.toml`**; run scripts with `julia --project`.
- Load packages with `using` at the top of the file (not scattered mid-script).
- Create one explicit RNG at the top, seeded once: `rng = MersenneTwister(20260607)` (or `StableRNGs.StableRNG` when a number must match across Julia versions). Never call the global `rand` inside loops you expect to reproduce.
- All paths relative to the repo root; create output dirs with `mkpath(out_dir)`.
- A header comment block stating: what the script computes, deterministic vs stochastic, the calibration, the output path. (The existing `trauma_phase_diagram.jl` header is the model to follow.)

## 2. Function design

- `snake_case` for variables, lowercase for functions (`basin`, `drifta`, `finalmu` — or keep the existing names consistently).
- Type-annotate function signatures where it aids clarity/perf; return named tuples or structs, not bare positional tuples for multi-value returns.
- No magic numbers — primitives (`q, γ, σ, λ, δ, κ, …`) defined once as named constants at the top, matching the draft's notation.
- A docstring on every non-trivial function: what it returns, in what units, against what truth.

## 3. Domain correctness

- Verify each routine matches the draft's formula: `Φ(ᾱ)=(1-σ)(1-e^{-λφ(ᾱ)})`, the drift `f(ω;α)`, the share `φ`. A mismatch between code and the §5/§6 equations is a bug, not a calibration choice.
- Keep the **BDG-nesting check** as an executable assertion (σ=0, α=1, γ̂=γα̂ ⇒ recovers BDG) — it is the correctness anchor (see `replication-protocol.md`).

## 4. Publication-ready figures (MANDATORY — user requirement)

Every figure that can reach the paper must be submission-grade:

```julia
using Plots
default(
    fontfamily       = "Computer Modern",   # match the paper's typeface
    framestyle       = :box,
    grid             = false,
    legendfontsize   = 9,
    guidefontsize    = 11,
    titlefontsize    = 12,
    tickfontsize     = 9,
    size             = (640, 440),          # consistent aspect across the deck of figures
    dpi              = 300,                  # submission DPI
)
```

- **Consistency over cleverness:** all figures share one theme, palette, font, and sizing. A reader should see them as one family.
- Label axes with the draft's notation (`\bar\alpha`, `\phi`, `\lambda`, `\kappa`, `\mu_T`); use LaTeX strings (`L"\bar\alpha"`).
- Colour-blind-safe palette; never rely on colour alone (use linestyle/markers too).
- Export deterministically: `savefig(joinpath(out_dir, "trauma_<name>.png"))`. One script ⇒ one named figure; no manual cropping/editing afterward (SSOT).
- Prefer vector output (`.pdf`/`.svg`) for line art when the draft's renderer accepts it; keep `.png` at 300 DPI otherwise.

## 5. Output data pattern

- Heavy computations: save the result object (`JLD2.@save` / `Serialization.serialize`) so figures and the audit can reload without re-running.
- Save summary tables as a machine object **and** a human-readable `CSV`.
- Never let a headline number live only in REPL output.

## 6. Line length & mathematical exceptions

- Keep lines ≤ 100 chars, **except** dense mathematical expressions (map iterations, likelihood ratios, finite differences) where breaking harms readability — then add a one-line comment naming the operation.

## 7. Numerical discipline

- **No float equality.** Use `isapprox(a, b; atol=1e-10)`, never `==` on doubles or on iterated fixed points.
- **Clamp before `log`/`qnorm`-like calls.** Near the ceiling `1-σ`, guard `e^{-λφ}` and any `log` argument away from 0/1: `clamp(p, eps(), 1 - eps())`.
- **Integer literals for counts.** Friend counts `n_A, n_B, n_0`, replication counts — keep them `Int`.
- **Pre-allocate** result arrays (`Vector{Float64}(undef, n)`); never `push!` in a hot loop.
- **Explicit convergence criteria** for fixed-point iteration (`isapprox` + max-iter cap); report non-convergence rather than returning the last iterate silently.

## 8. Checklist

```
[ ] Project.toml + Manifest.toml committed; script runs with --project
[ ] using at top; one rng seeded once at top (YYYYMMDD)
[ ] all paths relative; mkpath for outputs
[ ] header states: computes-what / deterministic-or-stochastic / calibration / output path
[ ] routines match the draft's equations; BDG-nesting assertion present
[ ] figures: shared theme, LaTeX-notation labels, 300 DPI, deterministic savefig
[ ] heavy results saved (JLD2/Serialization) + CSV summary
[ ] numerical discipline: isapprox not ==, clamp before log, pre-allocated, convergence checked
```

## Cross-references

- [`simulation-conventions.md`](simulation-conventions.md) — Monte Carlo discipline (MCSE, per-rep streams).
- [`single-source-of-truth.md`](single-source-of-truth.md) — figure provenance; never hand-edit a derived PNG.
- [`replication-protocol.md`](replication-protocol.md) — replicate BDG before extending; the nesting check.
