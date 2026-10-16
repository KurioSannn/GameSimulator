# 02 GAME DESIGN DOCUMENT BASELINE

## 1. Working title

**NUSANTARA: THE MANDATE**

Title remains a working title until the team explicitly locks a final title.

## 2. Main character

**Nara Adinata**

### Character role

Fictional President of Indonesia.

### Baseline personality

- analytical
- calm
- empathetic
- pragmatic
- curious
- occasionally over-analytical

### Character conflict

Nara begins with faith in evidence and gradually learns that evidence can clarify trade-offs without providing a perfect answer.

### Character arc

```text
"Data can help us find the answer."
            ↓
"Every answer creates a trade-off."
            ↓
"Leadership means choosing which trade-offs society can live with."
```

Age, family, exact political history, education details, and other biography elements remain provisional until story development.

## 3. World

The geographic and cultural setting is **real Indonesia**.

The game may fictionalize the presidency and future outcomes, but it must not replace real Indonesian geography or cultural identity with a generic "Indonesia-like" setting.

## 4. Map hierarchy

```text
Indonesia
 ↓
Pulau/Kawasan
 ↓
Provinsi
 ↓
Kabupaten/Kota
```

Lower geographic levels may be stored when officially available but are not automatically required as primary map interaction layers.

## 5. Regions

All administrative regions in the latest official baseline snapshot are eligible for simulation. Do not hardcode 514 forever without verifying the current official administrative structure during the research snapshot.

## 6. Simulation model

The game is a stateful simulation.

A region has:

- static/reference facts
- baseline facts
- simulated state
- historical state/memory
- local cultural metadata
- resource profile
- stakeholder/sentiment state
- event eligibility

## 7. Decision model

A player decision can change:

- budget
- production
- infrastructure
- welfare
- sentiment
- employment
- environment
- resource extraction
- regional equity
- cultural resilience
- future case probabilities

## 8. Local wisdom model

Local wisdom should be translated only when:

1. the cultural source is reliable,
2. the practice/principle is understood in context,
3. the game mechanic is an honest abstraction rather than a fake historical claim,
4. the adaptation is culturally appropriate,
5. the source and interpretation are documented.

## 9. Historical cases

The target is at least **100 validated real-world cases** in the master library. A larger pool is welcome when quality is maintained.

Not all cases need to appear in one playthrough.

## 10. Case selection

Cases can be:

- scripted to specific story chapters
- condition-triggered
- probability-weighted
- chained from previous decisions

## 11. Case branching

Cases should support:

- multiple decisions
- immediate consequences
- delayed consequences
- regional consequences
- stakeholder consequences
- follow-up cases

## 12. Randomness

The game should use controlled uncertainty rather than arbitrary randomness.

The same decision can produce a range of outcomes when explicitly modeled, but major system relationships should remain explainable.

## 13. News/briefing system

Case presentation can use a fictional in-game briefing/news wrapper based on real source facts. Do not copy news articles verbatim.

## 14. Advisor system

Advisor characters provide information, recommendations, and human context but do not remove the player's agency.

Suggested advisor domains:

- Keuangan
- Pembangunan
- Sosial
- Lingkungan
- Kebudayaan
- Data/Ilmiah

## 15. Progression

Players may unlock or improve capabilities such as:

- agriculture
- irrigation
- logistics
- industry
- digital government
- energy
- public services
- environmental management

## 16. Failure

Resource exhaustion should usually create crisis states rather than instant game over.

Catastrophic game-over conditions may exist only for extreme systemic collapse.

## 17. Replayability

Different choices must produce materially different states and legacy profiles.
