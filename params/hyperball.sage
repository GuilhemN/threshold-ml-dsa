from math import comb
import numpy as np
from sage.doctest.util import Timer
from sage.all import *
from dataclasses import dataclass, field
from sage.misc.prandom import choice, randrange
from sage.doctest.util import Timer



#####################################
####### Parameters for MLDSA ########
#####################################
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
    sigt: float = field(init=False)

    def __post_init__(self):
        self.beta = self.tau * self.eta
        self.sigt = sqrt(((2*self.eta+1)**2-1)/12)



###############################
####### Basic Functions #######
###############################

R.<t> = PolynomialRing(ZZ)

def polylist_to_vector(poly_list,n=256):
    coeff_arrays = np.concatenate([(p.coefficients(sparse=False))+[0]*(n-p.degree()-1) for p in poly_list])
    return coeff_arrays

def polylist_to_vector_sparse(poly_list):
    coeff_arrays = np.concatenate([np.array(p.coefficients()) for p in poly_list ], dtype=np.int64)
    return coeff_arrays


def infinity_norm_polynomials(poly_list,n=256):
    coeff_arrays = polylist_to_vector_sparse(poly_list)
    return np.max(np.abs(coeff_arrays))

def vector_to_polynomials_numpy(v,dim):
    k = dim // 256
    return [R(v[i*256:(i+1)*256].tolist()) for i in range(k)]

def sample_polynomials(k,n,b1,b2):
    coeffs = np.random.randint(b1, b2, size=(k, n), dtype=np.int64)  # Fast uniform sampling
    return [R(list(row)) for row in coeffs]  # Convert each row to a polynomial

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

#def highbits(r, alpha, q):
    r1, r0 = decompose(r, alpha, q)
    return r1

def highbits(r, alpha, q):
    r = r % q
    r0 = r % alpha
    if r0 > alpha / 2:
        r0 -= alpha
    if r - r0 == q-1:
        return 0
    return (r-r0) // alpha

def MakeHint(z, r, alpha, q):
    r1 = highbits(r, alpha, q)
    v1 = highbits(r+z, alpha, q)
    return int(r1 != v1)

def MakeHintv(z, r, alpha, q):
    h = []
    for i in range(len(z)):
        for (zi, ri) in zip(z[i].coefficients(sparse=False)+[0]*(255-z[i].degree()), r[i].coefficients(sparse=False)+[0]*(255-r[i].degree())):
            h.append(MakeHint(zi, ri, alpha, q))
    return h

def MakeHintvsize(z, r, alpha, q):
    h = 0
    for i in range(len(z)):
        for (zi, ri) in zip(z[i].coefficients(sparse=False)+[0]*(255-z[i].degree()), r[i].coefficients(sparse=False)+[0]*(255-r[i].degree())):
            h+= MakeHint(zi, ri, alpha, q)
    return h


###################################
####### Sampling functions ########
###################################



#def sample_ball(radius, dim):
    x = np.random.normal(size=dim+2)
    s = np.linalg.norm(x)
    fact=(radius/s)
    return fact*(x[:-2])

def sample_ball_imbalanced(radius, fact,params: MLDSAParams):
    x = np.random.normal(size=(params.k+params.ell)*params.n+2)
    s = np.linalg.norm(x)
    ratio=(radius/s)
    res = ratio*(x[:-2])
    return [res[:params.ell*params.n] * fact, res[params.ell*params.n:(params.k+params.ell)*params.n]]


def sample_ball_int(radius, fact,params: MLDSAParams):
    [s1,s2]=sample_ball_imbalanced(radius,fact, params)
    #print("s ", s[:10]," ", type(s), " ", s.shape)
    return [np.rint(s1).astype(int), np.rint(s2).astype(int)]


def sample(T,radius,fact,params: MLDSAParams):
    v1 = np.zeros(params.ell*params.n, dtype=int)
    v2 = np.zeros(params.k*params.n, dtype=int)
    for _ in range(T):
        [v1_,v2_] = sample_ball_int(radius,fact, params)
        v1 += v1_
        v2 += v2_
    return [v1, v2]


##################################
####### Rejection sampling #######
##################################


