# 05 CULTURAL RESEARCH SPECIFICATION

## Goal

Create a high-coverage **Indonesia Cultural Knowledge Base** grounded in public, credible sources. Culture is part of the simulation world and a potential governance mechanic source.

## Core principle

> Research first, interpretation second, gamification third.

## Coverage ambition

Include as many documented cultural elements as can be responsibly sourced. Do not claim absolute completeness. Maintain a coverage and gap registry.

## Primary research domains

- ethnic groups / suku bangsa
- languages
- local languages and variants
- adat
- customary institutions
- rites
- ceremonies
- oral traditions
- stories/folklore
- proverbs/pantun
- traditional food/drink
- traditional medicine where safe and appropriate
- traditional knowledge
- traditional land management
- agricultural systems
- water management traditions
- fisheries management traditions
- crafts
- clothing
- ornaments
- architecture
- music
- dance
- performing arts
- literature
- traditional games
- traditional sports
- tools and technologies
- weapons as cultural documentation only, not gameplay weapons
- cultural institutions
- cultural spaces
- intangible heritage
- tangible heritage
- customary territories
- indigenous communities

## High-priority source systems to investigate

- Sistem Pendataan Kebudayaan Terpadu (SPKT)
- Budaya Kita / official culture data portals
- Warisan Budaya Takbenda databases
- Badan Bahasa language datasets
- BPS ethnic/language publications
- official museums
- official provincial/regency culture offices
- credible universities and cultural research institutions
- BRWA and AMAN datasets/context for customary territories when publicly available and appropriate
- UNESCO where directly relevant

Always verify the current availability and licensing status of each source.

## Suggested record schema

Every cultural object should capture as many of these as possible:

- culture_id
- preferred_name
- aliases
- category
- subcategory
- island
- province
- regency/city
- locality
- ethnic/community association
- language association
- description
- history/context
- social function
- ecological/economic relevance
- values/principles
- practice/process
- materials/resources
- participants
- season/occasion
- documented status
- WBTb status if applicable
- customary status if applicable
- sensitivity level
- sacred/restricted indicator
- gameplay suitability
- adaptation notes
- source institution
- source title
- source URL
- publication date
- retrieval date
- confidence

## Cultural interpretation rules

### Rule 1: Do not equate region with one culture

Papua, Maluku, Sulawesi, Sumatra, etc. contain diverse peoples and practices. Preserve plurality.

### Rule 2: Do not turn culture into magic buffs

Example:

Bad:

> Subak = +10 Food.

Better:

> principles of collective water governance can inform a water-allocation mechanic.

### Rule 3: Sacred/sensitive material requires caution

A documented cultural object is not automatically appropriate for gameplay.

Use classification such as:

- informational only
- potentially adaptable
- adaptable with caution
- do not gamify

### Rule 4: Document the abstraction

For every mechanic derived from culture, store:

```text
source fact
→ interpretation
→ mechanic abstraction
→ why abstraction is reasonable
→ sensitivity review
```

## Cultural mechanic examples

These are design hypotheses, not final factual claims:

- Subak → collective water governance
- Sasi → sustainable resource timing and community rules
- Gotong royong → community mobilization/social capital
- Musyawarah → consensus/acceptance mechanism

Every actual inclusion must be researched before implementation.

## Cultural source integrity

Never copy long source descriptions into game text. Paraphrase and cite.
