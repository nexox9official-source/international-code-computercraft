local M = {}

M.ROOT = "/international_code"
M.DATA = M.ROOT .. "/data"
M.CONFIG = M.ROOT .. "/config.tbl"
M.STATE = M.DATA .. "/state.tbl"
M.BACKUPS = M.DATA .. "/backups"
M.PROTOCOL = "uns_icu_v1"
M.VERSION = "0.19.0"

local randomReady = false

function M.ensureDir(path)
  if not fs.exists(path) then fs.makeDir(path) end
end

function M.ensureLayout()
  M.ensureDir(M.ROOT)
  M.ensureDir(M.DATA)
  M.ensureDir(M.BACKUPS)
end

function M.readAll(path)
  if not fs.exists(path) then return nil end
  local h = fs.open(path, "r")
  if not h then return nil end
  local s = h.readAll()
  h.close()
  return s
end

function M.writeAll(path, data)
  local h = assert(fs.open(path, "w"))
  h.write(data)
  h.close()
end

function M.loadTable(path, fallback)
  local raw = M.readAll(path)
  if not raw or raw == "" then return fallback end
  local ok, value = pcall(textutils.unserialize, raw)
  if ok and type(value) == "table" then return value end
  return fallback
end

function M.saveTableAtomic(path, value)
  local tmp = path .. ".tmp"
  M.writeAll(tmp, textutils.serialize(value, { compact = false }))
  if fs.exists(path) then fs.delete(path) end
  fs.move(tmp, path)
end

function M.loadConfig()
  return M.loadTable(M.CONFIG, nil)
end

function M.saveConfig(cfg)
  M.ensureLayout()
  M.saveTableAtomic(M.CONFIG, cfg)
end

function M.initRandom()
  if randomReady then return end
  local seed = os.getComputerID() * 7919
  if os.epoch then seed = seed + (os.epoch("utc") % 2147483647) end
  math.randomseed(seed)
  math.random(); math.random(); math.random()
  randomReady = true
end

function M.randomToken(len)
  M.initRandom()
  local alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789"
  local out = {}
  for i = 1, (len or 32) do
    local n = math.random(1, #alphabet)
    out[i] = alphabet:sub(n, n)
  end
  return table.concat(out)
end

function M.pairCode()
  M.initRandom()
  return string.format("%06d", math.random(0, 999999))
end

function M.nowMs()
  if os.epoch then return os.epoch("utc") end
  return math.floor(os.clock() * 1000)
end

function M.now()
  if os.epoch then
    local t = math.floor(os.epoch("utc") / 1000)
    local ok, v = pcall(os.date, "!%Y-%m-%dT%H:%M:%SZ", t)
    if ok and v then return v end
  end
  return tostring(os.day()) .. ":" .. textutils.formatTime(os.time(), true)
end

function M.trim(s)
  if s == nil then return "" end
  return tostring(s):match("^%s*(.-)%s*$")
end

function M.normalizeSearch(s)
  s=tostring(s or "")
  local replacements={
    {"À","a"},{"Á","a"},{"Â","a"},{"Ã","a"},{"Ä","a"},{"Å","a"},
    {"à","a"},{"á","a"},{"â","a"},{"ã","a"},{"ä","a"},{"å","a"},
    {"Ç","c"},{"ç","c"},
    {"È","e"},{"É","e"},{"Ê","e"},{"Ë","e"},
    {"è","e"},{"é","e"},{"ê","e"},{"ë","e"},
    {"Ì","i"},{"Í","i"},{"Î","i"},{"Ï","i"},
    {"ì","i"},{"í","i"},{"î","i"},{"ï","i"},
    {"Ñ","n"},{"ñ","n"},
    {"Ò","o"},{"Ó","o"},{"Ô","o"},{"Õ","o"},{"Ö","o"},
    {"ò","o"},{"ó","o"},{"ô","o"},{"õ","o"},{"ö","o"},
    {"Ù","u"},{"Ú","u"},{"Û","u"},{"Ü","u"},
    {"ù","u"},{"ú","u"},{"û","u"},{"ü","u"},
    {"Ý","y"},{"Ÿ","y"},{"ý","y"},{"ÿ","y"},
    {"Œ","oe"},{"œ","oe"},{"Æ","ae"},{"æ","ae"},
    {"’","'"},{"‘","'"},{"–","-"},{"—","-"}
  }
  for _,pair in ipairs(replacements) do s=s:gsub(pair[1],pair[2]) end
  s=string.lower(s)
  s=s:gsub("%s+"," ")
  return M.trim(s)
end

function M.lower(s)
  return M.normalizeSearch(s)
end

function M.contains(haystack, needle)
  haystack = M.normalizeSearch(haystack)
  needle = M.normalizeSearch(needle)
  return needle == "" or string.find(haystack, needle, 1, true) ~= nil
end

function M.searchTokens(s)
  local out={}
  for token in M.normalizeSearch(s):gmatch("[%w%-_]+") do
    if token~="" then out[#out+1]=token end
  end
  return out
end

function M.containsAllTokens(haystack, query)
  local normalized=M.normalizeSearch(haystack)
  local tokens=M.searchTokens(query)
  if #tokens==0 then return true end
  for _,token in ipairs(tokens) do
    if not string.find(normalized,token,1,true) then return false end
  end
  return true
end

function M.wrap(text, width)
  width = math.max(4, width or 25)
  local lines = {}
  text = tostring(text or "")
  for raw in (text .. "\n"):gmatch("(.-)\n") do
    if raw == "" then
      lines[#lines + 1] = ""
    else
      local line = ""
      for word in raw:gmatch("%S+") do
        if #line == 0 then
          if #word <= width then
            line = word
          else
            local p = 1
            while p <= #word do
              lines[#lines + 1] = word:sub(p, p + width - 1)
              p = p + width
            end
          end
        elseif #line + 1 + #word <= width then
          line = line .. " " .. word
        else
          lines[#lines + 1] = line
          if #word <= width then
            line = word
          else
            local p = 1
            while p <= #word do
              lines[#lines + 1] = word:sub(p, p + width - 1)
              p = p + width
            end
            line = ""
          end
        end
      end
      if #line > 0 then lines[#lines + 1] = line end
    end
  end
  return lines
end

function M.fit(s, width)
  s = tostring(s or "")
  if #s <= width then return s .. string.rep(" ", width - #s) end
  if width <= 3 then return s:sub(1, width) end
  return s:sub(1, width - 3) .. "..."
end

function M.openModems()
  local opened = 0
  for _, side in ipairs(peripheral.getNames()) do
    if peripheral.getType(side) == "modem" then
      if not rednet.isOpen(side) then rednet.open(side) end
      opened = opened + 1
    end
  end
  return opened
end

function M.deepcopy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for k, v in pairs(value) do out[M.deepcopy(k, seen)] = M.deepcopy(v, seen) end
  return out
end

function M.sortedKeys(t)
  local keys = {}
  for k in pairs(t or {}) do keys[#keys + 1] = k end
  table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)
  return keys
end

function M.safeName(s)
  s = M.trim(s):gsub("[^%w%-%_ ]", "")
  if s == "" then s = "terminal-" .. os.getComputerID() end
  return s:sub(1, 40)
end

function M.simpleChecksum(s)
  local h = 2166136261
  for i = 1, #s do
    h = (h + s:byte(i) * 16777619) % 4294967296
  end
  return string.format("%08x", h)
end

return M
