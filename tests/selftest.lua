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

assert(common.VERSION=="0.11.0","unexpected application version: "..tostring(common.VERSION))

local function readSource(path)
  local h=assert(io.open(path,"r"))
  local body=h:read("*a")
  h:close()
  return body
end

local server=readSource("international_code/server.lua")
local client=readSource("international_code/client.lua")
local public=readSource("international_code/public.lua")
local printer=readSource("international_code/printer.lua")
local cli=readSource("ic.lua")

assert(server:find('CONFLICT_CREATE',1,true),"conflict server actions missing")
assert(server:find('INCIDENT_CREATE',1,true),"incident server actions missing")
assert(server:find('SITUATION_GET',1,true),"situation server action missing")
assert(server:find('UNS%-CFZONE'),"conflict-zone seals missing")
assert(client:find('conflictDetails=function',1,true),"conflict client UI missing")
assert(client:find('incidentDetails=function',1,true),"incident client UI missing")
assert(public:find('function P.situationDisplay',1,true),"situation monitor missing")
assert(public:find('function P.conflictDisplay',1,true),"conflict monitor missing")
assert(printer:find('function P.conflict',1,true),"conflict printer missing")
assert(printer:find('function P.incident',1,true),"incident printer missing")
assert(cli:find('cmd=="conflict"',1,true),"conflict CLI missing")
assert(cli:find('cmd=="situation"',1,true),"situation CLI missing")

print("Self-test OK: search + 500 articles + v0.11 situation/conflict features")
