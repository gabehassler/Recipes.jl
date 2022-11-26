module Recipes

export Ingredient,
       Instruction,
       Recipe

using Unitful

include("RecipeUnits.jl")

using Recipes.RecipeUnits

Unitful.register(RecipeUnits)


const UNITS = Dict(
    "g" => u"g",
    "tsp" => u"tsp"
)

struct Ingredient
    name::String
    quantity::Union{Quantity, Nothing}
    prep::Union{String, Nothing}
end



import Base.string
function string(x::Ingredient)
    s = x.name
    if !isnothing(x.quantity)
        s *= " (" * string(x.quantity) * ")"
    end
    if !isnothing(x.prep) && !isempty(x.prep)
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

const RECIPE = "recipe:"
const MAKES = "makes:"
const INGREDIENTS = "ingredients:"
const INSTRUCTIONS = "instructions:"

function find_next_single(lines::Vector{<:AbstractString},
                          match::AbstractString;
                          start::Int = 1)
    while !startswith(lowercase(lines[start]), match)
        start += 1
    end

    strip(lines[start][(length(match) + 1):end]), start + 1
end

function find_next_list(lines::Vector{<:AbstractString},
                        match::AbstractString;
                        start::Int = 1)

    while !startswith(lowercase(lines[start]), match)
        start += 1
    end

    l = String[]
    start += 1
    while start <= length(lines) && startswith(lines[start], '-')
        push!(l, strip(lines[start][2:end]))
        start += 1
    end

    l, start
end

const INGREDIENT_PATTERN = r"([^\(\)]*)\s*(?:\((.*)\))?(?:,\s*(.*))?" #r"(.*)\s*(?:\((.*)\))?(?:,\s*(.*))?"


function parse_ingredient(s::AbstractString)
    m = match(INGREDIENT_PATTERN, s)
    @show m
    if isnothing(m)
        error("could not parse ingredient: $s")
    end

    @show m

    Ingredient(m[1], parse_amount(m[2]), m[3])
end

function parse_amount(::Nothing)
    nothing
end

function parse_number(s::AbstractString)
    n = parse(Float64, s)
    try
        n = Int(n)
    catch
        #do nothing
    end
    return n
end

function parse_amount(s::AbstractString)
    s = split(s)
    n = parse_number(s[1])
    if length(s) == 1
        return n * u"count"
    elseif length(s) == 2
        if s[2] in keys(UNITS)
            return n * UNITS[s[2]]
        else
            unit = s[2]
            dim_name = unit * "Dim"
            dim_name_long = unit * "Dimension"

            @warn "unrecognized unit $unit. creating new unit"
            dim = eval(:(@dimension $(Symbol(dim_name)) $dim_name $(Symbol(dim_name_long))))
            u = eval(:(@refunit $(Symbol(unit)) $unit $(Symbol(unit)) $dim false))
            return n * u
        end
    else
        error("not implemented")
    end
end


function parse_recipe(s::String)
    lines = readlines(s)

    name, i = find_next_single(lines, RECIPE)
    amt, i = find_next_single(lines, MAKES, start = i)
    ingredients, i = find_next_list(lines, INGREDIENTS, start = i)
    instructions, _ = find_next_list(lines, INSTRUCTIONS, start = i)

    return Recipe(name,
                  parse_ingredient.(ingredients),
                  Instruction.(instructions),
                  parse_amount(amt))

end


end # module
