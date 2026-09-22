local common=dofile("international_code/common.lua")

assert(common.contains("Légitime défense individuelle","legitime defense"))
assert(common.contains("État d'urgence","etat d'urgence"))
assert(common.containsAllTokens("Interdiction des attaques indiscriminées","attaque interdiction"))
assert(not common.containsAllTokens("Frontières internationales","attaque guerre"))

local total=0
local seen={}
for i=1,5 do
  local path=string.format("international_code/seed/%03d.lua",i)
  local chunk=dofile(path)
  assert(type(chunk)=="table",path.." must return a table")
  for _,entry in ipairs(chunk) do
    local n=entry.number or entry[1]
    assert(type(n)=="number","article number missing in "..path)
    assert(not seen[n],"duplicate article number "..n)
    seen[n]=true
    total=total+1
  end
end

assert(total==500,"expected 500 seed articles, got "..total)
for n=1,500 do assert(seen[n],"missing article "..n) end

print("Self-test OK: search normalization + 500 unique articles")
