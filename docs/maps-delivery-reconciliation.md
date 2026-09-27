# Nile Tropical — Street Maps & Delivery Reconciliation

Status: REPOSITORY IMPLEMENTATION / PRODUCTION DEPLOYMENT PENDING

## Implemented

- Customer address/landmark search is available.
- Configured applications route geocoding through the Supabase location-search Edge Function.
- Configured applications route road calculations through the Supabase route Edge Function.
- Development/unconfigured builds retain direct Photon/OSRM fallback.
- Customer can request browser/device current location.
- Android foreground location permissions are declared.
- iOS foreground location usage text is declared.
- Customer destination marker is draggable.
- Moving the destination marker invalidates the previous route and delivery quote.
- Road distance and duration are calculated from the selected coordinates.
- quote_delivery remains the authoritative delivery-price calculation.
- Geographic delivery-zone resolution contract has been added using configurable zone center/radius metadata.
- Existing delivery-zone names, fees and records are not changed by the migration.
- Flutter Map network tile caching is explicitly enabled through NetworkTileProvider.
- OSM attribution remains visible on the map.

## Production gates

1. Deploy the two map Edge Functions to the production Supabase project.
2. Configure and review geographic metadata for each active delivery zone. Do not invent coordinates or radii.
3. Decide and document the long-term map-tile provider and its usage limits before high-volume public launch. The current OSM tile endpoint is suitable for controlled testing; production use must follow the tile provider's policy.
4. Run customer checkout tests:
   - address search
   - current location
   - draggable pin
   - route recalculation after pin movement
   - authoritative delivery quote
   - order creation with route snapshots
5. Run admin delivery tests:
   - route display
   - quote
   - external map handoff
   - courier/shipment workflow.
6. Verify the production Edge Functions and database migration separately before marking LIVE VERIFIED.

## Important architectural rule

Client-side coordinates, distance and route data are navigation inputs/snapshots only. The server remains authoritative for delivery-zone eligibility, delivery fee, order totals, stock and payment state.
