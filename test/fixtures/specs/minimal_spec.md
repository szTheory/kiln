# Minimal kiln spec

```kiln-scenario
scenarios:
  - id: smoke
    description: always passes
    steps:
      - kind: assert
        expect: "true"
```

```kiln-scenario
scenarios:
  - id: smoke-two
    description: second block merge
    steps:
      - kind: assert
        expect: "true"
```
