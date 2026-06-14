# =====================================================================
# Trauma-and-Polarization simulations  (extension of BDG)
# Style mirrors BDG_simulations_main.ipynb (Bowen, Dmitriev, Galperti).
#
# Model differences from BDG:
#   - probabilistic sharing: baseline rate sigma for everyone; a type-A
#     carrier over-shares a-news with extra urge alpha (type-B over-shares b).
#   - the urge alpha is TIME-VARYING: it adjusts toward a target set by how
#     much triggering news the carrier was exposed to (law of motion below).
#   - the friend network among PARTISANS is ENDOGENOUS: same-type linking
#     probability rises with the community's average urge. We use a SIGMOIDAL
#     (tipping) link probability: sparse when calm, a convex take-off near an
#     inflection a0, then saturating below 1. The convex take-off is what
#     creates multiplicity; the saturation keeps p a valid probability for ANY
#     steepness kappa (a LINEAR rho0+h+kappa*alpha would exceed 1 once
#     kappa > (1-rho0-h)/(1-sigma) ~ 1, which is why the band was so narrow).
#   - the listener is a NORMAL agent (tau=0) with a FIXED friend network. The
#     flare reaches her only through the INTENSIVE margin (her existing type-A
#     friends get louder, alpha rises); her friend COUNTS never change. This
#     isolates the new alpha-alphahat channel from BDG's friend-imbalance one.
#   - the listener stays Bayesian but is misspecified: she uses a constant
#     perceived urge alphahat < alpha (BDG's gammahat<gamma channel, here with
#     the identification gammahat = gamma*alphahat when sigma=0).
#
# Run cell-by-cell in IJulia/Jupyter, as the original replication file.
#
# Truth is fixed to omega = B throughout the belief simulations, so Pr(a)=1-q.
# Headline: with ONE information quality q, a community in the "healing" basin
# learns the truth while a community in the "flare-up" basin converges to A.
# =====================================================================

import Pkg
Pkg.add("Plots")
Pkg.add("Distributions")
Pkg.add("Statistics")
Pkg.add("StatsBase")
Pkg.add("Random")

using Plots
using Distributions
using Statistics
using StatsBase
using Random

# Setting the random seed (same as BDG)
Random.seed!(19013)

# =====================================================================
# Parameters and primitives
# =====================================================================

gamma = 0.95          # firsthand news arrival rate
sigma = 0.10          # baseline sharing rate (everyone); ceiling on urge is 1-sigma
q = 0.70              # information quality (FIXED across both basins below)
p = 0.5               # common prior on state A

# Trauma law of motion: alpha_{t+1} = (1-delta) alpha_t + delta * T(phi_t; lambda)
# *** PROPORTION model (sec. 5A): the urge target now responds to the SHARE of the
#     diet that is triggering, NOT the absolute count. The share is size-free, so the
#     flare-up condition no longer scales with community size N (sec. 5A, sec. 7). ***
delta = 0.20          # healing / adjustment speed
lambda = 1.364        # trigger sensitivity (CENTERED in the size-free omega=B bistable band)
alphahat = 0.05       # listener's CONSTANT perceived urge (<= healing urge: under-perceives)

# Sigmoidal same-type (partisan-partisan) link probability:
#   p_same(alpha) = rho0 + (1-rho0) / (1 + exp(-kappa*(alpha - a0)))
# rho0 = floor (calm network), kappa = sorting steepness, a0 = tipping point.
# NOTE: under the proportion model bistability is HARDER (the share is bounded below
# by Pr(a|B)=1-q), so it needs STRONGER sorting: kappa ~ 80 here vs ~12 in the old
# count model.  This is the honest cost of size-invariance (sec. 5A).
NthetaA = 80          # type-A community size (now affects NOTHING -- see phi below)
rho0 = 0.02           # baseline link probability (network when the community is calm)
kappa = 80.0          # flare-driven sorting steepness (sharp tipping)
a0 = 0.55             # inflection / tipping urge of the sorting curve
thetaA = 0.30         # population share of type-A carriers
beta = (1 - thetaA)*rho0/thetaA   # composition ratio D_o/(N-1): outside diet, SIZE-FREE

# Listener's FIXED, exogenous friend network (a NORMAL, A-leaning agent).
# These counts do NOT move with the flare (concern-#2 fix: intensive margin only).
# Re-tuned for the proportion model so the belief-flip threshold sits BETWEEN the
# two (compressed) urge basins alo~0.45 and ahi~0.57.
nA_L = 16             # type-A friends (fixed)
nB_L = 2              # type-B friends (fixed)
n0_L = 3              # normal friends  (her own signal is added as one more source)

