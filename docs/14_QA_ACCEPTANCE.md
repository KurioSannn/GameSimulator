# 14 QA AND ACCEPTANCE CRITERIA

## A. Competition compliance

- [ ] Windows `.exe` builds successfully
- [ ] APK builds successfully **if required by the current official rules**
- [ ] within applicable file-size limits
- [ ] no extra software required at runtime
- [ ] gameplay guide can be produced
- [ ] tools list can be documented
- [ ] AI usage can be disclosed

## B. Desktop UX

- [ ] 1920×1080 reference layout is coherent
- [ ] common 16:9 desktop sizes remain usable
- [ ] map pan/zoom is responsive
- [ ] mouse interaction is intuitive
- [ ] keyboard shortcuts, if implemented, are discoverable
- [ ] tooltips do not obscure critical controls
- [ ] UI does not require touch behavior

## C. Map

- [ ] Indonesia map loads
- [ ] province selection works
- [ ] regency/city selection works
- [ ] no obvious broken geometry in supported baseline
- [ ] selected region can be inspected

## D. Simulation

- [ ] every modeled region has state
- [ ] every region updates every simulation tick semantically
- [ ] off-screen regions continue simulating
- [ ] simulation does not depend on UI presence
- [ ] no accidental duplication of regional state

## E. Causality

- [ ] player decisions change state
- [ ] delayed effects are applied
- [ ] regional and national impacts can diverge
- [ ] follow-up cases can be triggered by prior state
- [ ] sentiment changes for explainable reasons

## F. Save

- [ ] save anytime
- [ ] load after restart
- [ ] multiple save slots
- [ ] autosave recovery
- [ ] quicksave
- [ ] corrupt save does not crash whole game

## G. Data integrity

- [ ] source year preserved
- [ ] source unit preserved
- [ ] missing data is not silently treated as zero
- [ ] provenance is present
- [ ] real and simulated values are distinguishable
- [ ] data snapshot is recorded

## H. Cultural integrity

- [ ] source documented
- [ ] interpretation documented
- [ ] sensitive content reviewed
- [ ] province-level stereotypes avoided

## I. Performance

Measure, do not assume. Desktop is the primary performance target. Benchmark:

- startup
- map load
- opening main dashboard
- one monthly tick
- one quarterly turn
- one full year
- full baseline 60 monthly ticks
- save/load time
- memory usage
- worst-case all-region stress case
- long-session stability

If APK is later required, run a separate Android feasibility/performance pass after desktop stability is proven.

## J. Regression

Every major system change should run at least:

- simulation unit tests
- save/load tests
- content validation
- source/provenance validation
- build smoke test
- critical path playtest
