# 09 CONTENT AND DATA SCHEMA

## Principle

Repeated game content should be data-driven.

The final Godot representation may use `Resource`/`.tres`, JSON, CSV, databases, or a combination chosen by Claude Code. The game-design requirement is about behavior and provenance, not a pre-decided implementation format.

## 1. Region record

Suggested fields:

```text
region_id
parent_region_id
region_level
name
aliases
province_code
regency_city_code
island_group
geometry_ref
centroid
area
baseline_population
baseline_economy
baseline_human_capital
baseline_infrastructure
baseline_resources
baseline_culture_refs
source_refs
```

## 2. Simulation state

```text
region_id
tick
population
economy
welfare
stability
trust
environment
budget_share
food_supply
energy_supply
employment
infrastructure_condition
logistics_capacity
resource_stocks
resource_production
resource_consumption
prices
stakeholder_state
sentiment
active_policies
active_events
history_flags
```

## 3. Policy record

```text
policy_id
name
description
category
requirements
budget_cost
implementation_time
target_scope
target_regions
direct_effects
delayed_effects
risk_profile
stakeholder_effects
cultural_constraints
source_refs
```

## 4. Event record

```text
case_id
title
category
time_window
location_scope
trigger_conditions
severity_conditions
briefing
stakeholders
choices
immediate_effects
delayed_effects
regional_effects
national_effects
follow_up_links
source_refs
cultural_refs
simulation_notes
```

## 5. Cultural record

See `docs/05_CULTURAL_RESEARCH_SPEC.md`.

## 6. Source record

```text
source_id
institution
title
url
source_type
publication_date
retrieved_at
reference_period
geographic_resolution
license_note
methodology_note
checksum
status
```

## 7. Data provenance record

Every derived value should be traceable through:

```text
source
→ raw field
→ transformation
→ normalized field
→ game variable
```

## 8. Fact classification

Use:

- REAL_OFFICIAL
- REAL_ACADEMIC
- REAL_NEWS
- REAL_SECONDARY
- DERIVED
- SIMULATED
- FICTIONAL

## 9. Missing-data classification

Use:

- NOT_AVAILABLE
- NOT_PUBLISHED
- WRONG_RESOLUTION
- STALE_ONLY
- CONFLICTING
- PENDING_VERIFICATION

Never use `0` when the true status is unknown.