# Mean-field DIET of a representative type-A carrier, truth omega = B:
#   triggering = a-signals (fuel rate r);  non-triggering = b-signals (fuel rate ranti).
r     = gamma * (1 - q)                   # = gamma * Pr(a | B)   (a-fuel: the trigger)
ranti = gamma * q                         # = gamma * Pr(b | B)   (b-fuel: anti-trigger)

# Sigmoidal link probability
logit(a)  = 1.0 / (1.0 + exp(-kappa*(a - a0)))
psame(a)  = rho0 + (1 - rho0)*logit(a)
DA(a)     = (NthetaA - 1)*psame(a)        # expected same-type degree (reporting only)

# Triggering SHARE of the diet at community urge a (mean-field, own signal dropped as
# O(1/N)).  D_A = (N-1)*psame(a), D_o = beta*(N-1): the (N-1) cancels in the ratio, so
# phi -- and hence every steady state below -- is EXACTLY independent of N.
#   bt = a-inflow per (N-1): same-type over-share (sigma+a) + outside relays sigma*beta
#   bo = b-inflow per (N-1): every friend relays b at baseline sigma
function phi(a; rt = r, ro = ranti)
    bt = (sigma + a)*psame(a) + sigma*beta
    bo = sigma*psame(a)       + sigma*beta
    return (rt*bt) / (rt*bt + ro*bo)
end

# Bounded target urge and the steady-state map Phi (Phi' by finite difference)
Tfun(x) = (1 - sigma)*(1 - exp(-lambda*x))
Phi(a)  = Tfun(phi(a))
Phip(a) = (Phi(a + 1e-6) - Phi(a - 1e-6)) / 2e-6

# Sanity check: the same-type link probability must stay a valid probability
println("max same-type link prob p_same(1-sigma) = ", round(psame(1 - sigma), digits=3), "  (must be <= 1)")

# =====================================================================
# PART A. Steady-state map and the three equilibria  (truth omega = B)
# =====================================================================

agrid = range(0.0, 1 - sigma, length = 4001)
gap = [Phi(a) - a for a in agrid]          # zeros of this are the steady states

eqs = Float64[]
for k in 1:1:(length(agrid) - 1)
    if gap[k]*gap[k+1] < 0
        push!(eqs, 0.5*(agrid[k] + agrid[k+1]))   # crossing of the 45-degree line
    end
end

println("Equilibria (alpha* with Phi(alpha*) = alpha*): ", round.(eqs, digits=4))
for a in eqs
    stab = Phip(a) < 1 ? "stable" : "unstable"
    println("   alpha* = ", round(a, digits=4),
            "   Phi' = ", round(Phip(a), digits=3),
            "   (", stab, ")   same-type degree DA = ", round(DA(a), digits=1))
end

diagonal = collect(agrid)
plot(agrid, [Phi.(agrid) diagonal],
    label = ["Phi(alpha)" "45-degree line"],
    linecolor = [:blue :black], linestyle = [:solid :dash],
    xlabel = "Community urge alpha", ylabel = "Phi(alpha)",
    legend = :topleft, size = (800,600), dpi = 600)
scatter!(eqs, eqs, label = "equilibria", markercolor = :red, markersize = 6)
savefig("trauma_phi_map")

# =====================================================================
# PART A1. STATE-DEPENDENT MULTIPLICITY TEST  (Concern #1)
#   The urge is fed by TRIGGERING (a-) signals, whose supply is
#       r_omega = gamma * Pr(a | omega):   r_A = gamma*q  >  r_B = gamma*(1-q).
#   The same-q divergence story needs the BINDING state omega = B to be
#   BISTABLE (a healing AND a flare-up basin, so history selects which one).
#   Multiplicity is a BAND in lambda, not a single threshold: below it the
#   community always heals; above it it always flares (even when wrong).
# =====================================================================

# regime at (lam,kap, rt,ro):  :monolow, :bistable, or :monohigh.  Proportion model:
# rt = trigger fuel (gamma*Pr(a|omega)), ro = anti-trigger fuel (gamma*Pr(b|omega)).
function regime(lam, kap, rt, ro; ng = 6001)
    ps(a) = rho0 + (1 - rho0)/(1 + exp(-kap*(a - a0)))
    function ph(a)
        bt = (sigma + a)*ps(a) + sigma*beta
        bo = sigma*ps(a)       + sigma*beta
        (rt*bt)/(rt*bt + ro*bo)
    end
    P(a) = (1 - sigma)*(1 - exp(-lam*ph(a)))
    ag = range(0.0, 1 - sigma, length = ng)
    g  = [P(a) - a for a in ag]
    h  = 1e-6
    S = Float64[]
    for k in 1:(ng - 1)
        if g[k]*g[k+1] <= 0
            ac = ag[k]
            ((P(ac+h) - P(ac-h))/(2h) < 1) && push!(S, ac)
        end
    end
    length(S) >= 2 && return :bistable
    isempty(S) && return (g[end] > 0 ? :monohigh : :monolow)
    return S[1] > 0.5*(1 - sigma) ? :monohigh : :monolow
