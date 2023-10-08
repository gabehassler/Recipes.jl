using Recipes
using Recipes.RecipeUnits
using Unitful

Unitful.register(Recipes)
Unitful.register(Recipes.RecipeUnits)



# ingredients = [
#     Ingredient("egg", 1u"count"),
#     Ingredient("salt")
# ]

# instructions = [
#     Instruction("Fill pot with cool water")
#     Instruction("Add salt to water")
#     Instruction("Add egg to water")
#     Instruction("Turn on heat to high and wait for water to boil")
#     Instruction("Turn off heat and let eggs sit in water for 10 minutes")
#     Instruction("Remove eggs from water and cool with cool water")
# ]

# recipe = Recipe("hard-boiled egg", ingredients, instructions, 1u"count")

cd(@__DIR__)
# eggs_path = joinpath("..", "recipes", "mushroom_pate.txt")
# recipe = Recipes.parse_recipe(eggs_path)

# match(Recipes.INGREDIENT_PATTERN, "eggs (2)")

# macro testu(s::String)
#     local sdim = s * "Dim"
#     local sdimLong = s * "Dimension"
#     local sym = Symbol(s)
#     local symLong = Symbol(s * "Long")
#     return quote
#         $(esc(:(@dimension $Symbol(sdim) $sdim $symLong)))
#     end
#     # return quote
#     #     @dimension Test "Test" TestLong
#     # end
# end


# x = @testu "yDim4"

# @macroexpand Recipes.@make_nutrient :test
# x = Recipes.@make_nutrient :test2

# dog_path = joinpath("..", "recipes", "dog_food.txt")
# dogfood = Recipes.parse_recipe(dog_path, require_nutrition = true)
# dogfood = Recipes.scale_to_calories(dogfood, 1000u"kcal")
# @show Recipes.get_calories(dogfood)
# nutrition_facts(dogfood)
# println(dogfood * 7)


paths = [joinpath("..","recipes", "dog$x.txt") for x = [1, 5]]
recipes = Recipes.parse_recipe.(paths, require_nutrition = true)
recipes = 7 * Recipes.scale_to_calories.(recipes, 500u"kcal")
ingredients = Recipes.gather_ingredients(recipes...)