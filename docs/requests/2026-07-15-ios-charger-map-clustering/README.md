# iOS Charger Map Clustering

## Request

Improve the iOS charger map where dense charger coordinates produced a clumsy vertical stack of overlapping availability markers around Philadelphia.

## Production Data Findings

The charger API returns one charger record per physical charger. The iOS GraphQL adapter correctly groups chargers by `ocpiLocationId`, producing one map station per physical site.

The Philadelphia demo fleet currently contains:

- 40 chargers;
- 8 physical sites;
- 5 chargers at each site coordinate;
- sites separated by approximately 2 km along a generated diagonal coordinate pattern.

The eight site coordinates range from `39.9606, -75.1732` to `40.0656, -75.0682`. Rendering all eight site annotations independently at regional zoom caused the overlapping column visible in the reported screenshots.

## Design

The map now clusters physical sites according to their screen footprint at the current camera span:

- wide regional view: nearby physical sites render as a compact circular cluster;
- cluster marker: displays site count and available/total connector count;
- cluster tap: zooms to bounds containing its sites;
- close view: individual site availability pins reappear;
- individual pin tap: preserves the existing station-detail navigation;
- native Apple EV charger POIs are hidden to avoid duplicating Electra Hub annotations.

The source coordinates remain authoritative and are not altered by the client. Clustering is presentation-only and also protects the UI when legitimate production sites are geographically dense.

## Validation

The clustering calculation was exercised against the eight live Philadelphia site coordinates:

| Approximate visible radius | Cluster result |
|---:|---:|
| 100 km | 1 cluster containing 8 sites |
| 44 km | 2 clusters containing 4 sites each |
| 10 km | 8 individual site markers |
| 5 km | 8 individual site markers |

- [x] Live charger coordinates inspected through production GraphQL.
- [x] Chargers confirmed to be grouped by physical OCPI location before map rendering.
- [x] Zoom-aware clustering implemented.
- [x] Cluster-to-site zoom interaction implemented.
- [x] Duplicate native EV charger POIs removed.
- [x] Change pushed to iOS `develop`: `736aee5`.
- [ ] Compile and visually verify through an Apple/Xcode environment.
