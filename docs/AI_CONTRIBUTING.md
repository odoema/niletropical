# Nile Tropical — AI Contribution Protocol

## Purpose

This repository is designed so a new AI contributor can join without private conversation history. The repository must explain the project, live authority, contracts, current state, safety rules, and collaboration process.

## On first connection

1. Read `AI_START_HERE.md`.
2. Read `AGENTS.md`.
3. Read `docs/AI_HANDOFF.md`.
4. Read `docs/backend-contract.md`.
5. Read `docs/frontend-backend-map.md`.
6. Read `docs/reconciliation-status.md`.
7. Inspect the current branch/PR state.
8. If the task concerns production behavior, verify the relevant contract directly in Supabase.

## Collaboration rule

AI sessions are collaborators, not independent owners.

If another AI has committed work:

- inspect the commit and diff;
- understand why it exists;
- compare it with live evidence;
- preserve correct work;
- fix only demonstrated problems.

Never overwrite another AI's work merely because your implementation differs.

## Evidence hierarchy

For production behavior, when sources disagree:

1. Direct live Supabase evidence.
2. Confirmed deployed runtime behavior.
3. Tested repository implementation.
4. Repository documentation.
5. Unverified notes or conversation history.

Document the conclusion.

## Change discipline

Prefer focused commits describing the actual change.

Avoid mixing unrelated schema, frontend, payment, deployment, and cleanup work.

## Production changes

Before production changes, identify:

- contract being changed;
- reason;
- affected files/database objects;
- test evidence;
- deployment plan;
- rollback/containment considerations.

No AI should silently perform destructive production work.

## Handoff format

Update `docs/AI_HANDOFF.md` when leaving material work for another AI:

### Completed
What changed.

### Verified
What was directly tested or confirmed.

### Pending
What still needs evidence.

### Blocked
What prevents the next step.

### Next action
The smallest logical next task.

## Definition of done

A commit is not automatically a completed feature.

Use:

- LIVE VERIFIED
- REPOSITORY
- RECONCILED
- TESTED
- DEPLOYED
- PENDING/UNVERIFIED

Only claim the strongest state supported by evidence.
