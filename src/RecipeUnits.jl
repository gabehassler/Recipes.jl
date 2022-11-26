module RecipeUnits

export MyQuantity

using Unitful


@dimension amt "amount" Amount
@refunit count "count" Count amt false

@unit tsp "tsp" TeaSpoon 4.92892u"mL" false


end