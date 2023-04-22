module RecipeUnits

export MyQuantity

using Unitful


@dimension amt "amount" Qnty
@refunit count "count" Count amt false

@unit tsp "tsp" TeaSpoon 4.92892u"mL" false
@unit cup "cup" Cup 0.236588u"L" false

# @unit cal "cal" Cal 4184"J" false
end