def rej(T,N,sig_t,eta,M,fact,params:MLDSAParams):
    dim= (params.k+params.ell) * params.n
    slack = (1/eta + sqrt(1/eta**2 + M**(2/dim)-1)) / (M**(2/dim)-1)
    slackradius2 = M**(1/(dim))
    beta = 1.3 * sqrt((params.k+params.ell/fact**2) * params.n* ceil(comb(N, T-1) / T)) * sig_t * sqrt(params.tau)
    radius = slack*beta
    radius2 = slackradius2*radius
    return [radius.n(53),radius2.n(53)]



def evaluate_proba_success(random_distr,nbsamples, params: MLDSAParams):
    m_norminf_r1 = []
    m_norminf_r2mct0 = []
    m_nonzero_h = []

    for _ in range(nbsamples): # run the measurements many times for more accuracy
        # Sample the signing randomness and split it in two
        [r1,r2] = random_distr()
        S = Subsets(range(params.n), params.tau).random_element()
        c = sum([choice([-1,1]) * t^k for k in S])
        # Step 1: Compute norm inf of r1, this has to be lower than gamma1-beta in the end...
        m_norminf_r1.append(np.max(np.abs(r1)))

        # Step 2: Evaluate probability of success for the second part (hint must have less than omega 1's, and infinite norm must be less than gamma2)
        r2=vector_to_polynomials_numpy(r2,params.k*params.n)
        #r2 = [sum([r2[j*params.n + a]*t^a for a in range(params.n)]) for j in range(params.k)]

        # At this point ignore r1, and heuristically assume that w is roughly uniformly distributed conditionned on r2
        w= sample_polynomials(params.k, params.n,0,params.q)
        #w1 = [sum([randrange(q)*t^a for a in range(params.n)]) for j in range(params.k)]
        # Sample t_0, the lower bits of the public key, should be roughly distributed as below
        t0 = sample_polynomials(params.k, params.n,-2**(params.d-1),2**(params.d-1))
        #t0 = [sum([randrange(-2**(params.d-1), 2**(params.d-1))*t^a for a in range(params.n)]) for j in range(params.k)]
        v = [(r2[i]-c*t0[i]).mod(t^256+1) for i in range(params.k)]
        h = MakeHintvsize(v, w, 2*params.gamma2, params.q)
        m_norminf_r2mct0.append(infinity_norm_polynomials(v))
        m_nonzero_h.append(h)
    return {
        "checknorminf_r1": float(sum([int(v < params.gamma1 - params.beta) for v in m_norminf_r1]) / nbsamples),
        "checknorminf_r2mcto": float(sum([int(v <= params.gamma2) for v in m_norminf_r2mct0]) / nbsamples),
        "checkhint": float(sum([int(v <= params.omega) for v in m_nonzero_h]) / nbsamples),
    }






#####################################
####### Parameter evaluation ########
#####################################




def evaluate_params(T,N,eta,expo,fact,sig_t,nbsamples,params: MLDSAParams,verb=0):
    # compute bound on I_{1-1/\eta^2}((kn+1)/2,1/2)
    boundI = (1-1/eta**2)**((params.ell+params.k)*params.n-1)*(params.ell+params.k)*params.n*(1-1/eta)
    if verb:
        print("boundI", float(log(boundI,2)))
    p=1/2^expo
    M=(1/p)**(1/T)
    [rad,rad2]=(rej(T,N,sig_t,eta,M,fact,params))
    probas = evaluate_proba_success(lambda: sample(T,rad,fact,params),nbsamples, params)
    pfinal = p * probas["checknorminf_r1"] * probas["checknorminf_r2mcto"] * probas["checkhint"]
    if pfinal==0:
        print(f"T,N={int(T)},{int(N)}  p=1/2^{float(expo)}   fact={fact}  , accept proba too low")
    else:
        K=ceil(-1/log(1-pfinal,2))
        totalComm = 32
        totalComm += K * ceil(log(params.q, 2)) * params.k * params.n // 8
        totalComm += K * ceil(log(params.gamma1, 2)) * params.ell * params.n // 8
        print(f"T,N={int(T)},{int(N)}  p=1/2^{float(expo)}   fact={fact}    Com={float(totalComm)}")
        if verb:
            print(f"checknorminf_r1={probas['checknorminf_r1']}")
            print(f"checknorminf_r2mcto={probas['checknorminf_r2mcto']}")
            print(f"checkhint={probas['checkhint']}")
            print(f"pfinal={pfinal}")
            print(f"ptotal={(1-(1-pfinal)**K)}")
            print(f"rad={rad}")
            print(f"rad*fact={rad*fact}")
            print(f"rad2={rad2}")
            print(f"K={K}")


