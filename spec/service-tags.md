# Camino Messenger Service Tags Specification

## Overview

This specification defines a tagging scheme for Camino Messenger Protocol services
to distinguish between different message routing patterns and service types. The
tags follow a similar pattern to NatSpec's custom tags but are specifically designed
for protobuf service definitions.

## Tag Format

The tag follows this format:

```protobuf
/// @custom:cmp-service type:{TYPE} routing:{PATTERN} [on-chain:{true|false}] [structure:{VERSION}]
service ServiceName {
  // service definition
}
```

## Service Types

The `type` tag identifies the fundamental nature of the service:

- `core` - Essential protocol services (e.g., ping, network fee)
- `product` - Product related services (e.g., booking, search, notification,
  cancellation).
- `system` - System-level services (e.g., health checks, metrics)

> [!NOTE]
> Notifications and cancellation services also fall under `product` type because
> they relate to the product, even if they do not directly communicate between
> partners via the messenger server.

## Service Routing Patterns

The `routing` tag defines the message routing pattern:

- `p2p` - Partner-to-Partner communication via messenger server (e.g., search, booking)
- `local` - Partner-to-Bot communication without server routing (e.g., notification, cancellation)

## Service Blockchain Interaction

The `on-chain` tag indicates whether the service interacts with the blockchain in any
way. Possible values are `true` and `false`, with `false` as the default if the tag is
omitted.

- `false` - For services that **do not** interact with the blockchain (e.g., search, list, info)
- `true` - For services that involve any on-chain interaction, including read or
  write actions (e.g., listening for events, minting, cancellation)

## Structure Version

The `structure` tag identifies which version of the structure the service uses. This
is independent of the protobuf package version and indicates significant structural
changes in how requests and responses are formatted. The value is an integer
representing the structure version.

- **Default**: `1` (if tag is omitted)
- **Values**: Any positive integer (1, 2, 3, ...)

> [!NOTE] 
> This tag is primarily used by code generators to produce compatible code
> for each structure variant. If the tag is not specified, the service is assumed to
> use structure version `1`.

## Examples

### P2P Product Service (in package cmp.services.accommodation.v2)

```protobuf
/// @custom:cmp-service type:product routing:p2p structure:2
service AccommodationSearchService {
  rpc AccommodationSearch(AccommodationSearchRequest) returns (AccommodationSearchResponse);
}
```

### Local Service (in package cmp.services.notification.v1)

```protobuf
/// @custom:cmp-service type:product routing:local on-chain:true structure:1
service NotificationService {
  rpc TokenBoughtNotification(TokenBought) returns (google.protobuf.Empty);
  rpc TokenExpiredNotification(TokenExpired) returns (google.protobuf.Empty);
}
```

### Core System Service (in package cmp.services.ping.v1)

```protobuf
/// @custom:cmp-service type:core routing:p2p on-chain:false structure:1
service PingService {
  rpc Ping(PingRequest) returns (PingResponse);
}
```

## Implementation Implications

### Code Generation

The tags can be used by code generators to:

1. Generate appropriate routing logic based on pattern
2. Apply different validation rules
3. Implement pattern-specific error handling
4. Add pattern-specific logging/monitoring
5. Generate client/server stubs with appropriate configurations

### Documentation

These tags should be:

1. Required for all service definitions
2. Validated via CI

### Validation Rules

Required attributes:

- Every service must have a `@custom:cmp-service` tag
- The tag must include both `type` and `routing` attributes
- `routing` must be one of the defined patterns
- `type` must be one of the defined types

Optional attributes:

- `structure` - If omitted, defaults to `1`. If provided, must be a positive integer
- `on-chain` - If omitted, defaults to `false`. If provided, must be `true` or `false`

## Migration Guide

To add tags to existing services:

1. Analyze the service's current usage pattern
2. Determine appropriate type and pattern
3. Add tags above service definition
4. Update any code generation scripts
5. Test generated code for correct routing

## Best Practices

1. Always include both required attributes (type and routing)
2. Keep attributes in same order for consistency, first `type` then `routing`
3. Document tag selection rationale in comments
4. Review tag assignments during service updates
5. Include tags in service review process
6. Keep the tag on a single line above the service
