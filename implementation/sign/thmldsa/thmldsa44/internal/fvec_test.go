// Code generated from mode3/internal/pack_test.go by gen.go

package internal

import (
	"testing"

	common "github.com/cloudflare/circl/sign/internal/dilithium"
)

func TestFVecFrom(t *testing.T) {
	var v FVec
	var s1 VecL
	var s2 VecK

	for i := uint32(0); i < common.Q/2; i++ {
		s1[0][0] = i
		v.From(&s1, &s2)

		if i <= common.Q / 2 && int(v[0]) != int(i) {
			t.Logf("%f vs %d", v[0], i)
			t.Fatal()
		} else if i > common.Q / 2 && int(v[0]) != int(i) - common.Q {
			t.Fatal()
		}
	}
}

func TestFVecRound(t *testing.T) {
	var v FVec
	var s1 VecL
	var s2 VecK

	for i := uint32(0); i < common.Q/2; i++ {
		v[0] = 1.2
		v[1] = 3.6
		v[2] = -2.3

		v.Round(&s1, &s2)
		if s1[0][0] != 1 || s1[0][1] != 4 {
			t.Fatal()
		}
	}
}