end

# trigger / anti-trigger fuel under each truth (A-community: trigger = a-signals)
rA_t, rA_o = gamma*q,     gamma*(1 - q)   # omega = A : a-signals abundant
rB_t, rB_o = gamma*(1-q), gamma*q         # omega = B : a-signals scarce (binding case)
println("Chosen (lambda, kappa, a0) = ($lambda, $kappa, $a0)")
println("  omega = A : ", regime(lambda, kappa, rA_t, rA_o))
println("  omega = B : ", regime(lambda, kappa, rB_t, rB_o), "   <-- MUST be :bistable for the result")

lamscan = range(0.5, 2.5, length = 4000)
bandB = [l for l in lamscan if regime(l, kappa, rB_t, rB_o) == :bistable]
if isempty(bandB)
    println("WARNING: omega = B is NOT bistable at kappa = $kappa for any lambda in [0.5,2.5].")
else
    lo, hi = minimum(bandB), maximum(bandB)
    println("omega = B bistable band at kappa = $kappa:  lambda in (",
            round(lo, digits=3), ", ", round(hi, digits=3), ")   width = ",
            round(hi - lo, digits=3), "  rel-width = ", round((hi - lo)/(0.5*(lo+hi)), digits=2))
    (lo <= lambda <= hi) ? println("   chosen lambda = $lambda is INSIDE the band. OK.") :
                           println("   NOTE: chosen lambda = $lambda is OUTSIDE the band.")
end

# (lambda, kappa) map of the omega = B regime; dashed line = omega = A bistable boundary
lamg = range(0.5, 2.0, length = 160)
kapg = range(0.0, 120.0, length = 160)
codeB = [regime(l, k, rB_t, rB_o) == :bistable ? 1.0 :
        (regime(l, k, rB_t, rB_o) == :monohigh ? 0.5 : 0.0) for k in kapg, l in lamg]
heatmap(lamg, kapg, codeB,
    c = cgrad([:white, :gold, :firebrick]), clims = (0, 1),
    xlabel = "reactivity lambda", ylabel = "network sorting kappa",
    title = "omega=B regime (proportion model): white=heals, gold=BISTABLE, red=always-flares",
    colorbar = false, size = (820, 620), dpi = 600)
bistA = [regime(l, k, rA_t, rA_o) == :bistable ? 1.0 : 0.0 for k in kapg, l in lamg]
contour!(lamg, kapg, bistA, levels = [0.5], linecolor = :black, linestyle = :dash)
scatter!([lambda], [kappa], markercolor = :blue, markersize = 6, label = "chosen")
savefig("trauma_state_dependent_region")

# =====================================================================
# PART A2. Trauma dynamics: convergence to the two basins  (truth omega = B)
#   alpha_{t+1} = (1-delta) alpha_t + delta * Phi(alpha_t)
# =====================================================================

T = 300

apath_heal = zeros(T+1, 1)
apath_heal[1] = 0.20                       # starts below the unstable threshold (~0.50) -> heals
apath_flare = zeros(T+1, 1)
apath_flare[1] = 0.75                      # starts above the threshold -> flares up

for t in 1:1:T
    apath_heal[t+1]  = (1 - delta)*apath_heal[t]  + delta*Phi(apath_heal[t])
    apath_flare[t+1] = (1 - delta)*apath_flare[t] + delta*Phi(apath_flare[t])
end

plot([apath_heal apath_flare],
    label = ["alpha_0 = 0.20  (heals)" "alpha_0 = 0.75  (flares up)"],
    linecolor = [:blue :red], linestyle = [:solid :solid],
    ylims = [0,1], xlabel = "Period, t", ylabel = "Community urge alpha_t",
    legend = :right, size = (800,600), dpi = 600)
savefig("trauma_alpha_dynamics")

# =====================================================================
# PART B. Belief evolution at each stable equilibrium (truth = B)
#   Same q for both; the listener's network is FIXED; only the urge differs.
# =====================================================================

