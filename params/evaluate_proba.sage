from sage.all import *
from dataclasses import dataclass, field
from sage.misc.prandom import choice, randrange
from sage.doctest.util import Timer

@dataclass(repr=False)
class MLDSAParams:
    q: int
    n: int
    k: int
    ell: int
    tau: int
    eta: int
    d: int
    omega: int
    gamma1: int
    gamma2: int

    beta: int = field(init=False)

    def __post_init__(self):
        self.beta = self.tau * self.eta

q = 8380417
params_mldsa_44 = MLDSAParams(q=q, n=256, k=4, ell=4, tau=39, eta=2, d=13, omega=80, gamma1=2**17, gamma2=(q-1)/88)

R.<t> = PolynomialRing(ZZ)

def decompose(r, alpha, q):
    r = r % q
    r0 = r % alpha
    if r0 > alpha / 2:
        r0 -= alpha
    
    if r - r0 == q-1:
        r1 = 0
        r0 = r0 - 1
    else:
        r1 = (r-r0) // alpha
    return (r1,r0)

def highbits(r, alpha, q):
    r1, r0 = decompose(r, alpha, q)
    return r1

def MakeHint(z, r, alpha, q):
    r1 = highbits(r, alpha, q)
    v1 = highbits(r+z, alpha, q)
    return int(r1 != v1)

def MakeHintv(z, r, alpha, q):
    h = []
    for i in range(len(z)):
        for (zi, ri) in zip(z[i].coefficients(sparse=False), r[i].coefficients(sparse=False)):
            h.append(MakeHint(zi, ri, alpha, q))
    return h

def normpolyv(v):
    """
    norm vector of polynomials
    """
    s = 0
    for vi in v:
        s = max(s, max([abs(u) for u in vi.coefficients()]))
    
    return s

def evaluate_proba_success(random_distr, params: MLDSAParams):
    nbsamples = 100
    m_norminf_r1 = []
    m_norminf_r2mct0 = []
    m_nonzero_h = []

    for _ in range(nbsamples): # run the measurements many times for more accuracy
        # Sample the signing randomness and split it in two
        r = random_distr((params.k+params.ell) * params.n)
        r1 = r[:params.ell * params.n]
        r2 = r[params.ell * params.n:]
        # Sample a random challenge
        S = Subsets(range(params.n), params.tau).random_element()
        c = sum([choice([-1,1]) * t^k for k in S])
        # Step 1: Compute norm inf of r1, this has to be lower than gamma1-beta in the end...
        m_norminf_r1.append(max([abs(v) for v in r1]))

        # Step 2: Evaluate probability of success for the second part (hint must have less than omega 1's, and infinite norm must be less than gamma2)
        r2 = [sum([r2[j*params.n + a]*t^a for a in range(params.n)]) for j in range(params.k)]

        # At this point ignore r1, and heuristically assume that w is roughly uniformly distributed conditionned on r2
        w = [sum([randrange(q)*t^a for a in range(params.n)]) for j in range(params.k)]
        # Sample t_0, the lower bits of the public key, should be roughly distributed as below
        t0 = [sum([randrange(-2**(params.d-1), 2**(params.d-1))*t^a for a in range(params.n)]) for j in range(params.k)]

        v = [(r2[i]-c*t0[i]).mod(t^params.n+1) for i in range(params.k)]
        h = MakeHintv(v, w, 2*params.gamma2, params.q)

        m_norminf_r2mct0.append(normpolyv(v))
        m_nonzero_h.append(sum(h))

    return {
        "checknorminf_r1": float(sum([int(v < params.gamma1 - params.beta) for v in m_norminf_r1]) / nbsamples),
        "checknorminf_r2mcto": float(sum([int(v <= params.gamma2) for v in m_norminf_r2mct0]) / nbsamples),
        "checkhint": float(sum([int(v <= params.omega) for v in m_nonzero_h]) / nbsamples),
    }
