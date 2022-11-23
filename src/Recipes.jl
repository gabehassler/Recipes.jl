module Recipes

export Ingredient,
       Instruction,
       Recipe

using Unitful

@dimension amt "amount" Amount
@refunit count "count" Count amt false

struct Ingredient
    name::String
    quantity::Union{Quantity, Nothing}
    prep::String
end



import Base.string
function string(x::Ingredient)
    s = x.name
    if !isnothing(x.quantity)
        s *= " (" * string(x.quantity) * ")"
    end
    if !isempty(x.prep)
        s *= ": " * x.prep
    end
    s
end

import Base.show
function show(io::IO, x::Ingredient)
    print(io, string(x))
end

import Base.*
function *(s::Real, x::Ingredient)
    Ingredient(x.name, s * x.quantity, x.prep)
end

function *(x::Ingredient, s::Real)
    s * x
end

*(s::Real, x::Nothing) = nothing
*(x::Nothing, s::Real) = s * x

struct Instruction
    instruction::String
end

struct Recipe
    name::String
    ingredients::Vector{Ingredient}
    instructions::Vector{Instruction}
    amount::Quantity
end

function show(io::IO, r::Recipe)
    s = "Recipe: $(r.name)  (makes $(r.amount))\n\n\tIngredients:"
    for i = 1:length(r.ingredients)
        s *= "\n\t\t- $(r.ingredients[i])"
    end
    s *= "\n\n\tInstructions:"
    for i = 1:length(r.instructions)
        s *= "\n\t\t$i. $(r.instructions[i].instruction)"
    end


    print(io, s)
end

function *(s::Real, r::Recipe)
    Recipe(r.name, s .* r.ingredients, r.instructions, s * r.amount)
end

function *(r::Recipe, s::Real)
    s * r
end




end # module
