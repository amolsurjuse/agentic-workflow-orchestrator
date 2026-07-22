# Global Driver Charger Discovery

## Goal

Make regional demo stations discoverable to every ElectraHub driver without
turning a nearby-map request into a worldwide, high-latency query. The first
regional expansion covers India and Singapore.

## Regional Inventory

| Country | City | Location | Chargers | Connector IDs | Currency |
| --- | --- | --- | ---: | --- | --- |
| India | Pune | ElectraHub Pune Koregaon Park | 5 | `CON-IN-0001` to `CON-IN-0005` | INR |
| India | New Delhi | ElectraHub Delhi Connaught Place | 5 | `CON-IN-0006` to `CON-IN-0010` | INR |
| India | Bengaluru | ElectraHub Bengaluru Indiranagar | 5 | `CON-IN-0011` to `CON-IN-0015` | INR |
| India | Mumbai | ElectraHub Mumbai Bandra Kurla Complex | 5 | `CON-IN-0016` to `CON-IN-0020` | INR |
| Singapore | Singapore | ElectraHub Singapore Marina Bay | 5 | `CON-SG-0001` to `CON-SG-0005` | SGD |

The fleet contains 25 chargers and one connector per charger. Each regional
connector has an active local-currency tariff, including energy, time, idle,
and session-fee components. India tariffs cap charging at INR 5,000 and idle
fees at INR 500. Singapore tariffs cap charging at SGD 100 and idle fees at
SGD 50.

## Data and Service Flow

1. Liquibase in `pricing-service` creates the INR and SGD tariffs.
2. Liquibase in `charger-management-service` creates the enterprise, network,
   locations, charger inventory, EVSE inventory, and connector inventory.
3. The charger-management reindexer publishes inventory to the
   `ocpi-connectors` Elasticsearch index.
4. The public GraphQL discovery query, `ocpiChargers`, reads the index and
   supplies country, city, address, coordinates, connector availability, and
   pricing.
5. `ocpp-simulator` explicitly seeds and connects the 25 regional charger IDs,
   allowing the OCPP status overlay to present them as usable chargers rather
   than stale inventory records.

## Driver Discovery Rules

- **Nearby** remains a geo-filtered request based on the device location or map
  camera. It is intentionally local for speed and relevance.
- **Global search** uses `ocpiChargers(search: ...)` without device latitude or
  longitude. A driver in the United States can search for `Pune`, `Mumbai`,
  `Singapore`, a charger ID, or a connector ID and receive the correct result.
- **Regional browse** on iOS exposes an **Explore** menu in the map navigation
  bar. It switches the map to an explicit Europe or Asia market set, fits the
  camera to the returned stations, and refreshes that same market without a
  device-location filter. Returning to **Nearby** restores GPS-scoped
  discovery. A delayed GPS update must never overwrite a user's selected
  market.
- Driver result cards display the street address, city, and ISO country code so
  similarly named locations are distinguishable.
- iOS and Android both use the same GraphQL contract. The web driver portal has
  no charger-discovery/map feature at the time of this change.

## Security and Scope

This change exposes only the existing public charger discovery data. It does
not make cross-border settlement or payment conversion claims. A driver can
inspect a charger and its local tariff in another country; starting a session
continues to follow the existing payment, currency, and eligibility rules.

## Validation

After deployment, verify:

```graphql
query {
  ocpiChargers(countryCode: "IN", limit: 30) {
    chargerId
    chargerName
    status
    location { name address city }
    pricing { tariffs { currency energyPrice timePrice parkingPrice flatFee } }
  }
}
```

Expected result: 20 India chargers.

```graphql
query {
  ocpiChargers(search: "Singapore", limit: 10) {
    chargerId
    status
    location { name address city }
  }
}
```

Expected result: five Singapore chargers, with a live OCPP status after the
simulator reconciliation loop has run.

On iOS, open **Explore > Asia** and verify that Pune, New Delhi, Bengaluru,
Mumbai, and Singapore stations appear without changing the device location.
Open **Explore > Europe** and verify that the European demo locations appear.
Return to **Explore > Nearby** and verify that GPS-scoped discovery resumes.
On Android, search `Pune`, select a result, and confirm the map centers on the
station and shows INR pricing. Repeat with `Singapore` and confirm SGD.
