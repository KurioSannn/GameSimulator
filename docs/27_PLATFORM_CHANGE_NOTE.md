# 27 PLATFORM CHANGE NOTE

## Request incorporated

The human team explicitly changed the project priority from a mobile-first/cross-platform design assumption to a **desktop `.exe`-first strategy game**.

## What changed

- Windows desktop is now the primary target for UX, input, performance, and QA.
- Mobile-first layout guidance was removed from the core UI contract.
- Touch interaction is not part of the core desktop design.
- Godot architecture is intentionally left open for Claude Code to choose according to best practice.
- Android remains a secondary compliance/export pass because the supplied IT-CAS 2026 guidebook explicitly lists both APK and EXE as required submission formats.

## Do not misinterpret this

This is **not** permission to ignore the competition requirement. It means: build and prove the desktop game first, then adapt/export for Android only if still required.
