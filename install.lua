local REPO="https://raw.githubusercontent.com/nexox9official-source/international-code-computercraft/main/"
local files={
  "ic.lua",
  "international_code/common.lua",
  "international_code/server.lua",
  "international_code/client.lua",
  "international_code/printer.lua",
  "international_code/seed/001.lua",
  "international_code/seed/002.lua",
  "international_code/seed/003.lua",
  "international_code/seed/004.lua",
  "international_code/seed/005.lua"
}
local args={...}
local role=args[1]

local function dirOf(p) return p:match("^(.*)/[^/]+$") end
local function ensure(p) if p and p~="" and not fs.exists(p) then fs.makeDir(p) end end

local function download(rel)
  local url=REPO..rel
  local h,err=http.get(url)
  if not h then error("Telechargement impossible: "..rel.." / "..tostring(err),0) end
  local data=h.readAll();h.close()
  ensure(dirOf("/"..rel))
  local out=assert(fs.open("/"..rel,"w"));out.write(data);out.close()
  print("[OK] "..rel)
end

term.setBackgroundColor(colors.black);term.setTextColor(colors.white);term.clear();term.setCursorPos(1,1)
print("UNS INTERNATIONAL CODE")
print("Installation ComputerCraft")
print("")
if not http then error("API HTTP indisponible.",0) end
for _,f in ipairs(files) do download(f) end

if not fs.exists("/startup") then fs.makeDir("/startup") end
local s=assert(fs.open("/startup/90_uns_international_code.lua","w"))
s.write('if fs.exists("/ic.lua") then shell.run("ic") end\n')
s.close()

print("")
print("Installation terminee.")
if role then
  if role=="server" then shell.run("ic","setup","server")
  elseif role=="writer" or role=="clerk" or role=="judge" or role=="viewer" or role=="admin" then shell.run("ic","setup",role)
  else print("Role inconnu: "..role);print("Utilisez ensuite: ic help") end
else
  print("Lancez: ic help")
end
