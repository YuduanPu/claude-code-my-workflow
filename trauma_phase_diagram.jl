# =====================================================================
# Phase diagrams: WHICH t=0 population structures polarize?
# Companion to trauma_simulations_main.jl and trauma_network_sim.jl.
#
# *** PROPORTION MODEL (sec. 5A / sec. 7). ***
# The urge target now responds to the SHARE of the diet that is triggering, not
# the absolute count. In the mean-field (own signal dropped as O(1/N)) the share
# phi(alpha) is EXACTLY independent of community size N. Consequence, drawn below:
#   - Phase diagram 1 (history x network imbalance) is qualitatively unchanged:
#     polarization still needs the flare basin AND an imbalanced listener.
#   - Phase diagram 2 (history x SIZE) goes FLAT along the size axis: size no
#     longer decides anything. We overlay the OLD count-model boundary (dashed)
#     to show what disappeared -- the count model's "small N heals / large N
#     self-ignites" slope is gone.
#
# Method (deterministic mean-field backbone):
#   - `basin`     : iterate the SIZE-FREE urge law of motion to its steady state.
#   - `basinCount`: the OLD count-model basin (size-dependent), for the contrast.
#   - `driftA`    : expected per-period log-odds step of an A-side normal. Sign>0
#                   => belief -> A (WRONG, truth=B); sign<0 => belief -> B (truth).
#   - `finalmu`   : turn that drift into a long-run belief.
# =====================================================================

import Pkg
Pkg.add("Plots"); Pkg.add("Statistics")
using Plots, Statistics

# ---- primitives (identical calibration to trauma_simulations_main.jl) ----
gamma, sigma, q = 0.95, 0.10, 0.70      # arrival rate, baseline share rate, signal quality
delta, lambda, alphahat = 0.20, 1.364, 0.05   # LOM speed, reactivity (size-free band), perceived urge
kappa, a0, rho0 = 80.0, 0.55, 0.02      # sigmoid sorting steepness, tipping urge, link floor
thetaA = 0.30                           # population share of type-A carriers
beta   = (1 - thetaA)*rho0/thetaA       # composition ratio D_o/(N-1): SIZE-FREE

# log-likelihood weight of a seen signal, and of a partisan's silence
L  = log(q/(1-q))
sA = log((1 - gamma*sigma - gamma*q*alphahat) /
         (1 - gamma*sigma - gamma*(1-q)*alphahat))                 # silence weight, < 0
psame(a) = rho0 + (1 - rho0)/(1 + exp(-kappa*(a - a0)))            # within-type link prob (sigmoid)
Tfun(x)  = (1 - sigma)*(1 - exp(-lambda*x))                        # urge target given exposure x

# fuel rates under truth B: trigger = a (scarce), anti = b (abundant)
rB_t, rB_o = gamma*(1 - q), gamma*q

# ---------------------------------------------------------------------
# (1) SIZE-FREE basin.  phi(a) = a-share of the diet (mean-field, own signal
#     dropped). D_A=(N-1)*psame(a), D_o=beta*(N-1): the (N-1) cancels, so this
#     basin does NOT depend on N at all.  rt,ro = trigger/anti-trigger fuel.
# ---------------------------------------------------------------------
function phi(a, rt, ro)
    bt = (sigma + a)*psame(a) + sigma*beta
    bo = sigma*psame(a)       + sigma*beta
    (rt*bt)/(rt*bt + ro*bo)
end
function basin(seed, rt, ro; iters = 800)
    a = seed
    for _ in 1:iters
        a = (1 - delta)*a + delta*Tfun(phi(a, rt, ro))
    end
    return a
end

# ---------------------------------------------------------------------
# (1b) OLD count-model basin (size-DEPENDENT), kept only to draw the contrast
#      boundary on phase diagram 2.  Uses the original count calibration knobs
#      that produced the size dependence: target T(m) with m the absolute count.
# ---------------------------------------------------------------------
psameCount(a)   = rho0 + (1 - rho0)/(1 + exp(-12.0*(a - 0.30)))    # old kappa=12, a0=0.30
function basinCount(seed, Ncomm, r; iters = 800)
    a = seed; c0 = r*1.3
    for _ in 1:iters
        a = (1 - delta)*a + delta*(1 - sigma)*(1 - exp(-0.105*( r*(sigma + a)*(Ncomm - 1)*psameCount(a) + c0 )))
    end
    return a
end

