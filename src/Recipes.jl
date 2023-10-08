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
    nutrients::Vector{String}
    quantities::Vector{<:Union{Missing, Quantity}}
    reference_weight::Quantity
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
    # nutrients = x.nutrients
    # if !isnothing(nutrients)
    #     nutrients = Nutrition(nutrients.values * s, nutrients.dict)
    # end
    Ingredient(x.name,
               x.quantity * s,
               x.prep,
               x.nutrients * s)
end

function *(x::Ingredient, s::Real)
    s * x
end

import Base.+
function +(a::Ingredient, b::Ingredient)
    if a.name != b.name
        error("cannot add two different ingredients")
    end
    if (a.nutrients.nutrients != b.nutrients.nutrients)
        error("ingredients are the same but they have different nutritional profiles")
    end
    @show a
    @show b
    return Ingredient(
        a.name,
        a.quantity + b.quantity,
        a.prep,
        Nutrition(
            copy(a.nutrients.nutrients),
            a.nutrients.quantities + b.nutrients.quantities,
            a.nutrients.reference_weight + b.nutrients.reference_weight)
    )
end

*(s::Real, x::Nothing) = nothing
*(x::Nothing, s::Real) = s * x

function *(x::Nutrition, s::Real)
    Nutrition(x.nutrients, x.quantities * s, x.reference_weight * s)
end

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

include("nutrition.jl")
include("nutritionix_keys.jl")
include("nutritionix.jl")




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
                        #   ingredient_dict::Dict{String, String},
                        #   nutrition_df::DataFrame,
                        #   unit_df::DataFrame,
                          require_nutrition::Bool = false)
    m = match(INGREDIENT_PATTERN, s)
    if isnothing(m)
        error("could not parse ingredient: $s")
    end

    prep = isnothing(m[3]) ? nothing : String(m[3])

    ingredient = String(strip(m[1]))
    # nutr_ingredient = ingredient
    # try
    #     nutr_ingredient = ingredient_dict[ingredient]
    # catch
    #     # do nothing
    # end
    nutrients = require_nutrition ? parse_nutrition(ingredient) : nothing

    if require_nutrition && isnothing(nutrients)
        error("Cannot find '$nutr_ingredient' in nutrition file, and " *
              "'require_nutrition = true'")
    end

    quant = parse_amount(m[2])
    if !isnothing(nutrients)
        ref_weight = nutrients.reference_weight
        if dimension(quant) == dimension(ref_weight)
            nutrients = nutrients * (uconvert(unit(ref_weight), quant) / ref_weight)
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
    # idf = CSV.read(SIMPLE_DICT, DataFrame)
    # ingredient_dict = Dict(String(idf.short[i]) => String(idf.long[i]) for i in 1:nrow(idf))
    # nutrition = CSV.read(NUTRITION_PATH, DataFrame)
    # units = CSV.read(NUTRITION_DICT, DataFrame)
    return Recipe(name,
                  parse_ingredient.(ingredients,
                                    # ingredient_dict = ingredient_dict,
                                    # nutrition_df = nutrition,
                                    # unit_df = units,
                                    require_nutrition = require_nutrition),
                  Instruction.(instructions),
                  parse_amount(amt))

end

function nutrition_facts(recipe::Recipe;
                         dict = CSV.read(NUTRIENTS_DICT, DataFrame),
                         requirements = CSV.read(MINIMUM_NUTRITION, DataFrame))
    ingredients = recipe.ingredients
    nutrients = [i.nutrients for i in ingredients]
    n = length(nutrients)
    if !isnothing(findfirst(isnothing, nutrients))
        error("Some ingredients do not have nutrition information")
    end
    # dict = deepcopy(nutrients[1].dict)
    # quants = deepcopy(nutrients[1].values)
    # for i = 2:n
    #     @assert nutrients[i].dict === nutrients[1].dict
    #     quants += nutrients[i].values
    # end

    all_nutrients = dict.name
    quants = Vector{Union{Missing, Quantity}}(undef, length(all_nutrients))
    some_missing = fill(false, length(all_nutrients))
    fill!(quants, missing)
    for i = 1:length(nutrients)
        for j = 1:length(all_nutrients)
            ind = findfirst(isequal(all_nutrients[j]), nutrients[i].nutrients)
            # if isnothing(ind)
            #     error("Cannot find $(all_nutrients[j]) in $(nutrients[i].nutrients)")
            # end
            quant = isnothing(ind) ? missing : nutrients[i].quantities[ind]
            # quant = nutrients[i].quantities[ind]

            if ismissing(quant)
                some_missing[j] = true
            elseif ismissing(quants[j])
                quants[j] = quant
            else
                quants[j] += quant
            end
        end
    end

    dict[!, "quantity"] = quants
    dict[!, "some_missing"] = some_missing

    cals_ind = findfirst(isequal("Energy"), dict.name)
    cals = dict.quantity[cals_ind]
    water_ind = findfirst(isequal("Water"), dict.name)
    water = dict.quantity[water_ind]

    total_weight = sum([i.quantity for i in ingredients])
    dry_weight = total_weight - water

    reqs = [parse_and_scale_requirement(
        requirements, i, cals, dry_weight) for i = 1:nrow(requirements)]

    requirements.min_requirement = [r[1] for r in reqs]
    requirements.max_requirement = [r[2] for r in reqs]
    # requirements.min_requirement = requirements.min_requirement .* (cals / 1000u"kcal")
    dict = outerjoin(dict, requirements, on = [:name => :nutrient])
    format_nutrition(dict, total_weight)
end

function parse_and_scale_requirement(requirements, ind, calories, dry_weight)
    qmin = requirements.min_requirement[ind]
    qmax = requirements.max_requirement[ind]
    q = [qmin, qmax]
    comp = requirements.comparison[ind]
    if comp == "per 1000 kcal"
        return q .* (UNIT_DICT[requirements.unit_requirement[ind]] * (calories / 1000u"kcal"))
    elseif comp == "% dry weight"
        return q .* (dry_weight / 100)
    else
        error("unrecognized comparison")
    end
end

function gather_ingredients(recipes::Recipe...)
    ingredients = vcat([r.ingredients for r in recipes]...)
    names = [i.name for i in ingredients]
    new_ingredients = Ingredient[]
    new_names = String[]
    for ingredient in ingredients
        ind = findfirst(isequal(ingredient.name), new_names)
        if isnothing(ind)
            push!(new_ingredients, ingredient)
            push!(new_names, ingredient.name)
        else
            new_ingredients[ind] += ingredient
        end
    end
    return new_ingredients
end



end # module