def evaluate_params_fixedK(T,N,eta,K,expo,fact,sig_t,nbsamples,params: MLDSAParams,verb=0):
    # compute bound on I_{1-1/\eta^2}((kn+1)/2,1/2)
    boundI = (1-1/eta**2)**((params.ell+params.k)*params.n-1)*(params.ell+params.k)*params.n*(1-1/eta)
    if verb:
        print("boundI", float(log(boundI,2)))
    p=1/2^expo
    M=(1/p)**(1/T)
    [rad,rad2]=(rej(T,N,sig_t,eta,M,fact,params))
    probas = evaluate_proba_success(lambda: sample(T,rad,fact,params),nbsamples, params)
    pfinal = p * probas["checknorminf_r1"] * probas["checknorminf_r2mcto"] * probas["checkhint"]
    if pfinal==0:
        print(f"T,N={int(T)},{int(N)}  p=1/2^{float(expo)}   fact={fact}  , accept proba too low")
    else:
        totalComm = 32
        totalComm += K * ceil(log(params.q, 2)) * params.k * params.n // 8
        totalComm += K * ceil(log(params.gamma1, 2)) * params.ell * params.n // 8
        print(f"T,N={int(T)},{int(N)}  p=1/2^{float(expo)}   fact={fact}    Com={float(totalComm)}")
        if verb:
            print(f"checknorminf_r1={probas['checknorminf_r1']}")
            print(f"checknorminf_r2mcto={probas['checknorminf_r2mcto']}")
            print(f"checkhint={probas['checkhint']}")
            print(f"pfinal={pfinal}")
            print(f"ptotal={(1-(1-pfinal)**K)}")
            print(f"rad={rad}")
            print(f"rad*fact={rad*fact}")
            print(f"rad2={rad2}")
            print(f"K={K}")





def find_params(T,N,eta,sig_t,nbsamples,emin,emax,estep,fmin,fmax,fstep,params: MLDSAParams,verb=0):
    best_exp=0
    best_factor=0
    best_p=0
    best_r1=0
    best_r2=0
    best_h=0
    best_rad=0
    best_rad2=0
    for expo in srange(emin,emax,estep):
        paccept=1/2^expo
        M = (1/paccept)**(1/T)
        slack = (1/eta + sqrt(1/eta**2 + M**(2/((params.k+params.ell)*params.n))-1)) / (M**(2/((params.k+params.ell)*params.n))-1)
        slackradius2 = M**(1/((params.k+params.ell)*params.n))
        for factor_enlarge_r1 in srange(fmin,fmax,fstep):
            beta = 1.3 * sqrt(params.n * (params.k + params.ell/factor_enlarge_r1**2) * ceil(comb(N, T-1) / T)) * sig_t * sqrt(params.tau)
            radius = (slack*beta).n(53)
            radius2 = (slackradius2*radius).n(53)
            probas = evaluate_proba_success(lambda: sample(T,radius,factor_enlarge_r1,params),nbsamples, params)
            pfinal = paccept * probas["checknorminf_r1"] * probas["checknorminf_r2mcto"] * probas["checkhint"]
            if pfinal>best_p:
                best_p=pfinal
                best_exp=expo
                best_factor=factor_enlarge_r1
                best_r1=probas["checknorminf_r1"]
                best_r2=probas["checknorminf_r2mcto"]
                best_h=probas["checkhint"]
                best_rad=radius
                best_rad2=radius2
    K=ceil(-1/log(1-best_p,2))
    totalComm = 32
    totalComm += K * ceil(log(params.q, 2)) * params.k * params.n // 8
    totalComm += K * ceil(log(params.gamma1, 2)) * params.ell * params.n // 8
    print(f"T,N={int(T)},{int(N)}  p=1/2^{best_exp}   factor={best_factor}   Com={totalComm}")
    if verb:
        print(f"checknorminf_r1={best_r1}")
        print(f"checknorminf_r2mcto={best_r2}")
        print(f"checkhint={best_h}")
        print(f"pfinal={best_p}")
        print(f"ptotal={(1-(1-best_p)**K)}")
        print(f"rad={best_rad}")
        print(f"rad2={best_rad2}")
        print(f"K={K}")

