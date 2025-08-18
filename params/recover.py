import itertools
from math import comb, ceil
from scipy.sparse import csr_array
from scipy.sparse.csgraph import maximum_flow

def compute_maxflow_graph(N, T):
    secrets = list(itertools.combinations(range(N), N-T+1))

    # source is 0
    # exit is 1
    def id_user(i):
        return i + 2
    def id_secret(secret):
        return N + 2 + secrets.index(secret)
    
    l = 2 + N + len(secrets)
    weights = [[0]*l for _ in range(l)]

    # add flow to users
    for i in range(T): 
        weights[0][id_user(i)] = ceil(comb(N, T-1)/T)

    # add flow out of secrets
    for secret in secrets: 
        weights[id_secret(secret)][1] = 1

    # add flow between users and secrets
    for secret in secrets: 
        for user in secret:
            weights[id_user(user)][id_secret(secret)] = 1

    # compute ideal assignation of secrets
    graph = csr_array(weights)
    flow = maximum_flow(graph, 0, 1)
    
    assignment = {i: set() for i in range(T)}
    for i in range(T):
        for secret in secrets:
            if flow.flow[id_user(i),id_secret(secret)] == 1:
                assignment[i].add(secret)
    
    return assignment

sols = {}
for N in range(1, 6+1):
    for T in range(2, N):
        sols[(N,T)] = compute_maxflow_graph(N,T)

def final_distribute(act, N):
    act = list(act)
    act.sort()

    p = act + [i for i in range(N) if i not in act]
    sol0 = sols[(N, len(act))]
    return {p[x]: [set([p[i] for i in v]) for v in sol0[x]] for x in sol0}

for N in range(1, 6+1):
    for T in range(2, N):
        secrets = list(itertools.combinations(range(N), N-T+1))

        for act in itertools.combinations(range(N), T):
            act = set(act)
            d = final_distribute(act, N)

            assert(max([len(d[x]) for x in d]) <= ceil(comb(N, T-1)/T))
            assert(sum([len(d[x]) for x in d]) == comb(N, T-1))


# Print solutions, formatting sets of signers as uint8
def secret_to_uint8(secret):
    u = 0
    for s in secret:
        u |= 1 << s
    return u

for N in range(1, 6+1):
    for T in range(2, N):
        final_sol = [[] for _ in range(T)]
        for i in sols[(N,T)]:
            for j in sols[(N,T)][i]:
                # final_sol[i].append(j)
                final_sol[i].append(secret_to_uint8(j))
        print(T, N, final_sol)
