# =====================================================================
# Agent-based NETWORK polarization  (companion to trauma_simulations_main.jl)
# Style mirrors BDG_simulations_main.ipynb.
#
# This is the explicit-graph version of the mean-field model: instead of a
# single representative listener, we simulate a whole POPULATION of wired
# agents and watch two camps polarize AGAINST each other.
#
#   Population (truth fixed to omega = B, so Pr(a)=1-q):
#     - NA type-A partisans, NB type-B partisans, Nn normal agents.
#     - each normal is "affiliated" with one side (the neighborhood she lives
#       in) and has a FIXED set of neighbors: kS same-side partisans, kO
#       opposite-side partisans, k0 normals. Her counts never change
#       (concern-#2 fix: the flare reaches her only via louder neighbors).
#     - the PARTISAN subgraph REWIRES every period: same-type link prob is
#       the sigmoidal p_same(alphabar) evaluated at the current community
#       urge, so the network thickens as a community flares (the kappa channel).
#
#   Each period: signals realize -> partisans update their urge from the
#   triggering news they received over the (rewired) same-type subgraph ->
#   normals Bayes-update (misspecified, alphahat) from their fixed neighbors.
#
#   Headline: with ONE q, A-side normals converge to A (WRONG, truth is B) and
#   B-side normals converge to B (correct). The belief distribution goes
#   bimodal -- the network polarizes against itself.
# =====================================================================

import Pkg
Pkg.add("Plots"); Pkg.add("Distributions"); Pkg.add("Statistics"); Pkg.add("Random")
using Plots, Distributions, Statistics, Random
Random.seed!(19013)

# ---- primitives (PROPORTION model; same calibration as trauma_simulations_main.jl) ----
gamma, sigma, q = 0.95, 0.10, 0.70
delta, lambda, alphahat = 0.20, 1.364, 0.05    # lambda now dimensionless (drives the SHARE)
kappa, a0, rho0 = 80.0, 0.55, 0.02             # strong sorting needed under the share model
thetaA = 0.30                                  # population share of type-A carriers
beta   = (1 - thetaA)*rho0/thetaA              # composition ratio D_o/(N-1): SIZE-FREE
PA = 1 - q                       # Pr(a | omega=B)
rtrig, ranti = gamma*(1 - q), gamma*q          # fuel under truth B: trigger a scarce, anti b abundant

# ---- population ----
# Under the PROPORTION model the basin no longer depends on community size: the share
# fed to Tfun is invariant to NA/NB (counts scale, ratio does not). Vary NA below and the
# healing/flare split is unchanged -- this is the size-invariance of sec. 5A made stochastic.
NA, NB, Nn = 20, 20, 100         # A-partisans, B-partisans, normals (size is irrelevant under sec.5A)
nAff = Nn ÷ 2                    # half the normals affiliated to each side
Tt = 250
kS, kO = 16, 2                  # same-side / opposite-side partisan neighbors (matches the (16,2) calibrated listener)

aff = vcat(fill(:A, nAff), fill(:B, Nn - nAff))     # normal affiliations
# fixed neighbor index lists (drawn once)
sameN = [ aff[i] == :A ? randperm(NA)[1:kS] : randperm(NB)[1:kS] for i in 1:Nn ]
oppN  = [ aff[i] == :A ? randperm(NB)[1:kO] : randperm(NA)[1:kO] for i in 1:Nn ]

# weights and link curve
L  = log(q/(1-q))
sA = log((1 - gamma*sigma - gamma*q*alphahat) / (1 - gamma*sigma - gamma*(1-q)*alphahat))   # < 0
sB = -sA
psame(ab) = rho0 + (1 - rho0)/(1 + exp(-kappa*(ab - a0)))
Tfun(x)   = (1 - sigma)*(1 - exp(-lambda*x))     # x = SHARE of diet that is triggering, in [0,1]

# mean-field triggering share (sec. 5A): own signal dropped (O(1/N)), so EXACTLY size-free.
# rt = fuel for the triggering signal, ro = fuel for the anti signal.
function phishare(a, rt, ro)
    p  = psame(a)
    bt = (sigma + a)*p + sigma*beta          # triggering-inflow coeff
    bo =  sigma*p      + sigma*beta          # anti-inflow coeff
    (rt*bt)/(rt*bt + ro*bo)
end

# draw firsthand signals for n agents: +1 = a, -1 = b, 0 = none
sigdraw(n) = [ rand() < gamma ? (rand() < PA ? 1 : -1) : 0 for _ in 1:n ]

