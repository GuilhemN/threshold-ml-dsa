// Code generated from mode3/internal/dilithium_test.go by gen.go

package internal

import (
	"encoding/binary"
	"io"
	"testing"

	common "github.com/cloudflare/circl/sign/internal/dilithium"
)

// Checks whether p is normalized.  Only used in tests.
func PolyNormalized(p *common.Poly) bool {
	p2 := *p
	p2.Normalize()
	return p2 == *p
}

func BenchmarkPkUnpack(b *testing.B) {
	var buf [PublicKeySize]byte
	var pk PublicKey
	for i := 0; i < b.N; i++ {
		pk.Unpack(&buf)
	}
}

func TestSignThenVerifyAndPkSkPacking(t *testing.T) {
	var (
		seed [common.SeedSize]byte
		sig  [SignatureSize]byte
		msg  [8]byte
		pkb  [PublicKeySize]byte
		skb  []byte
		pk2  PublicKey
		sk2  PrivateKey
		rnd  [32]byte
	)

	params := defaultThresholdParams()
	skb = make([]byte, params.PrivateKeySize())

	for i := uint64(0); i < 30; i++ {
		binary.LittleEndian.PutUint64(seed[:], i)
		pk, sks := NewThresholdKeysFromSeed(&seed, params)
		sk := &sks[0]
		if len(sks) != 1 || !sk.Equal(sk) {
			t.Fatal()
		}
		for j := uint64(0); j < 10; j++ {
			binary.LittleEndian.PutUint64(msg[:], j)
			SignTo(sk, func(w io.Writer) { _, _ = w.Write(msg[:]) }, rnd, sig[:])
			if !Verify(pk, func(w io.Writer) { _, _ = w.Write(msg[:]) }, sig[:]) {
				t.Fatal()
			}
		}
		pk.Pack(&pkb)
		pk2.Unpack(&pkb)
		if !pk.Equal(&pk2) {
			t.Fatal()
		}
		sk.Pack(skb)
		sk2.Unpack(skb)
		if !sk.Equal(&sk2) {
			t.Fatal()
		}
	}
}

func TestThSignMultiKeys(t *testing.T) {
	subTestThSignMultiKeys(t, [2]uint8{0, 1})
	// subTestThSignMultiKeys(t, [2]uint8{0, 2})
	// subTestThSignMultiKeys(t, [2]uint8{1, 2})
}

func subTestThSignMultiKeys(t *testing.T, signerSet [2]uint8) {
	act := uint8((1 << signerSet[0]) | (1 << signerSet[1]))
	var (
		seed [common.SeedSize]byte
		sig  [SignatureSize]byte
		msg  [8]byte
		rhop [64]byte
	)
	for i := uint64(0); i < 20; i++ {
		binary.LittleEndian.PutUint64(seed[:], i)
		params, err := GetThresholdParams(2, 3)
		if err != nil {
			t.Fatal(err)
		}
		pk, sks := NewThresholdKeysFromSeed(&seed, params)

		// Add the sks to sign
		msgWriter := func(w io.Writer) { _, _ = w.Write(msg[:]) }

		// Sign separately
		success := false
		for attempts := uint16(0); attempts < 200; attempts++ {
			w1, stw1 := GenThCommitment(&sks[signerSet[0]], rhop, attempts, params)
			w2, stw2 := GenThCommitment(&sks[signerSet[1]], rhop, attempts, params)
			AggregateCommitments(w1, w2)

			mu := ComputeMu(&sks[0], msgWriter)
			z1s := ComputeResponses(&sks[signerSet[0]], act, mu, w1, stw1, params)
			z2s := ComputeResponses(&sks[signerSet[1]], act, mu, w1, stw2, params)
			AggregateResponses(z1s, z2s)
			ret3 := Combine(pk, msgWriter, w1, z1s, sig[:], params)
			if !ret3 {
				continue
			}

			if !Verify(pk, msgWriter, sig[:]) {
				t.Fatal("invalid signature produced")
			}

			t.Log(attempts)
			success = true
			break
		}

		if !success {
			t.Fatal("failed to produce valid signature")
		}
	}
}

func TestGamma1Size(t *testing.T) {
	var expected int
	switch Gamma1Bits {
	case 17:
		expected = 576
	case 19:
		expected = 640
	}
	if expected != PolyLeGamma1Size {
		t.Fatal()
	}
}
