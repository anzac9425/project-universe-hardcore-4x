# Procedural System Generator Logic

This document prints the logic of the current deterministic star-system generator implementation.
It describes what each data model and generator stage does, in execution order.

## Core design rules

- The generator is deterministic.
- The generator is stateless.
- No `RandomNumberGenerator` state is used inside `MapGenerator`.
- All variability comes from semantic hash lookups such as `seed + "slot:4:ecc"`.
- The generator builds results in the order: **seed -> star -> disk -> orbital slots -> planets/belts -> moons -> analytic orbit state**.

## Data model summary

### `StarData`
Stores the derived stellar state:
- seed
- mass in solar masses
- luminosity in solar units
- temperature in kelvin
- radius in solar radii
- spectral type
- habitable zone bounds
- snow line
- hot zone

### `PlanetData`
Stores the derived planetary state:
- seed
- name
- type
- mass in Earth masses
- radius in Earth radii
- equilibrium temperature
- composition label
- full orbit
- moon list

### `MoonData`
Stores the derived moon state:
- seed
- name
- type
- mass
- radius
- temperature
- composition
- full orbit

### `AsteroidBeltData`
Stores the derived belt state:
- seed
- name
- orbit
- width
- mass
- dominant material
- resonance tag

### `OrbitData`
Stores orbital elements and analytic helpers:
- semi-major axis
- eccentricity
- inclination
- argument of periapsis
- longitude of ascending node
- mean anomaly at epoch
- period
- mean motion
- phase offset

It also exposes:
- `mean_anomaly_at_time(time_days)`
- `true_anomaly_at_time(time_days)`
- `radial_distance_au_at_time(time_days)`

### `SystemData`
Stores the generated system state:
- seed
- map position
- generated flag
- stars
- planets
- asteroid belts
- `get_bodies()` helper for planets + belts

## Execution flow

## 1. `generate_galaxy()`
`generate_galaxy()` creates a `GalaxyData` resource and fills it with system shells from `_generate_system_shell()`.

### `_generate_system_shell()`
This method places systems in a deterministic spiral-like shell:
- uses the index to compute a radial fraction
- adds small hash-derived radial and angular jitter
- rotates `Vector2.RIGHT`
- assigns a deterministic system seed with `derive_seed()`

This is not a simulation of galaxy formation.
It is a deterministic placement function that preserves reproducibility.

## 2. `generate_system(system)`
This is the top-level entry point for detailed system generation.

Steps:
1. exit early if the system is null or already generated
2. derive the star seed from the system seed
3. generate exactly one star with `_generate_star()`
4. generate planets and asteroid belts with `_generate_planetary_architecture()`
5. assign the typed result arrays back to `SystemData`
6. mark the system as generated

## 3. `derive_seed(parent, index)`
This creates a child seed from a parent seed and integer index.
It does not advance mutable state.
It hashes a semantic string like `seed:0`.

## 4. Hash functions

### `_hash_float(seed, key)`
Logic:
1. build a string `"seed:key"`
2. compute a SHA-256 hex digest
3. read the first 13 hex digits
4. convert them into a floating-point value in `[0, 1]`

This means every decision can be keyed independently.
Calling another function elsewhere does not perturb existing values.

### `_hash_int(seed, key)`
Converts the normalized float hash into a deterministic integer seed.

### `_hex_digit_value(codepoint)`
Converts ASCII hex codepoints into numeric digit values.

## 5. Star synthesis

### `_generate_star(star_seed)`
This function derives the star from mass rather than selecting a category first.

Steps:
1. sample stellar mass using `_sample_initial_mass_function()`
2. derive luminosity with `L ~ M^3.5`
3. derive radius with `R ~ M^0.8`
4. derive temperature from luminosity and radius
5. classify spectral type from temperature
6. derive thermal boundaries:
   - habitable zone inner edge
   - habitable zone outer edge
   - snow line
   - hot zone

## 6. IMF sampling

### `_sample_initial_mass_function(u)`
This approximates a broken power-law IMF using three mass ranges:
- 0.08 to 0.50 solar masses
- 0.50 to 1.00 solar masses
- 1.00 to 20.00 solar masses