# ---------------------------------------------------------------------
# one run, given initial community urges (seed the basin via these)
# ---------------------------------------------------------------------
function run_population(alA0, alB0)
    alA = fill(alA0, NA); alB = fill(alB0, NB)
    Lam = zeros(Nn)
    muA_t = zeros(Tt); muB_t = zeros(Tt); abA_t = zeros(Tt); abB_t = zeros(Tt)
    for t in 1:Tt
        sAp = sigdraw(NA); sBp = sigdraw(NB); sNo = sigdraw(Nn)
        abarA = mean(alA); abarB = mean(alB); pA = psame(abarA); pB = psame(abarB)
        abA_t[t] = abarA; abB_t[t] = abarB

        # ---- partisan urge update: driven by the size-free mean-field SHARE (sec. 5A) ----
        # The community urge follows the deterministic share law of motion; the stochastic,
        # explicit-graph action lives entirely in the normals' belief updates below. Because
        # phishare is size-free, this block is identical for any NA/NB -> size-invariance.
        # A-community (truth B): trigger = a (scarce, fuel rtrig); B-community: trigger = b
        # (abundant, fuel ranti). Each carrier shares the common community target (symmetric).
        targA = Tfun(phishare(abarA, rtrig, ranti))
        targB = Tfun(phishare(abarB, ranti, rtrig))
        for i in 1:NA; alA[i] = (1 - delta)*alA[i] + delta*targA; end
        for i in 1:NB; alB[i] = (1 - delta)*alB[i] + delta*targB; end

        # ---- normal belief update from FIXED neighbors ----
        for i in 1:Nn
            d = sNo[i] == 1 ? L : (sNo[i] == -1 ? -L : 0.0)    # own signal
            if aff[i] == :A
                st, sal, stype = sAp, alA, :A;  ot, oal, otype = sBp, alB, :B
            else
                st, sal, stype = sBp, alB, :B;  ot, oal, otype = sAp, alA, :A
            end
            # same-side partisan neighbors
            for j in sameN[i]
                if stype == :A
                    if     st[j] == 1  && rand() < sigma + sal[j]; d += L
                    elseif st[j] == -1 && rand() < sigma;          d -= L
                    else                                            d += sA   end
                else
                    if     st[j] == -1 && rand() < sigma + sal[j]; d -= L
                    elseif st[j] == 1  && rand() < sigma;          d += L
                    else                                            d += sB   end
                end
            end
            # opposite-side partisan neighbors
            for j in oppN[i]
                if otype == :A
                    if     ot[j] == 1  && rand() < sigma + oal[j]; d += L
                    elseif ot[j] == -1 && rand() < sigma;          d -= L
                    else                                            d += sA   end
                else
                    if     ot[j] == -1 && rand() < sigma + oal[j]; d -= L
                    elseif ot[j] == 1  && rand() < sigma;          d += L
                    else                                            d += sB   end
                end
            end
            Lam[i] += d
        end
        mu = 1 ./ (1 .+ exp.(-Lam))
        muA_t[t] = mean(mu[aff .== :A]); muB_t[t] = mean(mu[aff .== :B])
    end
    mu = 1 ./ (1 .+ exp.(-Lam))
    return mu, muA_t, muB_t, abA_t, abB_t
end

# =====================================================================
# SCENARIO 1 (headline): both communities in the FLARE basin -> two camps
# =====================================================================
mu1, muA1, muB1, abA1, abB1 = run_population(0.75, 0.75)   # both seeds above alpha_mid ~ 0.506 -> flare
println("=== Scenario 1: both communities flare (truth = B) ===")
println("final urges:  abar_A = ", round(abA1[end], digits=3), " (truth-OPPOSED)   abar_B = ",
        round(abB1[end], digits=3), " (truth-aligned)")
println("A-side normals mean mu = ", round(mean(mu1[aff .== :A]), digits=3), "  (->1 = believe A = WRONG)")
println("B-side normals mean mu = ", round(mean(mu1[aff .== :B]), digits=3), "  (->0 = believe B = correct)")
println("polarization gap = ", round(mean(mu1[aff .== :A]) - mean(mu1[aff .== :B]), digits=3))

# divergence over time
plot([muA1 muB1], label = ["A-side normals" "B-side normals"],
    linecolor = [:firebrick :navy], linewidth = 2,
    ylims = [0,1], xlabel = "Period, t", ylabel = "Mean belief in state A",
    title = "Network polarizes against itself (truth = B, same q = 0.70)",
    legend = :right, size = (900,600), dpi = 600)
savefig("trauma_network_divergence")

# final belief histogram, by side
histogram(mu1[aff .== :A], bins = 0:0.05:1, alpha = 0.6, label = "A-side", color = :firebrick)
histogram!(mu1[aff .== :B], bins = 0:0.05:1, alpha = 0.6, label = "B-side", color = :navy,
    xlabel = "Belief in state A (final)", ylabel = "number of normal agents",
    title = "Bimodal beliefs: two camps, one truth", size = (900,600), dpi = 600)
savefig("trauma_network_histogram")

# =====================================================================
# SCENARIO 2 (contrast): A-community starts in the HEALING basin.
#   Then A-side normals learn the truth too -> NO polarization (consensus on B).
#   Shows the split is CONTINGENT on the A-community tipping into flare.
# =====================================================================
mu2, muA2, muB2, abA2, abB2 = run_population(0.20, 0.75)   # A below alpha_mid -> heals; B above -> flares
println()
println("=== Scenario 2: A-community heals, B-community flares (truth = B) ===")
println("final urges:  abar_A = ", round(abA2[end], digits=3), " (healed)   abar_B = ",
        round(abB2[end], digits=3))
println("A-side normals mean mu = ", round(mean(mu2[aff .== :A]), digits=3), "  (now also ->0 = correct)")
println("B-side normals mean mu = ", round(mean(mu2[aff .== :B]), digits=3))
println("polarization gap = ", round(mean(mu2[aff .== :A]) - mean(mu2[aff .== :B]), digits=3),
        "  (~0 => consensus on the truth, no polarization)")

plot([muA1 muB1 muA2], label = ["A-side (A flares) -> WRONG" "B-side -> correct" "A-side (A heals) -> correct"],
    linecolor = [:firebrick :navy :orange], linestyle = [:solid :solid :dash], linewidth = 2,
    ylims = [0,1], xlabel = "Period, t", ylabel = "Mean belief in state A",
    title = "Polarization is contingent on the A-community's basin",
    legend = :right, size = (900,600), dpi = 600)
savefig("trauma_network_contingent")
