local REPO="https://raw.githubusercontent.com/nexox9official-source/international-code-computercraft/main/"
local files={
  "ic.lua",
  "international_code/common.lua",
  "international_code/launcher.lua",
  "international_code/server.lua",
  "international_code/client.lua",
  "international_code/printer.lua",
  "international_code/public.lua",
  "international_code/national.lua",
  "international_code/national_client.lua",
  "international_code/national_democracy.lua",
  "international_code/national_democracy_client.lua",
  "international_code/national_printer.lua",
  "international_code/national_public.lua",
  "international_code/national_services.lua",
  "international_code/national_finance.lua",
  "international_code/national_network.lua",
  "international_code/national/corpus_meta.json",
  "international_code/national/articles_001_100.json",
  "international_code/national/articles_101_200.json",
  "international_code/national/articles_201_300.json",
  "international_code/national/articles_301_400.json",
  "international_code/seed/001.lua",
  "international_code/seed/002.lua",
  "international_code/seed/003.lua",
  "international_code/seed/004.lua",
  "international_code/seed/005.lua"
}
local args={...}
local mode=args[1]

local function dirOf(p) return p:match("^(.*)/[^/]+$") end
local function ensure(p) if p and p~="" and not fs.exists(p) then fs.makeDir(p) end end

local function download(rel,index,total)
  local url=REPO..rel
  local h,err=http.get(url)
  if not h then error("Telechargement impossible: "..rel.." / "..tostring(err),0) end
  ensure(dirOf("/"..rel))

  local tmp="/"..rel..".download"
  if fs.exists(tmp) then fs.delete(tmp) end
  local out=assert(fs.open(tmp,"wb"))
  local bytes=0

  while true do
    local chunk=h.read(8192)
    if not chunk then break end
    out.write(chunk)
    bytes=bytes+#chunk
  end
  h.close();out.close()

  local target="/"..rel
  if fs.exists(target) then fs.delete(target) end
  fs.move(tmp,target)

  term.setCursorPos(1,4)
  term.clearLine()
  term.write(string.format("[%d/%d] %s",index,total,rel))
  term.setCursorPos(1,5)
  term.clearLine()
  term.write(tostring(bytes).." octets / streaming RAM faible")
  if collectgarbage then pcall(collectgarbage,"collect") end
end

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear();term.setCursorPos(1,1)
print("UNS + NORTH COALITION")
print("Installation / mise a jour faible memoire")
print("")
if not http then error("API HTTP indisponible.",0) end

for i,f in ipairs(files) do download(f,i,#files) end

if not fs.exists("/startup") then fs.makeDir("/startup") end
local s=assert(fs.open("/startup/90_uns_international_code.lua","w"))
s.write([[
if fs.exists("/ic.lua") and fs.exists("/international_code/common.lua") then
  local ok,common=pcall(dofile,"/international_code/common.lua")
  local cfg=ok and common.loadConfig() or nil
  if cfg and cfg.role=="server" then shell.run("ic","server")
  else shell.run("ic") end
end
]])
s.close()

term.setCursorPos(1,7)
term.clearLine()
term.setTextColor(colors.lime)
term.write("Installation terminee.")
term.setTextColor(colors.white)

if mode=="update" then
  print("")
  print("Mise a jour terminee. Vos donnees/configurations sont conservees.")
  return
end

if mode=="server" then
  shell.run("ic","setup","server")
elseif mode=="writer" or mode=="clerk" or mode=="judge" or mode=="delegate" or mode=="viewer" or mode=="admin" then
  shell.run("ic","setup",mode)
else
  print("")
  print("Ouverture du centre de controle...")
  sleep(0.5)
  shell.run("ic")
end