Logic:
1. compute a weight for each segment with `_power_law_integral()`
2. normalize by total weight
3. locate which segment the input `u` lands in
4. sample inside the segment with `_sample_power_law()`

### `_sample_power_law(u, min_mass, max_mass, alpha)`
Inverse-CDF sampler for a power-law distribution.

### `_power_law_integral(min_mass, max_mass, alpha)`
Returns the analytic integral of the power-law.
Used to build segment weights.

## 7. Planetary architecture

### `_generate_planetary_architecture(system_seed, star)`
This function builds planets and skipped orbital slots from a deterministic disk model.

Steps:
1. choose a disk mass fraction between 1% and 10% of stellar mass
2. derive disk inner edge from the hot zone
3. derive disk outer edge from stellar snow line and stellar mass
4. choose a logarithmic orbit spacing factor from the seed
5. choose the first template radius from the seed
6. normalize the disk surface density with `_disk_sigma0()`
7. walk outward over orbital slots
8. evaluate each slot with `_evaluate_slot()`
9. apply a mutual Hill-gap correction against the previous planet if needed
10. create a `PlanetData` if the slot mass is large enough
11. otherwise keep the slot as a skipped region for later asteroid-belt evaluation
12. after the slot pass, run `_generate_asteroid_belts()`

The slot pass is deterministic and single-directional.
There is no orbital integration and no iterative N-body solve.

## 8. Slot evaluation

### `_evaluate_slot(...)`
This is the local accretion approximation.

Inputs:
- current star
- current orbital radius
- feeding-zone width
- normalized disk density
- disk edges

Steps:
1. derive a slot seed
2. compute the annulus inner and outer edge
3. compute ring mass from the disk profile
4. choose a solid fraction based on whether the slot is inside or outside the snow line
5. compute a thermal factor that suppresses material retention in hotter regions
6. compute a small turbulence factor from the seed
7. compute accretion efficiency
8. compute solid mass in Earth masses
9. compute core mass from solid mass times efficiency
10. if the slot is beyond most of the snow line, estimate gas capture
11. compute total planetary mass as core plus gas envelope contribution
12. compute equilibrium temperature from stellar luminosity and orbital radius
13. return a dictionary of local formation results

## 9. Planet creation

### `_create_planet(system_seed, slot_index, star, orbit, slot_data)`
Creates a `PlanetData` resource from the evaluated slot.

Steps:
1. derive a planet seed
2. assign a deterministic slot-based name
3. copy mass and temperature from slot evaluation
4. classify the planet with `_classify_planet_type()`
5. choose a composition label with `_planet_composition_label()`
6. derive radius with `_planet_radius_earth()`
7. assign the orbit resource

## 10. Planet classification logic

### `_classify_planet_type(...)`
Rules:
- large mass plus strong gas capture -> gas giant
- high mass outside most of the snow line -> ice giant
- beyond the snow line or cold enough -> ice world
- temperate and moderate mass -> ocean world
- otherwise -> rocky world

### `_planet_composition_label(...)`
Maps the derived type and temperature regime to a textual composition label.

### `_planet_radius_earth(...)`
Uses type-specific power laws / saturating curves:
- gas giants use a saturating radius curve
- ice giants use a weaker power law
- rocky/ocean/ice worlds use compact terrestrial scaling laws

## 11. Orbital elements

### `_build_orbit_data(system_seed, key, semi_major_axis, central_mass_solar, previous_planet)`
Builds full orbital elements for planets and belts.

Steps:
1. derive eccentricity from a strongly low-biased hash power law
2. damp eccentricity if the neighboring planet gap is narrow
3. derive inclination from a low-biased distribution near the disk plane
4. derive argument of periapsis
5. derive longitude of ascending node
6. derive mean anomaly at epoch
7. copy mean anomaly into `phase_offset_rad`
8. derive orbital period from Kepler's third law
9. derive mean motion from the period

### `_build_satellite_orbit(planet, orbital_radius_au, moon_seed)`
Same idea as planets, but centered on the planet mass for moon periods.
Moon eccentricities and inclinations are even more strongly damped.