# generalized silence weight (BDG's Gammahat, now carrying sigma and alphahat)
Ghat = (1 - gamma*sigma - gamma*q*alphahat) / (1 - gamma*sigma - gamma*(1-q)*alphahat)

N = 10000
alo = eqs[1]                # healing equilibrium urge (A-community)
ahi = eqs[end]             # flare-up equilibrium urge (A-community)

# B-community urge under truth B: its trigger (b-signals) is ABUNDANT (rate gamma*q),
# so it flares.  swap the fuel rates in phi (trigger = b now): rt = ranti, ro = r.
PhiB(a)  = Tfun(phi(a; rt = ranti, ro = r))
aB_comm  = 0.5
for _ in 1:800; global aB_comm = (1 - delta)*aB_comm + delta*PhiB(aB_comm); end
println("B-community flare urge (truth B) = ", round(aB_comm, digits=3))

# ----- one belief path: A-friends at urge urgeA, B-friends at urge urgeB -----
function simulate_beliefs(urgeA, urgeB)
    mu = zeros(T+1, N); mu[1,:] = p*ones(1, N)
    for i in 1:1:N
    for t in 1:1:T
        # type-A friends (fixed count nA_L): over-share a with prob sigma+urgeA, share b with prob sigma
        sA = rand(Binomial(nA_L, gamma)); aA = rand(Binomial(sA, 1-q)); bA = sA - aA
        shAa = rand(Binomial(aA, sigma + urgeA)); shAb = rand(Binomial(bA, sigma)); silA = nA_L - shAa - shAb
        # type-B friends (fixed count nB_L): share a with prob sigma, over-share b with prob sigma+urgeB
        sB = rand(Binomial(nB_L, gamma)); aB = rand(Binomial(sB, 1-q)); bB = sB - aB
        shBa = rand(Binomial(aB, sigma)); shBb = rand(Binomial(bB, sigma + urgeB)); silB = nB_L - shBa - shBb
        # normal friends (fixed count n0_L): share each with prob sigma
        sn = rand(Binomial(n0_L, gamma)); an = rand(Binomial(sn, 1-q)); bn = sn - an
        shna = rand(Binomial(an, sigma)); shnb = rand(Binomial(bn, sigma))
        # own firsthand signal (always observed if received)
        og = rand(Binomial(1, gamma)); oa = rand(Binomial(og, 1-q)); ob = og - oa

        na = shAa + shBa + shna + oa            # total a-signals seen
        nb = shAb + shBb + shnb + ob            # total b-signals seen

        mu[t+1,i] = mu[t,i] / (mu[t,i] + (1 - mu[t,i]) *
            ((1-q)/q)^(na - nb) * Ghat^(silB - silA))
    end
    end
    return mu
end

muvec_heal  = simulate_beliefs(alo, aB_comm)
muvec_flare = simulate_beliefs(ahi, aB_comm)

avg_heal = zeros(T+1, 1); a10_heal = zeros(T+1, 1); a90_heal = zeros(T+1, 1)
avg_flare = zeros(T+1, 1); a10_flare = zeros(T+1, 1); a90_flare = zeros(T+1, 1)
for t in 1:1:(T+1)
    avg_heal[t] = mean(muvec_heal[t,:]); a10_heal[t] = quantile!(muvec_heal[t,:], 0.1); a90_heal[t] = quantile!(muvec_heal[t,:], 0.9)
    avg_flare[t] = mean(muvec_flare[t,:]); a10_flare[t] = quantile!(muvec_flare[t,:], 0.1); a90_flare[t] = quantile!(muvec_flare[t,:], 0.9)
end

println("Truth is B.  Healing basin  (urge ", round(alo, digits=3), ")  mu_T = ", round(avg_heal[T+1], digits=3), "  (correct ~ 0)")
println("Truth is B.  Flare-up basin (urge ", round(ahi, digits=3), ")  mu_T = ", round(avg_flare[T+1], digits=3), "  (WRONG ~ 1)")

plot_data = [avg_heal a10_heal a90_heal avg_flare a10_flare a90_flare]
plot_labels = ["Average, healing" "10%, healing" "90%, healing" "Average, flare-up" "10%, flare-up" "90%, flare-up"]
plot_colors = [:blue :blue :blue :red :red :red]
plot_styles = [:solid :dot :dot :solid :dot :dot]
plot(plot_data, title = "Truth = B, same q = 0.70: healing learns truth, flare-up does not",
    label = plot_labels, linecolor = plot_colors, linestyle = plot_styles,
    ylims = [0,1], size = (900,600), legend = :outertopright,
    ylabel = "Belief in state A", xlabel = "Period, t", dpi = 600)
