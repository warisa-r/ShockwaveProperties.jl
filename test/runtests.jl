using LinearAlgebra
using ShockwaveProperties
using Test
using Unitful

# flux for the euler equations
function F(u::ConservedState)
    v = u.ρv / u.ρ # velocity
    P = pressure(u; gas=DRY_AIR)
    return vcat(u.ρv', (u.ρv .* v' + I * P), (v .* (u.ρE + P))') # stack row vectors
end

@testset verbose = true "ShockwaveProperties.jl" begin
    @testset "Dimensional Analysis" begin
        # giving different units shouldn't mess with the actual results
        s1 = PrimitiveState(1.225, [2.0, 0.0], 300.0)
        s2 = PrimitiveState(0.002376892407u"slug/ft^3", [2.0, 1.0], 540.0u"Ra")
        u1 = ConservedState(s1; gas=DRY_AIR)
        u2 = ConservedState(s2; gas=DRY_AIR)
        #check dimensions
        for v ∈ (s1, s2, u1, u2)
            @test pressure(v; gas=DRY_AIR) isa Unitful.Pressure
            @test temperature(v; gas=DRY_AIR) isa Unitful.Temperature
            @test internal_energy(v; gas=DRY_AIR) isa ShockwaveProperties.SpecificEnergy
            @test speed_of_sound(v; gas=DRY_AIR) isa Unitful.Velocity
        end
        # check equivalency between primitive/conserved
        for (v1, v2) ∈ ((s1, u2), (s2, u1))
            @test pressure(v1; gas=DRY_AIR) ≈ pressure(v2; gas=DRY_AIR) 
            @test temperature(v1; gas=DRY_AIR) ≈ temperature(v2; gas=DRY_AIR) 
            @test internal_energy(v1; gas=DRY_AIR) ≈ internal_energy(v2; gas=DRY_AIR) 
            @test speed_of_sound(v1; gas=DRY_AIR) ≈ speed_of_sound(v2; gas=DRY_AIR) 
        end
    end
    @testset "Convert Primitve ↔ Conserved" begin
        s1 = PrimitiveState(1.225, [2.0, 0.0], 300.0)
        u = ConservedState(s1; gas=DRY_AIR)
        s2 = PrimitiveState(u; gas=DRY_AIR)
        @test s1.ρ ≈ s2.ρ
        @test s1.M ≈ s2.M
        @test s1.T ≈ s2.T
    end
    @testset "Rankine-Hugoniot Condition" begin
        free_stream = PrimitiveState(1.225, [2.0, 0.0], 300.0)
        u_L = ConservedState(free_stream; gas=DRY_AIR)
        # restricted domain here because formula from Anderson&Anderson
        # breaks down near β = 0
        # TODO investigate this.
        for θ ∈ range(0, π / 6; length=40)
            n = [-cos(θ), sin(θ)]
            t = [0 1; -1 0] * n
            u_R = state_behind(u_L, n, t; gas=DRY_AIR)
            # F(u_l)⋅n̂ - F(u_r)⋅n̂ = 0 ⟹ F(u_l)⋅n̂ = F(u_r)⋅n̂ 
            @test all(F(u_L) * n .≈ F(u_R) * n)
        end
    end

    @testset verbose = true "BilligShockParametrization" begin
        using .BilligShockParametrization
        @testset "Shockwave Normals" begin
            y = -10:0.1:10
            for R_b ∈ 1.0:0.5:4.0, M ∈ 2.0:1.0:5.0
                vals = mapreduce(hcat, y) do α
                    shock_normal(α, M, R_b) ⋅ shock_tangent(α, M, R_b)
                end
                @test all(≈(0), vals)
            end
        end
    end

end

