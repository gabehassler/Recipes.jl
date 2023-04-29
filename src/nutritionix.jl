using HTTP
# using JSON
using JSON3
using DataFrames
using CSV
using Unitful

include("RecipeUnits.jl")
Unitful.register(RecipeUnits)

include("nutritionix_keys.jl")

const NUTRIENTS_PATH = "./nutrition/nutrition.csv"

const UNIT_DICT = Dict("g" => 1u"g",
                       "mg" => 1u"mg",
                       "mcg" => 1u"μg",
                       "μg" => 1u"μg",
                       "IU" => 1/40 * 1u"μg",
                       "kcal" => 1u"kcal",
                       "kJ" => 1u"kJ",
                       "μg" => 1u"μg")

function parse_nutrition(json;
                         dict::DataFrame = CSV.read("./nutrition/nutrition_dict.csv", DataFrame))
    df = DataFrame(
        food = json[:food_name],
        quantity = json[:serving_weight_grams] * u"g"
        # calories = json[:nf_calories],
        # fat = json[:nf_total_fat],
        # carbs = json[:nf_total_carbohydrate],
        # fiber = json[:nf_dietary_fiber],
        # protein = json[:nf_protein]
    )

    nutrients = json[:full_nutrients]
    for nutrient in nutrients
        id = nutrient[:attr_id]
        ind = findfirst(isequal(id), dict.attr_id)
        name = ismissing(dict.pretty[ind]) ? dict.name[ind] : dict.pretty[ind]
        df[!, name] = [nutrient[:value]] * UNIT_DICT[dict.unit[ind]]
    end
    df
end

function parse_quantity(s::AbstractString)
    ss = split(s)
    @assert length(ss) == 2
    return uparse(join(ss))
end

parse_quantity(::Missing) = missing

function read_nutrients(;path::String = NUTRIENTS_PATH)
    df = CSV.read(path, DataFrame)
    for i = 2:ncol(df)
        df[!, i] = parse_quantity.(df[!, i])
    end
    df
end

function get_nutrient(s::String;
                      nutrients_df::DataFrame = read_nutrients())
    ind = findfirst(isequal(s), nutrients_df.food)
    if isnothing(ind)
        println("downloading nutrition information for $s")
        header = [
            "Content-Type" => "application/json",
            "x-app-id" => APPLICATION_ID,
            "x-app-key" => APPLICATION_KEY,
            "x-remote-user-id" => "0"
        ]

        body = Dict(
            "query" => s
        )

        url = "https://trackapi.nutritionix.com/v2/natural/nutrients"

        response = HTTP.post(url, header, JSON3.write(body))
        json = JSON3.read(response.body).foods
        if length(json) == 0
            error("Nutritionix didn't return any foods for query: $s")
        elseif length(json) > 1
            foods = [x[:food_name] for x in json]
            error("Nutritionix return multiple foods for query: $s\n\t$(join(foods, ", "))")
        end
        ind = findfirst(isequal(json[1][:food_name]), nutrients_df.food)
        if isnothing(ind)
            dfs = parse_nutrition(json[1])
            nutrients_df = vcat(nutrients_df, dfs, cols = :union)
            CSV.write(NUTRIENTS_PATH, nutrients_df)
            ind = nrow(nutrients_df)
        else
            @warn "food '$s' already exists under name '$(json[1][:food_name])'. " *
                "rephrase to avoid repeatedly downloading new nutrition information"
        end
    end

    ind
end

function missing_sum(x::AbstractArray{<:Union{Quantity, Missing}})
    n = length(x)
    s = nothing
    complete = true
    for i = 1:n
        if ismissing(x[i])
            complete = false
        else
            if isnothing(s)
                s = x[i]
            else
                s += x[i]
            end
        end
    end
    s, complete
end

function get_nutrients(ingredients::AbstractVector{<:AbstractString};
                       nutrients_df::DataFrame = read_nutrients())
    inds = [get_nutrient(i, nutrients_df = nutrients_df) for i in ingredients]
    df = nutrients_df[inds, :]
    nutrients = names(df)[2:end]
    amounts = [missing_sum(df[!, i]) for i = 2:ncol(df)]

    return DataFrame(nutrient = nutrients,
                     quantity = [x[1] for x in amounts],
                     complete = [x[2] for x in amounts])
end











parse_nutrition(y[1])
x = get_nutrients(["tofu", "brown rice"])
# curl --header "Content-Type: application/json" --header "x-app-id: 8ac8e3ee" --header "x-app-key: 7f2f5b5e827060a7ee44f03cace825a4" --header "x-remote-user-id: 0" -X POST --data "{\"query\":\"butter\"}" https://trackapi.nutritionix.com/v2/natural/nutrients