def gen_params(N, exptab,facttab, Ktab, eta, sig_t, params: MLDSAParams, verb=0):
    rads=[0]*(N-1)
    rads2=[0]*(N-1)
    comm=[32]*(N-1)
    for i in range(N-1):
        p=1/2^exptab[i]
        M=(1/p)**(1/(i+2))
        [rads[i],rads2[i]]=(rej(i+2,N,sig_t,eta,M,facttab[i],params))
        comm[i] += Ktab[i] * ceil(log(params.q, 2)) * params.k * params.n // 8
        comm[i] += Ktab[i] * ceil(1+log(params.gamma1, 2)) * params.ell * params.n // 8
    print("N=",N)
    print("rads=",rads)
    print("rads2=",rads2)
    print("fact=",facttab)
    print("comm=",comm)








########################################
####### Parameter sets for MLDSA #######
########################################


q = 8380417
sig_t = 1.4142135623730951

params_mldsa_44 = MLDSAParams(q=q, n=256, k=4, ell=4, tau=39, eta=2, d=13, omega=80, gamma1=2**17, gamma2=(q-1)/88)
eta44=7
params_mldsa_65 = MLDSAParams(q=q, n=256, k=6, ell=5, tau=49, eta=4, d=13, omega=55, gamma1=2**19, gamma2=(q-1)/32)
eta65=8
params_mldsa_87 = MLDSAParams(q=q, n=256, k=8, ell=7, tau=60, eta=2, d=13, omega=75, gamma1=2**19, gamma2=(q-1)/32)
eta87=9


exp2_44 = [ 1.3]
fac2_44 = [ 3]
K2_44 = [ 2]

exp3_44 = [ 1.5, 2]
fac3_44 = [ 3, 3]
K3_44 = [ 3, 4]

exp4_44 = [ 1.5, 2.5, 2.7]
fac4_44 = [ 3, 3, 3]
K4_44 = [ 3, 7, 8]

exp5_44 = [ 2, 3.5, 4.5, 3.5]
fac5_44 = [ 3, 3, 3, 3]
K5_44 = [ 3, 14, 30, 16]

exp6_44 = [1.9, 4, 5.5,5.7, 4.5]
fac6_44 = [3, 3, 3, 3,3]
K6_44 = [ 4, 19, 74, 100, 37]

exp2_65 = [ 1.9]
fac2_65 = [ 6]
K2_65 = [ 3]

exp3_65 = [ 2.5,2.8 ]
fac3_65 = [ 6, 6]
K3_65 = [ 5, 9]

exp4_65 = [ 2.5,4 , 4.4]
fac4_65 = [ 6, 6, 6]
K4_65 = [ 6, 20, 26]

exp5_65 = [ 3, 5.2, 7, 5.6]
fac5_65 = [ 6, 6, 6, 6]
K5_65 = [ 8, 62, 205, 78]

exp6_65 = [ 2.9, 6, 8.8, 9, 6.9]
fac6_65 = [ 6, 6, 6, 6, 6]
K6_65 = [ 8, 95, 804, 1200, 250]

exp2_87 = [1.6 ]
fac2_87 = [ 7]
K2_87 = [3 ]

exp3_87 = [ 1.8, 2.5]
fac3_87 = [ 8, 7]
K3_87 = [ 4, 6]

exp4_87 = [ 1.8, 3.1, 3.3]
fac4_87 = [ 7, 7, 7]
K4_87 = [ 4, 11, 14]

exp5_87 = [ 2.3, 4.2, 5.4, 4.3]
fac5_87 = [ 7, 7, 7, 7]
K5_87 = [ 5, 26, 70, 35]

exp6_87 = [ 2.1, 4.7, 7, 7.3, 5.7]
fac6_87 = [ 7, 7, 7, 7, 7]
K6_87 =   [ 5, 39, 208, 295, 87]


#evaluate_params(5,6,eta65,9,6,params_mldsa_65.sigt,2000,params_mldsa_65,verb=1)
#find_params(3,3,eta65,params_mldsa_65.sigt,2000,2.6,2.9,0.1,7,7.1,1,params_mldsa_65,verb=1)
#find_params(2,3,eta44,params_mldsa_44.sigt,2000,1.3,1.7,0.1,3,3.1,1,params_mldsa_44,verb=1)
#evaluate_params_fixedK(5,6,eta,K6[4],exp6[4],fac6[4],sig_t,1000,params_mldsa_44,verb=1)
gen_params(6,exp6_87,fac6_87,K6_87,eta87,params_mldsa_87.sigt,params_mldsa_87,verb=1)