# ---------------------------------------------------------------------
# (2) Drift of an A-side normal's belief, truth = B. nA type-A friends (urge aA),
#     nB type-B friends (urge aB), n0 normal friends + own signal. drift > 0 =>
#     she ends up believing A (the FALSE state).
# ---------------------------------------------------------------------
# NOTE: normal friends share at baseline sigma (per sec.2), so the honest signal
# term weights them by sigma -- own signal (weight 1) is the only full-strength
# unbiased source.  [Corrects the (n0+1) full-weight slip in the draft's sec.6A.]
function driftA(nA, nB, n0, aA, aB)
    signal = -gamma*(2q - 1)*(1 + sigma*(nA + nB + n0)) +
              gamma*((1 - q)*nA*aA - q*nB*aB)
    SA = nA*(1 - gamma*sigma - gamma*(1 - q)*aA)
    SB = nB*(1 - gamma*sigma - gamma*q*aB)
    return signal*L + sA*(SA - SB)
end
finalmu(f; T = 300) = 1/(1 + exp(-clamp(T*f, -700, 700)))

aB = basin(0.40, rB_o, rB_t)         # B-community: trigger = b (abundant under B) -> flares
println("size-free urges:  alo=", round(basin(0.0, rB_t, rB_o), digits=3),
        "  ahi=", round(basin(0.85, rB_t, rB_o), digits=3), "  aB(flare)=", round(aB, digits=3))

# =====================================================================
# PHASE DIAGRAM 1 — history x network imbalance  (proportion model)
#   x: nA = # same-side (type-A) friends ;  y: alpha_A(0) = initial urge (history)
#   color: A-side long-run belief, 0 = truth B, 1 = polarized to A
# =====================================================================
nB, n0 = 2, 3
nA_grid   = 0:1:50
urge_grid = 0.0:0.01:0.90

M1 = [ finalmu(driftA(nA, nB, n0, basin(u, rB_t, rB_o), aB)) for u in urge_grid, nA in nA_grid ]

heatmap(collect(nA_grid), collect(urge_grid), M1,
    c = cgrad([:navy, :white, :firebrick]), clims = (0, 1),
    xlabel = "same-side friends  n_A   (n_B = $nB)  -->  network imbalance",
    ylabel = "initial urge  alpha_A(0)   -->  history",
    title  = "Who polarizes?  (proportion model, truth = B, q = $q)",
    colorbar_title = "long-run belief in A  (0 = truth, 1 = polarized)",
    size = (900, 640), dpi = 600)
contour!(collect(nA_grid), collect(urge_grid), M1, levels = [0.5],
         linecolor = :black, linewidth = 2)
annotate!(40, 0.78, text("POLARIZED\n(A-side certain & wrong)", :white, 9, :center))
annotate!(12, 0.20, text("CONSENSUS\n(learns the truth)",       :white, 9, :center))
savefig("trauma_phase_history_x_network")

# =====================================================================
# PHASE DIAGRAM 2 — history x community size  (proportion model)
#   SOLID boundary = proportion model: FLAT in N (size is irrelevant; only the
#   initial urge, i.e. HISTORY, decides which basin).
#   DASHED boundary = OLD count model: sloped (small N can't flare, large N self-
#   ignites). The contrast is the result of sec. 5A.
# =====================================================================
nA_fix, nB_fix = 16, 2
size_grid = 20:4:300

# proportion model: basin ignores N, so each column is identical -> flat boundary
M2 = [ finalmu(driftA(nA_fix, nB_fix, n0, basin(u, rB_t, rB_o), aB))
       for u in urge_grid, N in size_grid ]
# old count model belief, for the dashed contrast contour
M2count = [ finalmu(driftA(nA_fix, nB_fix, n0,
                           basinCount(u, N, rB_t),
                           basinCount(0.40, N, rB_t)))
            for u in urge_grid, N in size_grid ]

heatmap(collect(size_grid), collect(urge_grid), M2,
    c = cgrad([:navy, :white, :firebrick]), clims = (0, 1),
    xlabel = "community size  N_A",
    ylabel = "initial urge  alpha_A(0)   -->  history",
    title  = "Size is now IRRELEVANT  (proportion model, network 16:2, truth = B)",
    colorbar_title = "long-run belief in A  (0 = truth, 1 = polarized)",
    size = (900, 640), dpi = 600)
contour!(collect(size_grid), collect(urge_grid), M2, levels = [0.5],
         linecolor = :black, linewidth = 2)                       # flat: history only
contour!(collect(size_grid), collect(urge_grid), M2count, levels = [0.5],
         linecolor = :black, linewidth = 2, linestyle = :dash)    # OLD count-model slope
annotate!(150, 0.82, text("PROPORTION (solid): flat -> size irrelevant", :black, 8, :center))
annotate!(150, 0.06, text("COUNT (dashed): sloped -> size mattered",     :black, 8, :center))
savefig("trauma_phase_history_x_size")

# ---- console summary ----
println("Phase diagram 1 (proportion):  polarization still needs BOTH the flare basin")
println("  (initial urge above ~0.50) AND an imbalanced listener (n_A above threshold).")
println("Phase diagram 2 (proportion):  the boundary is FLAT in N -- community size no")
println("  longer decides anything. The dashed line is the OLD count model, whose slope")
println("  (small N heals, large N self-ignites) is exactly what the share removes.")
