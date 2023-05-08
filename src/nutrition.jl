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


# const NUTRITION_PATH = "../nutrition/food.csv"
# const NUTRITION_DICT = "../nutrition/dict.csv"
# const SIMPLE_DICT = "../nutrition/simple_names.csv"
# const UNIT_DICT = Dict("g" => 1u"g",
#                        "mg" => 1u"mg",
#                        "mcg" => 1u"μg",
#                        "μg" => 1u"μg",
#                        "IU" => 1/40 * 1u"μg")
# const REF_WEIGHT = 100u"g"
const CALORIE_DICT = Dict("Carbohydrate" => 4u"cal" / 1u"g",
                          "Protein" => 4u"cal" / 1u"g",
                          "Fat" => 9u"cal" / 1u"g",
                          "Fiber" => 2u"cal" / 1u"g")

function parse_nutrition(key::String)
    nutrients, quants, ref = get_nutrient(key)
    return Nutrition(nutrients, quants, ref)
end

# function parse_nutrition(df::DataFrame, food::String, dict::DataFrame)
#     ind = findfirst(x -> x == food, df.Description)
#     if isnothing(ind)
#         return nothing
#     end

#     nutr_inds = 4:ncol(df)
#     @assert names(df)[nutr_inds] == dict.variable
#     quants = [df[ind, nutr_inds[i]] * UNIT_DICT[dict.unit[i]] for i = 1:nrow(dict)]
#     return Nutrition(quants, dict)
# end



function get_calories(food::String, quant::Quantity)
    quant = uconvert(u"g", quant)
    try
        return quant * CALORIE_DICT[food]
    catch
        return nothing
    end
end

