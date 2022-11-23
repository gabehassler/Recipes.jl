module RecipeUnits

export MyQuantity

using Unitful


@dimension amt "amount" Amount
@refunit count "count" Count amt false

@unit tsp "tsp" TeaSpoon 4.92892u"mL" false

struct MyQuantity
    value::Real
    unit::String
end

import Base.show
function show(io::IO, q::MyQuantity)
    print(io, "$(q.value) $(q.unit)")
end

import Base.*
function *(s::Real, q::MyQuantity)
    return MyQuantity(s * q.value, q.unit)
end

*(q::MyQuantity, s::Real) = s * q


end