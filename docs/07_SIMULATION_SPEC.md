# 07 SIMULATION SPECIFICATION

## Objective

Build a coherent multi-region simulation where every modeled region has individual state and is semantically updated on every internal simulation tick.

## Time

- monthly internal tick
- quarterly player-facing turn boundary
- five-year baseline administration
- target: 60 monthly ticks / 20 quarters

## Full region simulation requirement

All regions in the baseline map must have independent state.

Every simulation tick must conceptually execute:

```text
for each region:
    evaluate inputs
    update production
    update resources
    update services/capacity
    update environment
    update stakeholder conditions
    update sentiment
    process relevant event states
    store new state
```

The implementation may optimize memory access, vectorize/batch arithmetic, or use other optimizations. It may not semantically skip an entire region's simulation simply because it is off-screen.

## Static vs dynamic state

### Static/reference

- region name
- administrative code
- geometry
- official categorical metadata

### Baseline

- latest official starting values

### Dynamic

- simulated economy
- production
- prices
- resource stocks
- infrastructure condition
- services
- employment
- welfare
- environment
- sentiment
- policy effects
- event state

## Resource semantics

Every resource must specify one of these semantics:

- stock
- flow
- production rate
- reserve
- potential
- capacity
- demand
- price
- budget
- index
- score

Do not treat these as interchangeable.

## Suggested national indicators

- budget
- revenue
- expenditure
- economy
- welfare
- stability
- trust
- environment
- regional equity
- cultural resilience

## Regional state examples

- population
- economic output
- income proxy
- food production
- energy capacity
- mineral extraction capacity
- forest condition
- water availability
- infrastructure
- health service capacity
- education capacity
- employment
- price level
- sentiment
- social capital
- local government capacity
- culture-related resilience

## Causal framework

At minimum, model relationships such as:

```text
Production
→ Supply
→ Price
→ Welfare
→ Sentiment
```

```text
Infrastructure
→ Logistics
→ Market access
→ Production realization
→ Regional economy
```

```text
Extraction
→ Revenue / output
→ Employment
→ Environment pressure
→ Community response
→ Sentiment
```

```text
Budget
→ Public spending
→ Capacity
→ Welfare
→ Trust
```

These are conceptual relations, not final formulas.

## Inter-regional dependencies

Model where meaningful:

- food supply chains
- electricity transmission/distribution
- ports/logistics
- industrial processing
- labor mobility
- fiscal transfers
- resource extraction and downstream processing

## Sentiment model

Sentiment should be a function of current state and recent history. It should not be purely random.

Potential components:

- welfare
- employment
- price pressure
- public services
- disaster response
- environmental condition
- regional development
- policy satisfaction
- government trust
- cultural alignment
- historical memory

## Stakeholder layer

Stakeholder responses may influence:

- protest probability
- cooperation
- policy implementation
- investment
- community participation
- public sentiment

## Uncertainty

Use uncertainty where reality is uncertain, but preserve transparency and causality.

Each uncertain system should document:

- expected value
- possible range
- major factors
- random seed/determinism strategy for debugging

## Cascading crises

A crisis can create secondary and tertiary effects.

Example:

```text
Food production ↓
→ national supply ↓
→ prices ↑
→ inflation ↑
→ welfare ↓
→ sentiment ↓
→ political pressure ↑
```

The game should allow the player to interrupt a cascade through later decisions.

## Progression

Capabilities can unlock through investment/research.

Example domains:

- agriculture
- logistics
- energy
- health
- education
- digital government
- disaster resilience
- environmental management
- industrial processing

## Ending

At end of administration, calculate a multidimensional legacy rather than one simplistic score.
