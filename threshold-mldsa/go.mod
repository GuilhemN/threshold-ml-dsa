module threshold-mldsa

go 1.22.0

toolchain go1.24.0

replace github.com/cloudflare/circl => ../circl-main

require (
	github.com/cloudflare/circl v1.6.0
	github.com/montanaflynn/stats v0.7.1
)

require golang.org/x/sys v0.21.0 // indirect
