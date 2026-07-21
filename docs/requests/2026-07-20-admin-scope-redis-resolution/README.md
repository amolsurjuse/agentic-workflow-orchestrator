# Administrative scope Redis resolution

## Request

Investigate and correct the `SERVICE_UNAVAILABLE` response returned to a system administrator from `GET /charger/api/v1/admin/enterprises`.

## Observed behavior

The API gateway successfully resolved the caller's administrative scope, then forwarded a signed version-2 access-context reference. Charger Management returned:

```text
Could not read the administrative access scope.
```

## Root cause

The version-2 context intentionally stores the scope in shared Redis rather than sending all hierarchy identifiers in the request header. The production Gateway was configured with the Redis password, but Charger Management was not. Redis requires authentication, so the downstream cache read failed and the resolver correctly avoided treating it as an authorization success.

## Resolution

Add `SPRING_DATA_REDIS_PASSWORD` to the Charger Management deployment from the existing Redis secret in both development and production. This restores the intended shared-cache design without weakening access controls or reverting to large inline scope headers.

## Validation

1. Rendered the production Helm release. The Deployment contains `SPRING_DATA_REDIS_PASSWORD` from `redis-prod-secret` without embedding a secret value.
2. Ran Helm lint successfully.
3. Synced production Argo CD application `charger-management-service-prod` to Git revision `c3d0cd1` and confirmed the replacement pod became ready.
4. Confirmed the replacement Deployment resolves `SPRING_DATA_REDIS_PASSWORD` from `redis-prod-secret/redis-password`.
5. Performed an in-cluster signed version-2 access-context probe using a short-lived Redis cache entry. `GET /api/v1/admin/enterprises?limit=1&offset=0` returned HTTP `200` with the expected paged enterprise data.

The probe used an opaque cache reference and expired automatically; no user token, password, or secret value was written to source control or operational logs.
