# Threshold ML-DSA Implementation

This repository contains implementations from the research paper:

**"Efficient Threshold ML-DSA up to 6 parties"**
*Sofia Celi, Rafael del Pino, Thomas Espitau, Guilhem Niot, Thomas Prest*

## Warning

**These implementations are academic proof-of-concept prototypes, have not received careful code review, and are not ready for production use.**

## Structure

This repository includes the following implementation:

- **implementation**: *Threshold ML-DSA* implementation (our scheme) based on the [CIRCL](https://github.com/cloudflare/circl) library.
Note that we use only the needed functionality from CIRCL.

We additionally provide our benchmarking tools:

- **go-libp2p folder**: *Threshold ML-DSA* was evaluated with [go-libp2p](https://github.com/libp2p/go-libp2p) for LAN/WAN experiments, see `go-libp2p/examples/chat`. Note that we include the codebase of go-libp2p with an example modified.
- **threshold-mldsa-bench folder**: *Threshold ML-DSA* local benchmarking tools.

We also include the parameter selection scripts:
- **params**: Parameter scripts for *Threshold ML-DSA*.

## Building and Testing

### Prerequisites

- Go 1.19 or later

### Building

On each folder (except `params`) run:

```
make build
```

### Testing

On `implementation` folder run:

```
make test
```

## Benchmarking

### Local Benchmarks

Navigate to the `threshold-mldsa-bench` directory and run:

```bash
cd threshold-mldsa-bench
go run main.go type=d iter=<iterations> t=<threshold> n=<parties>
```

**Parameters:**
- `iter`: Number of iterations to average latencies over (use 1 for single run)
- `t`: Threshold value (number of parties required to sign)
- `n`: Total number of parties (maximum 6 parties allowed)

**Example:**

```bash
# Run 100 iterations with threshold 3 out of 5 parties
go run main.go type=d iter=100 t=3 n=5
```

### Network Benchmarks (LAN/WAN)

Use the go-libp2p chat example for distributed experiments:

```bash
cd go-libp2p/examples/chat
go build
```

Then run on two different machines:
```bash
# On the first machine (server)
./chat -sp <PORT> -id 0

# On another machine (client)
./chat -d /ip4/<SERVER_IP>/tcp/<PORT>/p2p/<PEER_ID> -id 1
```