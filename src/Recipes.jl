module Recipes

export Ingredient,
       Instruction,
       Recipe,
       nutrition_facts

using Unitful
using DataFrames
using CSV

include("RecipeUnits.jl")

using Recipes.RecipeUnits

Unitful.register(RecipeUnits)


const UNITS = Dict(
    "g" => u"g",
    "tsp" => u"tsp",
    "cup" => u"cup",
    "cups" => u"cup"
)


struct Nutrition
    values::Vector{Quantity}
    dict::DataFrame
end


struct Ingredient
    name::String
    quantity::Union{Quantity, Nothing}
    prep::Union{String, Nothing}
    nutrients::Union{Nutrition, Nothing}
end

function Ingredient(name::String;
    quantity::Union{Quantity, Nothing} = nothing,
    prep::Union{String, Nothing} = nothing,
    nutrients::Union{Nutrition, Nothing} = nothing)

    return Ingredient(name, quantity, prep, nutrients)
end

function Ingredient(name, quantity)
    return Ingredient(name, quantity = quantity)
end

include("nutrition.jl")



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
    nutrients = x.nutrients
    if !isnothing(nutrients)
        nutrients = Nutrition(nutrients.values * s, nutrients.dict)
    end
    Ingredient(x.name,
               s * x.quantity,
               x.prep,
               nutrients)
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


function parse_ingredient(s::AbstractString;
                          ingredient_dict::Dict{String, String},
                          nutrition_df::DataFrame,
                          unit_df::DataFrame,
                          require_nutrition::Bool = false)
    m = match(INGREDIENT_PATTERN, s)
    if isnothing(m)
        error("could not parse ingredient: $s")
    end

    prep = isnothing(m[3]) ? nothing : String(m[3])

    ingredient = String(strip(m[1]))
    nutr_ingredient = ingredient
    try
        nutr_ingredient = ingredient_dict[ingredient]
    catch
        # do nothing
    end

    nutrients = parse_nutrition(nutrition_df, nutr_ingredient, unit_df)
    if require_nutrition && isnothing(nutrients)
        error("Cannot find '$nutr_ingredient' in nutrition file, and " *
              "'require_nutrition = true'")
    end

    quant = parse_amount(m[2])
    if !isnothing(nutrients)
        if dimension(quant) == dimension(REF_WEIGHT)
            nutrients.values .*= uconvert(unit(REF_WEIGHT), quant) / REF_WEIGHT
        elseif require_nutrition
            error("the specified quantity is '$quant', which is not a mass." *
                  "nutrition information is only available by mass/weight")
        else
            nutrients = nothing
        end
    end




    Ingredient(ingredient,
               quantity = parse_amount(m[2]),
               prep = prep,
               nutrients = nutrients)
end

function parse_amount(::Nothing)
    nothing
end

function parse_number(s::AbstractString)
    if contains(s, '/')
        num, den = split(s, '/')
        return parse(Int, num) // parse(Int, den)
    end
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


function parse_recipe(s::String; require_nutrition::Bool = false)
    lines = readlines(s)

    name, i = find_next_single(lines, RECIPE)
    amt, i = find_next_single(lines, MAKES, start = i)
    ingredients, i = find_next_list(lines, INGREDIENTS, start = i)
    instructions, _ = find_next_list(lines, INSTRUCTIONS, start = i)
    idf = CSV.read(SIMPLE_DICT, DataFrame)
    ingredient_dict = Dict(String(idf.short[i]) => String(idf.long[i]) for i in 1:nrow(idf))
    nutrition = CSV.read(NUTRITION_PATH, DataFrame)
    units = CSV.read(NUTRITION_DICT, DataFrame)
    return Recipe(name,
                  parse_ingredient.(ingredients,
                                    ingredient_dict = ingredient_dict,
                                    nutrition_df = nutrition,
                                    unit_df = units,
                                    require_nutrition = require_nutrition),
                  Instruction.(instructions),
                  parse_amount(amt))

end

function nutrition_facts(recipe::Recipe)
    ingredients = recipe.ingredients
    nutrients = [i.nutrients for i in ingredients]
    n = length(nutrients)
    if !isnothing(findfirst(isnothing, nutrients))
        error("Some ingredients do not have nutrition information")
    end
    dict = deepcopy(nutrients[1].dict)
    quants = deepcopy(nutrients[1].values)
    for i = 2:n
        @assert nutrients[i].dict === nutrients[1].dict
        quants += nutrients[i].values
    end

    dict[!, "quantity"] = quants
    format_nutrition(dict)
end


end # module
