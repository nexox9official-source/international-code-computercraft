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

assert(common.VERSION=="0.15.0","unexpected application version: "..tostring(common.VERSION))

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
local national=readSource("international_code/national.lua")
local nationalClient=readSource("international_code/national_client.lua")
local nationalPrinter=readSource("international_code/national_printer.lua")
local nationalPublic=readSource("international_code/national_public.lua")
local nationalCorpus=readSource("international_code/national/corpus_v2.json")

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
assert(cli:find('cmd=="nc"',1,true),"national intranet CLI missing")
assert(cli:find('cmd=="nc-display"',1,true),"national live monitor CLI missing")
assert(server:find('national.handle',1,true),"national server dispatcher missing")
assert(national:find('NC_MINISTER_APPOINT_DIRECT',1,true),"national minister appointments missing")
assert(national:find('NC_ELECTION_VOTE',1,true),"national minister elections missing")
assert(national:find('NC_BILL_ENACT',1,true),"national legislation workflow missing")
assert(national:find('NC_DECREE_PUBLISH',1,true),"national decrees missing")
assert(national:find('NC_NOTICE_LIST',1,true),"national notifications missing")
assert(national:find('NC_CASE_CREATE',1,true),"national case creation missing")
assert(national:find('NC_CASE_ADD_EVIDENCE',1,true),"national evidence workflow missing")
assert(national:find('NC_CASE_ADD_JUDGMENT',1,true),"national judgments missing")
assert(national:find('NC_CASE_FILE_APPEAL',1,true),"national appeals missing")
assert(national:find('NC_CASE_ADD_ORDER',1,true),"national judicial orders missing")
assert(national:find('NC_CITIZEN_CREATE',1,true),"national citizen registry missing")
assert(national:find('NC_CITIZEN_LINK_CLIENT',1,true),"citizen-terminal linking missing")
assert(national:find('NC_SESSION_CREATE',1,true),"national sessions missing")
assert(national:find('NC_SESSION_CHECKIN',1,true),"national session attendance missing")
assert(national:find('NC_SESSION_CLOSE',1,true),"national session minutes missing")
assert(national:find('NC_VERIFY_SEAL',1,true),"national seal verification missing")
assert(national:find('NC_GAZETTE_LIST',1,true),"official Gazette listing missing")
assert(national:find('NC_GAZETTE_GET',1,true),"official Gazette retrieval missing")
assert(national:find('NC%-GAZ'),"official Gazette IDs/seals missing")
assert(nationalClient:find('CODE NATIONAL / CATEGORIES / RECHERCHE',1,true),"national categorized code UI missing")
assert(nationalClient:find('NOTIFICATIONS NATIONALES',1,true),"national notification center missing")
assert(nationalClient:find('JUSTICE / DOSSIERS NATIONAUX',1,true),"national justice UI missing")
assert(nationalClient:find('REGISTRE CIVIL / CITOYENS',1,true),"national citizen registry UI missing")
assert(nationalClient:find('CALENDRIER / SESSIONS NATIONALES',1,true),"national sessions UI missing")
assert(nationalClient:find('VERIFIER UN SCEAU NATIONAL',1,true),"national seal verification UI missing")
assert(nationalClient:find('JOURNAL OFFICIEL NORTH COALITION',1,true),"official Gazette UI missing")
assert(nationalPrinter:find('function P.law',1,true),"national law printing missing")
assert(nationalPrinter:find('function P.caseFile',1,true),"national case printing missing")
assert(nationalPrinter:find('function P.judgment',1,true),"national judgment printing missing")
assert(nationalPrinter:find('function P.session',1,true),"national session printing missing")
assert(nationalPrinter:find('function P.gazette',1,true),"official Gazette printing missing")
assert(nationalPublic:find('JUSTICE NATIONALE',1,true),"national justice monitor missing")
assert(nationalPublic:find('SESSIONS NATIONALES',1,true),"national session monitor missing")
assert(nationalPublic:find('NC-GAZ / actes officiels scelles',1,true),"official Gazette monitor missing")
assert(cli:find('cmd=="nc%-verify"'),"national seal verification CLI missing")

local ncCount=0
for _ in nationalCorpus:gmatch('"id"%s*:%s*"NC%-ART%-%d%d%d"') do ncCount=ncCount+1 end
assert(ncCount==400,"expected 400 North Coalition articles, got "..ncCount)
assert(nationalCorpus:find('"founding_phase_account": "NexoFr_"',1,true),"NexoFr_ founding account missing")
assert(not nationalCorpus:find("Astralium",1,true),"forbidden server name leaked into national corpus")

print("Self-test OK: 500 UNS articles + 400 NC articles + v0.15 regulated national state intranet")
