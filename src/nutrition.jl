# const NUTRITION = Dict{String, Nutrition}(
#     "brown rice (dry)" => Nutrition(
#         macros = [
#             Fat(1.5u"g"),

#         ]
#     )
# )

# macro make_nutrient(ex)
#     return quote
#         # println($ex)
#         local s = lowercase(String($(esc(ex))))
#         local fname = $(esc(ex))
#         x = quote
#             function $fname(q::Quantity)
#                 return Nutrient($s, q)
#             end
#         end
#         eval(x)
#     end
# end

# NUTRIENT_NAMES = [:Fat, :Carbs, :Protein]
# for nutrient in NUTRIENT_NAMES
#     @make_nutrient nutrient
# end


const NUTRITION_PATH = "../nutrition/food.csv"
const NUTRITION_DICT = "../nutrition/dict.csv"
const SIMPLE_DICT = "../nutrition/simple_names.csv"
const UNIT_DICT = Dict("g" => 1u"g",
                       "mg" => 1u"mg",
                       "mcg" => 1u"μg")
const REF_WEIGHT = 100u"g"
const CALORIE_DICT = Dict("Carbohydrate" => 4u"cal" / 1u"g",
                          "Protein" => 4u"cal" / 1u"g",
                          "Fat" => 9u"cal" / 1u"g")

function parse_nutrition(key::String;
                         nutrition_path::String = NUTRITION_PATH,
                         dict_path::String = NUTRITION_DICT)
    parse_nutrient(CSV.read(nutrition_path, DataFrame), key, CSV.read(dict_path, DataFrame))
end

function parse_nutrition(df::DataFrame, food::String, dict::DataFrame)
    ind = findfirst(x -> x == food, df.Description)
    if isnothing(ind)
        return nothing
    end

    nutr_inds = 4:ncol(df)
    @assert names(df)[nutr_inds] == dict.variable
    quants = [df[ind, nutr_inds[i]] * UNIT_DICT[dict.unit[i]] for i = 1:nrow(dict)]
    return Nutrition(quants, dict)
end



function get_calories(food::String, quant::Quantity)
    quant = uconvert(u"g", quant)
    try
        return quant * CALORIE_DICT[food]
    catch
        return 0.0u"cal"
    end
end

function format_nutrition(df::DataFrame)

    types = ["macro", "micro"]

    tb = DataFrame(nutrient = String[], quantity = Quantity[])
    for tp in types
        inds = findall(df.type .== tp)
        @show inds
        dfs = df[inds, :]
        full_inds = findall(ismissing, dfs.parent)
        full_nms = dfs.name[full_inds]
        sp = sortperm(full_nms)
        full_inds = full_inds[sp]
        full_nms = dfs.name[full_inds]
        tb = vcat(tb, DataFrame(nutrient = full_nms, quantity = dfs.quantity[full_inds]))

    end

    @show tb

    cals = [get_calories(tb.nutrient[i], tb.quantity[i]) for i = 1:nrow(tb)]
    @show cals
    total_cals = sum(cals)
    cal_percs = cals / total_cals
    tb[!, "cal_percs"] = cal_percs * 100
    tb
end