function format_nutrition(df::DataFrame)

    types = ["General", "Macro", "Mineral", "Vitamin", "Amino Acid"]
    # df = deepcopy(df)
    # df.name .= string.([x -> ismissing(df.pretty[x]) ? df.name[x] : df.pretty[x] for x = 1:nrow(df)])
    tb = DataFrame(nutrient = String[],
                   quantity = Quantity[],
                   is_sub = Bool[],
                   type = String[],
                   some_missing = Bool[],
                   minimum = Quantity[],
                   maximum = Quantity[])
    for tp in types
        inds = findall(x -> !ismissing(x) && x == tp, df.category)
        dfs = df[inds, :]
        full_inds = findall(ismissing, dfs.parent)
        full_nms = dfs.name[full_inds]
        sp = sortperm(full_nms)
        full_inds = full_inds[sp]
        full_nms = dfs.name[full_inds]
        qts = dfs.quantity[full_inds]
        mins = dfs.min_requirement[full_inds]
        maxs = dfs.max_requirement[full_inds]
        is_sub = fill(false, length(full_inds))
        some_missing = dfs.some_missing[full_inds]

        sub_inds = setdiff(1:nrow(dfs), full_inds)
        for ind in sub_inds
            parent = dfs.parent[ind]
            qt = dfs.quantity[ind]
            pind = findfirst(isequal(parent), full_nms)
            insert!(full_nms, pind + 1, dfs.name[ind])
            insert!(qts, pind + 1, qt)
            insert!(is_sub, pind + 1, true)
            insert!(some_missing, pind + 1, dfs.some_missing[ind])
            insert!(mins, pind + 1, dfs.min_requirement[ind])
            insert!(maxs, pind + 1, dfs.max_requirement[ind])
        end
        tb = vcat(tb, DataFrame(nutrient = full_nms,
                                quantity = qts,
                                is_sub = is_sub,
                                type = tp,
                                some_missing = some_missing,
                                minimum = mins,
                                maximum = maxs))
    end

    for i = 1:nrow(tb)
        n = tb.nutrient[i]
        ind = findfirst(isequal(n), df.name)
        if !ismissing(df.pretty[ind])
            tb.nutrient[i] = df.pretty[ind]
        end
    end

    @show tb

    # cals = [get_calories(tb.nutrient[i], tb.quantity[i]) for i = 1:nrow(tb)]
    # parent = nothing
    # parent_i = nothing
    # for i = 1:length(cals)
    #     if tb.is_sub[i]
    #         pcals_i = get_calories(parent, tb.quantity[i])
    #         if isnothing(cals[i])
    #             cals[i] = pcals_i
    #         else
    #             cals[parent_i] += cals[i] - pcals_i
    #         end
    #     else
    #         parent = tb.nutrient[i]
    #         parent_i = i
    #     end
    # end

    # total_cals = 0.0u"cal"
    # for i = 1:length(cals)
    #     if !isnothing(cals[i]) && !tb.is_sub[i]
    #         total_cals += cals[i]
    #     end
    # end

    # cal_percs = [isnothing(x) ? nothing : x / total_cals * 100 for x in cals]
    # tb[!, "cal_percs"] = cal_percs
    # tb[!, "calories"] = cals
    tb[!, "pretty"] = [tb.is_sub[i] ? "    " * tb.nutrient[i] : tb.nutrient[i] for i = 1:nrow(tb)]
    max_name = maximum(length.(tb.pretty))
    tb[!, "pretty_quant"] = [pretty_quant(x, sigdigits = 3) for x in tb.quantity]
    max_quant = maximum(length.(tb.pretty_quant))
    tb[!, "pretty_min"] = [pretty_quant(x, sigdigits = 3) for x in tb.minimum]
    max_min = maximum(length.(tb.pretty_min))
    tb[!, "pretty_max"] = [pretty_quant(x, sigdigits = 3) for x in tb.maximum]
    max_max = maximum(length.(tb.pretty_max))
    # tb[!, "pretty_cal"] = [pretty_quant(x, sigdigits = 3) for x in tb.calories]
    # max_cal = maximum(length.(tb.pretty_cal))
    # tb[!, "pretty_perc"] = [isnothing(x) ? "" : string(round(x, digits = 1)) * "%" for x in tb.cal_percs]
    # max_perc = maximum(length.(tb.pretty_perc))
    s = pad_string("Nutrition Facts:", max_name + 8, side=:right)
    s *= "   " * pad_string("Amount", max_quant, side = :right)
    s *= "   " * pad_string("Min", max_min, side = :right)
    s *= "   " * pad_string("Max", max_max, side = :right)

    println(s)
    for i = 1:nrow(tb)
        if i == 1 || tb.type[i] != tb.type[i - 1]
            println(tb.type[i])
        end
        nm = tb.some_missing[i] ? tb.pretty[i] * "*" : tb.pretty[i]
        s = "\t" * pad_string(nm, max_name, side = :right)
        s *= "   " * pad_string(tb.pretty_quant[i], max_quant, side = :left)
        s *= "   " * pad_string(tb.pretty_min[i], max_min, side = :left)
        s *= "   " * pad_string(tb.pretty_max[i], max_max, side = :left)

        # s *= "   " * pad_string(tb.pretty_cal[i], max_cal, side = :left)
        # s *= "   " * pad_string(tb.pretty_perc[i], max_perc, side = :left)
        s *= "\n"
        q = tb.quantity[i]
        mn = tb.minimum[i]
        mx = tb.maximum[i]
        mn = ismissing(mn) ? mn : convert(Quantity{Float64}, mn) # not sure why I need this?
        mx = ismissing(mx) ? mx : convert(Quantity{Float64}, mx) # not sure why I need this?

        if ismissing(mn)
            print(s)
        else
            satisfies = true
            if !(ismissing(mn) || q > mn)
                satisfies = false
            end
            if !(ismissing(mx) || q < mx)
                satisfies = false
            end
            if satisfies
                printstyled(s, color = :green)
            else
                printstyled(s, color = :red)
            end
        end
    end
end

function pad_string(s::String, n::Int; side = :left)
    d = n - length(s)
    @assert d >= 0
    spaces = join(fill(" ", d))
    if side == :left
        return spaces * s
    elseif side == :right
        return s * spaces
    else
        error("")
    end
end

function pretty_quant(q::Quantity; kwargs...)
    x = round(q.val; kwargs...)
    u = string(unit(q))
    if length(u) == 1
        u = pad_string(u, 2, side = :left)
    end
    return string(x) * " " * u
end

function pretty_quant(::Missing; kwargs...)
    return "?"
end

function pretty_quant(q::Nothing; kwargs...)
    return ""
end
