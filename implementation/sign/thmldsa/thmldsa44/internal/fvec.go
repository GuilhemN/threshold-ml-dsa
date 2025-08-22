// Code generated from mode3/internal/vec.go by gen.go

package internal

import (
	"math"
	common "github.com/cloudflare/circl/sign/internal/dilithium"
)

// A vector of L polynomials.
type FVec [common.N*(K+L)]float64

// Sets v to w + u.
func (v *FVec) Add(w, u *FVec) {
	for i := 0; i < common.N*(K+L); i++ {
		v[i] = w[i] + u[i]
	}
}

// Sets v to [s1 s2].
func (v *FVec) From(s1 *VecL, s2 *VecK) {
	var u int32
	for i := 0; i < L + K; i++ {
		for j := 0; j < common.N; j++ {
			// First centers u mod Q
			if i < L {
				u = int32(s1[i][j])
			} else {
				u = int32(s2[i-L][j])
			}

			u += common.Q/2
			t := u - common.Q
			u = t + int32((t >> 31) & common.Q);
			u = u - common.Q/2

			// convert to float
			v[i * common.N + j] = float64(u)
		}
	}
}

// Sets v to [s1 s2].
func (v *FVec) Round(s1 *VecL, s2 *VecK) {
	var u int32
	for i := 0; i < L + K; i++ {
		for j := 0; j < common.N; j++ {
			u = int32(math.Round(v[i * common.N + j]))

			// Adds +Q if it is <0
			t := u >> 31;
			u = u + (t & common.Q);

			if i < L {
				s1[i][j] = uint32(u)
			} else {
				s2[i-L][j] = uint32(u)
			}
		}
	}
}

// Check if norm 2 of v is larger than bound.
func (v *FVec) Excess(r float64, nu float64) bool {
	var sq float64
	for i := 0; i < L + K; i++ {
		for j := 0; j < common.N; j++ {
			if i < L {
				sq += v[i * common.N + j] * v[i * common.N + j] / (nu * nu)
			} else {
				sq += v[i * common.N + j] * v[i * common.N + j]
			}
		}
	}

	return sq > r * r
}
