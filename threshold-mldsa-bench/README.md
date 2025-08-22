# Threshold ML-DSA

This is a Golang implementation of Threshold-ML-DSA, a practical threshold signature scheme from LWE.
It is a wrapping around the CIRCL library modified to support the threshold version.

**WARNING:** This implementation is an academic proof-of-concept prototype, has not received careful code review, and is not ready for production use.

### Codebase Overview

- `sign/`
    - `local.go`: Locally runs the scheme on a single machine for a given number of parties.
- `main.go`: Run the code with `go run main.go id iters parties` where `id` is the party ID of the signer running the code (use `l` if you want to run the scheme locally), `iters` is the number of iterations to average the latencies over if you are benchmarking (if not, just use 1), and `parties` is the total number of parties. This is currently a full-threshold implementation. For testing a smaller threshold, set the `Threshold` config parameter with a different value, and use `ShamirSecretSharingGeneral`.
