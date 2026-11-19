# Nutrition engine / محرك تغذية الماعز — v0.1

## Scope
- Offline arithmetic is accounting, not ration formulation. There are no embedded feed tables or animal requirements.
- All values are explicitly entered or documented as unavailable. The "reference" selector on a target does not verify bibliographic quality.
- No water/minerals/vitamins recommendations without verified species-and-state-specific references.
- Consult a local veterinarian/ruminant nutritionist before feeding.

## Units and formulas
- As-fed kilogram: measured offered ration mass, water included.
- DM kg = as-fed kg × dry-matter percent / 100. DM must be >0 and ≤100%.
- ME MJ (metabolizable energy) = DM kg × ME MJ/kg DM.
- CP kg = DM kg × crude-protein percent of DM / 100.
- NDF kg = DM kg × NDF percent of DM / 100.
- Totals sum feed contributions only when all relevant component analyses are available. If a feed is missing NDF, total NDF is unknown, not a partial total.
- Goals are manually entered min/max ranges in the same units; no silent unit conversion.
- Matching DM, ME, CP and NDF does not certify a complete or safe ration.

## Guards
- Reject non-finite, zero/negative offered amounts, invalid DM, max-daily (user) limits exceeded.
- Reject inconsistent energy systems; UI currently accepts ME in MJ/kg DM only.
- Treat missing energy/protein/NDF as unknown. Never substitute invented coefficients.
- Warn for missing source, targets and lack of water, minerals and vitamins.
- Target stage must match selected animal stage.
- User-entered feed limits are constraints, not science-based maximum recommendations.
- Feed stock is a recorded inventory cap, not a biological feeding limit.
- Intake and targets are not automatically adjusted for environment, water, pregnancy or milk; user needs a specialist to select proper goals.

## Test fixtures
All numeric examples in test/ration_calculator_test.dart are synthetic fixtures, never feed analyses or reference requirements.

## Database
SQLite schema version 2 is for the new standalone application. Tables: nutrition_animal_profiles, nutrition_feed_analyses, nutrition_targets, animals, feeds, rations, ration_items. Foreign keys enabled. Animal deletion cascades to nutrition records and ration history; feed deletion cascades to its analysis but ration item snapshots remain. This schema is not compatible with the unprovided v6 release without a tested importer.

## Backlog
1. Vet-verified reference library with bibliographic metadata.
2. Analysis editing and version history, distinguish label/lab/user.
3. Validated multi-constraint ration solver after scientific constraints exist.
4. Offline database backup/restore validation.
5. Detailed water and mineral models only with documented sources.
6. Comparison and export reports with references.
7. UI/widget/integration/database migration tests.
