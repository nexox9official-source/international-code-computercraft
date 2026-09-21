local common = dofile("/international_code/common.lua")
local P = {}

local function getPrinter()
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "printer" then return peripheral.wrap(name), name end
  end
  return nil, nil
end

function P.available()
  local p, name = getPrinter()
  return p ~= nil, name
end

local function appendWrapped(lines, label, text, width)
  if label and label ~= "" then lines[#lines + 1] = label end
  local wrapped = common.wrap(text or "", width)
  for _, line in ipairs(wrapped) do lines[#lines + 1] = line end
  lines[#lines + 1] = ""
end

local function printLines(title, lines)
  local printer = getPrinter()
  if not printer then return false, "Aucune imprimante connectee." end
  local width, height = 25, 21
  if printer.getPageSize then
    local ok, w, h = pcall(printer.getPageSize)
    if ok and w and h then width, height = w, h end
  end
  local bodyHeight = math.max(5, height - 3)
  local pageCount = math.max(1, math.ceil(#lines / bodyHeight))
  local cursor = 1
  for page = 1, pageCount do
    if not printer.newPage() then return false, "Papier ou encre insuffisants." end
    if printer.setPageTitle then pcall(printer.setPageTitle, common.fit(title, 32)) end
    printer.setCursorPos(1,1)
    printer.write(common.fit("UNS / COUR INTERNATIONALE", width))
    local y = 2
    while y <= bodyHeight + 1 and cursor <= #lines do
      printer.setCursorPos(1,y)
      printer.write(common.fit(lines[cursor], width))
      cursor = cursor + 1
      y = y + 1
    end
    printer.setCursorPos(1,height)
    printer.write(common.fit("Page " .. page .. "/" .. pageCount, width))
    if not printer.endPage() then return false, "Impossible de finaliser la page." end
  end
  return true, pageCount
end

function P.law(law)
  local lines = {}
  appendWrapped(lines, law.ref .. " / v" .. tostring(law.version or 1), law.title, 25)
  appendWrapped(lines, "LIVRE", law.book or "Non classe", 25)
  appendWrapped(lines, "TITRE", law.section or "Non classe", 25)
  appendWrapped(lines, "STATUT", law.status or "inconnu", 25)
  appendWrapped(lines, "TEXTE", law.body or "", 25)
  appendWrapped(lines, "MISE A JOUR", law.updatedAt or law.createdAt or "", 25)
  return printLines(law.ref or "ARTICLE", lines)
end

function P.caseFile(case)
  local lines = {}
  appendWrapped(lines, case.id, case.title or "Dossier sans titre", 25)
  appendWrapped(lines, "STATUT", case.status or "ouvert", 25)
  appendWrapped(lines, "DEMANDEUR", case.complainant or "-", 25)
  appendWrapped(lines, "MIS EN CAUSE", case.accused or "-", 25)
  appendWrapped(lines, "CONTEXTE", case.summary or "", 25)

  lines[#lines+1] = "FAITS"
  for i, f in ipairs(case.facts or {}) do
    for _, l in ipairs(common.wrap(i .. ". " .. (f.text or ""), 25)) do lines[#lines+1] = l end
  end
  lines[#lines+1] = ""

  lines[#lines+1] = "PREUVES"
  for i, e in ipairs(case.evidence or {}) do
    for _, l in ipairs(common.wrap(i .. ". " .. (e.label or "Preuve") .. ": " .. (e.description or ""), 25)) do lines[#lines+1] = l end
  end
  lines[#lines+1] = ""

  appendWrapped(lines, "ARTICLES CITES", table.concat(case.citedArticles or {}, ", "), 25)

  lines[#lines+1] = "JUGEMENTS"
  for i, j in ipairs(case.judgments or {}) do
    for _, l in ipairs(common.wrap("Jugement " .. i .. " - " .. (j.date or ""), 25)) do lines[#lines+1] = l end
    for _, l in ipairs(common.wrap("Decision: " .. (j.verdict or ""), 25)) do lines[#lines+1] = l end
    for _, l in ipairs(common.wrap("Motifs: " .. (j.reasoning or ""), 25)) do lines[#lines+1] = l end
    for _, l in ipairs(common.wrap("Sanctions: " .. (j.sanctions or ""), 25)) do lines[#lines+1] = l end
    lines[#lines+1] = ""
  end

  appendWrapped(lines, "DERNIERE MAJ", case.updatedAt or case.createdAt or "", 25)
  return printLines(case.id or "DOSSIER", lines)
end

return P