savefig("trauma_beliefs_two_basins")

# =====================================================================
# PART C. Fully-coupled run: the community urge evolves over time, and the
#   listener's belief tracks it THROUGH HER FIXED NETWORK (nA_L unchanged).
#   Only alpha_t moves (intensive margin); her friend counts never grow.
#   Community 1 starts in the healing basin, community 2 in the flare basin.
# =====================================================================

muvec_c1 = zeros(T+1, N); muvec_c1[1,:] = p*ones(1, N)   # community heals
muvec_c2 = zeros(T+1, N); muvec_c2[1,:] = p*ones(1, N)   # community flares

for i in 1:1:N
for t in 1:1:T
    # ----- community 1 (healing path): urge a1 = apath_heal[t], network FIXED -----
    a1 = apath_heal[t]
    sA = rand(Binomial(nA_L, gamma)); aA = rand(Binomial(sA, 1-q)); bA = sA - aA
    shAa = rand(Binomial(aA, sigma + a1)); shAb = rand(Binomial(bA, sigma)); silA = nA_L - shAa - shAb
    sB = rand(Binomial(nB_L, gamma)); aB = rand(Binomial(sB, 1-q)); bB = sB - aB
    shBa = rand(Binomial(aB, sigma)); shBb = rand(Binomial(bB, sigma + aB_comm)); silB = nB_L - shBa - shBb
    sn = rand(Binomial(n0_L, gamma)); an = rand(Binomial(sn, 1-q)); bn = sn - an
    shna = rand(Binomial(an, sigma)); shnb = rand(Binomial(bn, sigma))
    og = rand(Binomial(1, gamma)); oa = rand(Binomial(og, 1-q)); ob = og - oa
    na = shAa + shBa + shna + oa; nb = shAb + shBb + shnb + ob
    muvec_c1[t+1,i] = muvec_c1[t,i] / (muvec_c1[t,i] + (1 - muvec_c1[t,i]) *
        ((1-q)/q)^(na - nb) * Ghat^(silB - silA))

    # ----- community 2 (flare-up path): urge a2 = apath_flare[t], network FIXED -----
    a2 = apath_flare[t]
    sA = rand(Binomial(nA_L, gamma)); aA = rand(Binomial(sA, 1-q)); bA = sA - aA
    shAa = rand(Binomial(aA, sigma + a2)); shAb = rand(Binomial(bA, sigma)); silA = nA_L - shAa - shAb
    sB = rand(Binomial(nB_L, gamma)); aB = rand(Binomial(sB, 1-q)); bB = sB - aB
    shBa = rand(Binomial(aB, sigma)); shBb = rand(Binomial(bB, sigma + aB_comm)); silB = nB_L - shBa - shBb
    sn = rand(Binomial(n0_L, gamma)); an = rand(Binomial(sn, 1-q)); bn = sn - an
    shna = rand(Binomial(an, sigma)); shnb = rand(Binomial(bn, sigma))
    og = rand(Binomial(1, gamma)); oa = rand(Binomial(og, 1-q)); ob = og - oa
    na = shAa + shBa + shna + oa; nb = shAb + shBb + shnb + ob
    muvec_c2[t+1,i] = muvec_c2[t,i] / (muvec_c2[t,i] + (1 - muvec_c2[t,i]) *
        ((1-q)/q)^(na - nb) * Ghat^(silB - silA))
end
end

avg_c1 = zeros(T+1, 1); avg_c2 = zeros(T+1, 1)
for t in 1:1:(T+1)
    avg_c1[t] = mean(muvec_c1[t,:])
    avg_c2[t] = mean(muvec_c2[t,:])
end

println("Coupled, truth B.  community heals:  alpha_T = ", round(apath_heal[T+1], digits=3),
        "  mu_T = ", round(avg_c1[T+1], digits=3))
println("Coupled, truth B.  community flares: alpha_T = ", round(apath_flare[T+1], digits=3),
        "  mu_T = ", round(avg_c2[T+1], digits=3))

plot([avg_c1 avg_c2],
    label = ["community heals (alpha_0=0.20)" "community flares (alpha_0=0.75)"],
    linecolor = [:blue :red], linestyle = [:solid :solid],
    ylims = [0,1], xlabel = "Period, t", ylabel = "Belief in state A",
    title = "Coupled trauma + belief dynamics, truth = B, same q = 0.70 (fixed listener network)",
    legend = :right, size = (900,600), dpi = 600)
savefig("trauma_coupled_dynamics")
