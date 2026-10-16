# 00 PROJECT CHARTER

## Project identity

**Project codename:** NUSANTARA  
**Working title:** NUSANTARA: THE MANDATE  
**Genre:** 2D nation/governance simulation, strategy, management, decision simulation  
**Engine:** Godot (stable release selected by Claude Code after repository/toolchain inspection)  
**Programming:** GDScript unless a documented best-practice exception is justified  
**Language:** Bahasa Indonesia  
**Primary platform:** Windows desktop (`.exe`)  
**Secondary platform:** Android (`.apk`) only as a competition-compliance deliverable if the official rules remain unchanged

## Platform priority

**Desktop-first is intentional.**

The gameplay, information architecture, map interaction, simulation workload, UX, input model, performance budget, and visual composition must be designed primarily for a desktop Windows audience. The project must not distort its core design simply to satisfy an assumed mobile-first pattern.

For the competition submission, the supplied IT-CAS 2026 guidebook states that both Android `.apk` and Windows `.exe` are required. Therefore:

1. Build and stabilize the Windows desktop experience first.
2. Keep the core simulation and content architecture platform-agnostic.
3. Do not create a separate mobile-first gameplay design.
4. After desktop feature parity and stability are proven, evaluate the minimum adaptation required for an Android export.
5. If organizer clarification later removes the APK requirement, preserve desktop-only as the final target.

## Vision

Create a compelling, accessible governance simulation in which the player leads **real Indonesia** through a branching five-year administration. The game's world is grounded in current official Indonesian data, real geography, documented culture, and a library of real historical problem cases. The player's future is fictional and determined by decisions.

## Design pillars

### 1. Real Indonesia

Use authentic Indonesian administrative geography, culture, public statistics, and documented problem contexts.

### 2. Data-driven governance

Every modeled region has measurable state. National conditions emerge from regional states and cross-regional interactions. All modeled regions must be semantically simulated individually every internal tick.

### 3. Consequences matter

Decisions generate immediate, delayed, regional, national, social, economic, environmental, and cultural consequences.

### 4. Local wisdom is playable

Local wisdom is not decorative. Where ethically and factually appropriate, its principles become governance mechanics.

### 5. Accessible depth

A new player should understand the game quickly, while deeper data and simulation layers reward curiosity.

### 6. Evidence with provenance

Where a number, case, or cultural fact came from must be traceable.

### 7. Replayable legacy

A run ends with a government legacy assessment. Different decision paths create different legacies.

### 8. Desktop strategy-game UX

The primary experience is a desktop strategy/simulation interface: mouse-driven map navigation, keyboard shortcuts where useful, dense but readable dashboards, clear hover/selection states, resizable panels, and deliberate use of desktop screen real estate.

## Product definition

The player controls **President Nara Adinata**, a fictional president, while the country and geographic/cultural world are **real Indonesia**. The future and alternate outcomes are simulated. The first simulation state is based on the latest official public data snapshot available to the project.

## Success definition

The game is successful when a reviewer can:

1. understand the game within minutes,
2. click a real region and inspect its state,
3. encounter a compelling real-world-inspired case,
4. make a meaningful decision with trade-offs,
5. observe regional and national consequences,
6. understand that local wisdom is part of the solution space,
7. replay and obtain a different legacy,
8. play the primary Windows build offline and without extra software,
9. observe a credible and responsive full-region simulation.
