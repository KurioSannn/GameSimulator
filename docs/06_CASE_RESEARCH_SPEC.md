# 06 REAL-WORLD CASE RESEARCH SPECIFICATION

## Goal

Create a master library of at least **100 validated real Indonesian cases** suitable for governance simulation. More is acceptable if quality remains high.

## What counts as a case

A case should represent a real event/problem/decision environment that can plausibly create a meaningful governance decision point.

Examples of categories:

- flood
- earthquake
- tsunami
- volcanic eruption
- drought
- forest fire
- food price crisis
- supply disruption
- energy shortage
- inflation/commodity shock
- industrial disruption
- infrastructure failure
- public health crisis
- education crisis
- poverty/social issue
- regional conflict
- environmental conflict
- land-use conflict
- natural resource governance
- fisheries issue
- agricultural issue
- transport disruption
- digital disruption
- major public service failure
- local cultural preservation challenge
- disaster recovery
- fiscal pressure
- regional inequality

## Historical breadth

Cases do not need to be current. Use a long historical window when useful. The case library is not a history textbook; it is a library of real situations for scenario design.

## Required fields

```text
case_id
case_title
case_category
subcategories
start_date
end_date
country
island
province
regency_city
exact_location_if_known
real_event_summary
trigger
root_causes
contributing_factors
stakeholders
population_affected
reported_impacts
economic_impacts
social_impacts
environmental_impacts
infrastructure_impacts
government_response
community_response
public_response
policy_context
known_constraints
known_uncertainties
primary_sources
secondary_sources
retrieved_at
source_quality
potential_decision_window
game_decision_options
immediate_simulated_effects
delayed_simulated_effects
regional_simulated_effects
national_simulated_effects
possible_follow_up_cases
relevant_local_wisdom
cultural_sensitivity_notes
fact_vs_simulation_notes
```

## Source hierarchy

Prefer:

1. BNPB/BMKG/ministry/regional government/official reports
2. official statistics
3. parliamentary or legal documents when relevant
4. reputable academic studies
5. reputable news with dated reporting
6. other credible documentation

For major cases, aim for multiple independent sources where practical.

## Case verification

A case should not be marked `validated` unless the core event is supported by credible evidence.

Validation status:

- candidate
- researched
- cross-checked
- validated
- rejected

## Timeline standard

Capture a sequence of events where available:

```text
T-7 days
↓
warning / precursor
↓
T0
event occurs
↓
T+1
initial response
↓
T+3
secondary impact
↓
T+7
recovery/continuing crisis
```

## Causal chain standard

Every strong case should include:

```text
trigger
→ exposure
→ vulnerability
→ impact
→ response
→ secondary effect
```

The chain can branch.

## Real vs simulation distinction

The actual event is factual. Player decisions and alternate outcomes are game simulation.

Never write fictional game outcomes as though they were historical facts.

## Geographic coverage rule

Case library should be geographically diverse across:

- Sumatra
- Java
- Kalimantan
- Sulawesi
- Bali/Nusa Tenggara
- Maluku
- Papua

Do not allow Java to dominate merely because source volume is larger.

## Candidate selection for the main story

The master pool can be 100+, but the final game should use a curated subset that provides:

- rising complexity
- geographic diversity
- domain diversity
- meaningful trade-offs
- local-wisdom opportunities
- branching possibilities
- performance-safe content scope