## 12. Moon generation

### `_generate_moons(system_seed, star, planet)`
Generates moons deterministically for sufficiently massive planets.

Steps:
1. skip tiny planets
2. compute the Hill radius
3. compute the Roche limit with `_roche_limit_au()`
4. define valid moon space between `max(Roche, 3 x planet radius)` and `0.4 x Hill radius`
5. derive a moon mass budget from a hash
6. reduce that budget for rocky/ocean planets
7. choose moon spacing and starting orbit from hashes
8. estimate moon count from available radial space
9. decide whether the system gets a rare major moon from a hash threshold
10. build moon mass weights
11. place moons from inner to outer orbits
12. classify each moon with `_classify_moon_type()`
13. assign composition and radius
14. create the moon orbit with `_build_satellite_orbit()`

### `_classify_moon_type(...)`
Rules:
- flagged major moon with enough mass -> major moon
- cold environment -> ice moon
- temperate environment with enough mass -> ocean moon
- otherwise -> rocky moon

### `_moon_composition_label(...)`
Maps moon type to a composition label.

### `_moon_radius_earth(...)`
Uses compact moon radius scaling with a small icy-body inflation factor.

## 13. Asteroid belts

### `_generate_asteroid_belts(system_seed, star, planets, skipped_slots)`
Builds belts from failed accretion regions.

Steps:
1. examine every skipped slot
2. compute resonance strength with `_strongest_resonance()`
3. require enough leftover solids
4. allow belt formation when resonance is meaningful or the thermal regime still allows debris retention
5. assign belt width, mass, material, and resonance tag
6. assign a full orbit to the belt

### `_strongest_resonance(radius_au, planets)`
Checks only gas giants and ice giants.
It compares the skipped slot radius against simple resonance families:
- 2:1
- 3:2
- 5:2

It returns the strongest match and its tag.

## 14. Physics/math helpers

### `_equilibrium_temperature_k(luminosity_solar, distance_au)`
Computes blackbody-style equilibrium temperature.

### `_disk_sigma0(disk_mass_solar, inner_au, outer_au)`
Normalizes the `r^-1.5` disk profile so integrated mass matches the chosen disk mass.

### `_disk_ring_mass(sigma0, inner_au, outer_au)`
Returns the mass in a specific annulus.

### `_orbit_zone_width(semi_major_axis, spacing_factor)`
Computes the feeding-zone width implied by the logarithmic spacing template.

### `_mutual_hill_radius_au(...)`
Computes the mutual Hill radius used by the stability gap check.

### `_roche_limit_au(planet)`
Computes the approximate Roche limit for moon placement.
It uses a density-ratio adjustment that is lower for dense rocky/ocean worlds.

## 15. Analytic orbit state

### `OrbitData.mean_anomaly_at_time(time_days)`
Returns linearly advanced mean anomaly.

### `OrbitData.true_anomaly_at_time(time_days)`
Uses a low-order analytic approximation to convert mean anomaly into true anomaly.
This avoids iterative Kepler solving.

### `OrbitData.radial_distance_au_at_time(time_days)`
Uses the conic-section radius formula with the approximated true anomaly.

## 16. Logging

### `LogManager.log_system_data(system)`
Prints:
- system seed and body counts
- star summary (type, mass, temperature, radius, luminosity, habitable zone, snow line)
- planet summary (seed, type, mass, radius, temperature, semi-major axis, eccentricity, moon count)
- belt summary (seed, mass, semi-major axis, width, resonance)

## 17. What this version does not do

- no binary or multiple-star generation
- no N-body simulation
- no time-stepped orbital integration
- no atmosphere or geology simulation
- no planet migration model
- no tidal evolution model
- no exact Kepler solve iteration

## 18. Why the version is deterministic

The implementation is deterministic because:
- all derived variability comes from hash functions with explicit semantic keys
- no mutable RNG state is advanced
- there is no stored simulation history
- time-based position is computed analytically from orbital elements

Given the same inputs, this version rebuilds the same star system every time.
