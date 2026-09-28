# AER_SHARED_PIPELINE v1

## Frozen dependency graph

```text
External canonical inputs
          ↓
       adapters
          ↓
       producers
          ↓
      publishers
          ↓
       products
      ┌────┴─────┐
      ↓          ↓
CALIPSO_STATS   CCN_GRID
  ↓     ↓          ↓
Ch4    Ch5      CCN plots
```

## Directory contract

```text
code      reproducible logic
products  formal immutable shared products only
runs      staging, application artifacts and logs
plots     products or consumer artifacts; no shared scientific production
```

External data remain at their canonical roots listed in `inputs/input_roots.yaml`. Existing published products under `F:\AER_RETRA_CASE` are not moved in this initialization step.
