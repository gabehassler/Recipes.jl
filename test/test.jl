macro testm(ex)
    return quote
        s = String($(esc(ex)))
        x = quote
            function $($(esc(ex)))(a::Int)
                repeat($s, a)
            end
        end
        eval(x)
    end
end

macro assert2(ex)
    return :( $(esc(ex)) ? nothing : throw(AssertionError("A") ))
end

function test()
    x = [:a, :b, :c]
    for y in x
        println(y)
        # println(@macroexpand @assert y == :a)
        # @assert2 y == :a
        # println(@macroexpand @testm :y)
        @testm y
    end
end

test()