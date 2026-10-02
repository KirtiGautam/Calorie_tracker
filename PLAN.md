# Cal Tracker — Project Plan

iOS app that tracks macros from food (primarily via photo), with first-class support for Indian foods and meals, and compares intake against TDEE.

**Background:** fluent in Python + Postgres, some frontend experience; using this project to learn Go/Rust (and Swift).

---

## 1. Architecture

```
┌─────────────────┐   photo + auth    ┌──────────────────┐   image    ┌──────────────┐
│  iOS app        │ ────────────────▶ │  Backend API     │ ─────────▶ │ Vision LLM   │
│  (SwiftUI)      │ ◀──────────────── │  (Go or Rust)    │ ◀───────── │ (dish + qty) │
│  - camera       │   macros JSON     │  - auth          │            └──────────────┘
│  - HealthKit    │                   │  - dish matching │
│  - charts       │                   │  - TDEE math     │
└─────────────────┘                   └────────┬─────────┘
                                               │
                                          ┌────▼──────────────────────┐
                                          │ Postgres                  │
                                          │ (IFCT/INDB-seeded dishes, │
                                          │  personal recipes, logs)  │
                                          └───────────────────────────┘
```

## 2. iOS client — Swift + SwiftUI (native)

- **HealthKit**: read `basalEnergyBurned`, `activeEnergyBurned`, body weight.
- **Camera/Photos**: `PhotosPicker` / AVFoundation.
- **Swift Charts**: intake vs. TDEE graphs.
- Requirements: Mac + Xcode; Apple Developer account ($99/yr) for TestFlight and HealthKit entitlements. A free account works for personal device installs, but the app expires every 7 days.

## 3. Backend — Go (recommended) or Rust

The backend is required anyway, because the LLM API key can't be shipped in the app.

- **Go**: `chi` or `net/http`, `pgx`, `sqlc` (typed queries generated from SQL). Fastest path to shipping.
- **Rust**: `axum` + `sqlx` (compile-time-checked SQL). More of a learning project.
- Compromise: Go now, rewrite one service in Rust later as an exercise.

## 4. Indian food: the core challenge

USDA FoodData Central covers few Indian dishes, so nutrition data must come from Indian sources and the app must handle Indian meal patterns.

| Problem | Example | How to handle it |
|---|---|---|
| Mixed dishes, not single ingredients | Paneer butter masala, sambar, biryani | Use recipe-level nutrition data, not ingredient lookups |
| Oil and ghee vary a lot | The same dal can be 150 or 300 kcal per katori | Ask "oil level: light / normal / rich" on confirmation |
| Home-cooked vs. restaurant | Restaurant dal makhani has far more butter and cream | Add a source toggle that applies a multiplier |
| Household units, not grams | 1 katori, 2 rotis, 1 ladle, half plate rice | Store unit-to-gram conversions per dish |
| Thalis: many items on one plate | Dal + sabzi + rice + roti + raita + pickle | The LLM must return several items; the confirm screen lists each one |
| Regional names and spellings | Bhindi / okra / vendakkai; chole / chana masala | Keep an alias table with fuzzy search (`pg_trgm`) |

### Nutrition data sources

- **IFCT 2017** (Indian Food Composition Tables, ICMR's National Institute of Nutrition): the authoritative source for raw ingredients (atta, toor dal, paneer, ...). Distributed as a book/PDF, so it needs a one-time extraction (Python).
- **INDB (Indian Nutrient Databank)**: recipe-level data for about 1,000 common Indian dishes, built on IFCT. *Verify current availability and license before relying on it.*
- **Personal recipes**: your household's dishes, computed from IFCT ingredients. The most accurate source for home food.
- **USDA FDC**: fallback only, for non-Indian foods (oats, eggs, whey, ...).

## 5. Food recognition pipeline

1. **Photo → vision LLM** returns dishes in Indian units as structured JSON:
   ```json
   [{"dish": "dal tadka", "aliases": ["yellow dal"], "qty": 1, "unit": "katori", "oil_level": "normal"},
    {"dish": "phulka roti", "qty": 3, "unit": "piece"}]
   ```
2. **Match to the Postgres dish table** with `pg_trgm` fuzzy search on names and aliases. Personal recipes are matched first.
3. **Convert units → grams → macros**, then apply the oil-level and restaurant adjustments.
4. **Confirm/edit screen** with per-item steppers (katori/roti counts), an oil toggle, and swap-dish search. Always shown: photo portion estimates are often off by 20–40%.
5. **"My recipes"**: save your household's real dal/sabzi recipes, which override generic data.

Costs are a few cents per photo at most, which is negligible for personal use.

## 6. TDEE

From simplest to best long-term:

1. **Formula**: Mifflin-St Jeor BMR × activity multiplier. Works from day one.
2. **HealthKit**: basal + active energy from Apple Watch. Watches often overestimate active calories.
3. **Adaptive**: back-calculate actual TDEE from logged intake vs. smoothed weight trend over 2–3 weeks (1 kg ≈ 7700 kcal). The best option long-term.

Also show a **protein target** alongside calories, since vegetarian Indian diets often run low on protein.

## 7. Infra

- **Postgres**: Neon or Supabase (free tiers), or self-hosted.
- **Hosting**: Fly.io / Railway / small VPS with Docker. Use the Mumbai region (Fly `bom`, AWS `ap-south-1`) for latency.
- **Auth**: Sign in with Apple. The backend verifies the identity token and issues its own JWT.
- **Images**: don't store them initially (process and discard). Add Cloudflare R2/S3 later if history is wanted.

## 8. Schema (draft)

```sql
users(id, apple_sub, height_cm, birth_date, sex, activity_level)
weigh_ins(user_id, date, weight_kg)

dishes(id, name, source, kcal_100g, protein_100g, carbs_100g, fat_100g,
       default_oil_level, user_id NULL)              -- user_id set = personal recipe
dish_aliases(dish_id, alias, lang)                   -- GIN trigram index on alias
dish_units(dish_id, unit, grams)                     -- katori=150, piece=40, ...
recipe_ingredients(dish_id, ingredient_id, grams)    -- for personal recipes
oil_adjustments(level, extra_fat_g_per_100g)

food_logs(id, user_id, eaten_at, meal, source, is_restaurant)   -- source: photo|manual
food_log_items(log_id, dish_id, qty, unit, grams, oil_level,
               kcal, protein_g, carbs_g, fat_g, llm_confidence)

daily_energy(user_id, date, bmr_kcal, active_kcal)   -- synced from HealthKit
```

## 9. Build order

1. **Data first (Python)**: extract IFCT and INDB into Postgres; build alias and unit tables for the 50–100 most-eaten dishes.
2. **Backend (Go)**: dish search, manual logging, daily totals endpoint.
3. **SwiftUI app**: manual logging by katori/roti count, plus a daily summary against formula TDEE.
4. **Photo flow**: LLM → dish match → confirm screen with oil toggle.
5. **Evaluation set**: photograph about 30 of your own meals with known portions; measure error, tune the prompt, and compare LLMs on Indian dishes.
6. **Personal recipes**, then HealthKit sync, then adaptive TDEE and charts.

## 10. Deferred

- **Barcode scanning**: Open Food Facts is global, but its coverage of Indian packaged foods is thin. Revisit if coverage improves or a better source is found. (iOS VisionKit handles the scanning itself.)
