local common = dofile("/international_code/common.lua")
local S = {}

local permissions = {
  viewer = {
    PING=true, DASHBOARD=true, SERVER_INFO=true, LAW_LIST=true, LAW_GET=true,
    CASE_LIST=true, CASE_GET=true
  },
  writer = {
    PING=true, DASHBOARD=true, SERVER_INFO=true, LAW_LIST=true, LAW_GET=true,
    CASE_LIST=true, CASE_GET=true, LAW_CREATE=true, LAW_AMEND=true, LAW_REPEAL=true,
    LAW_SET_STATUS=true, AUDIT_LIST=true
  },
  clerk = {
    PING=true, DASHBOARD=true, SERVER_INFO=true, LAW_LIST=true, LAW_GET=true,
    CASE_LIST=true, CASE_GET=true, CASE_CREATE=true, CASE_UPDATE_SUMMARY=true,
    CASE_ADD_FACT=true, CASE_ADD_EVIDENCE=true, CASE_ADD_ARTICLE=true,
    CASE_REMOVE_ARTICLE=true, CASE_SET_STATUS=true, AUDIT_LIST=true
  },
  judge = {
    PING=true, DASHBOARD=true, SERVER_INFO=true, LAW_LIST=true, LAW_GET=true,
    CASE_LIST=true, CASE_GET=true, CASE_CREATE=true, CASE_UPDATE_SUMMARY=true,
    CASE_ADD_FACT=true, CASE_ADD_EVIDENCE=true, CASE_ADD_ARTICLE=true,
    CASE_REMOVE_ARTICLE=true, CASE_ADD_JUDGMENT=true, CASE_SET_STATUS=true,
    AUDIT_LIST=true
  },
  admin = { ["*"]=true }
}

local function can(role, action)
  local p = permissions[role or ""]
  return p and (p["*"] or p[action]) or false
end

local bookNames = {
  "LIVRE I - DISPOSITIONS FONDAMENTALES, DEFINITIONS ET HIERARCHIE DES NORMES",
  "LIVRE II - SOURCES DU DROIT, PUBLICATION ET INTERPRETATION",
  "LIVRE III - ADHESION, STATUT ET OBLIGATIONS DES ETATS MEMBRES",
  "LIVRE IV - SUSPENSION, EXCLUSION ET CONTINUITE DES ETATS",
  "LIVRE V - INSTITUTIONS DE L'UNION ET REPARTITION DES POUVOIRS",
  "LIVRE VI - ASSEMBLEE, VOTES, LEGISLATION ET REGISTRE OFFICIEL",
  "LIVRE VII - COMPETENCE DE LA COUR INTERNATIONALE DE L'UNION",
  "LIVRE VIII - JUGES, PARQUET, GREFFE ET INDEPENDANCE JUDICIAIRE",
  "LIVRE IX - PROCEDURE JUDICIAIRE, SAISINE ET DROITS DES PARTIES",
  "LIVRE X - ENQUETES, PREUVES, TEMOINS ET INTEGRITE DES DOSSIERS",
  "LIVRE XI - JUGEMENTS, SANCTIONS, APPELS ET EXECUTION",
  "LIVRE XII - RESPONSABILITE INTERNATIONALE DES ETATS ET REPARATIONS",
  "LIVRE XIII - PAIX, SECURITE COLLECTIVE ET RECOURS A LA FORCE",
  "LIVRE XIV - CONDUITE DES HOSTILITES ET DROIT DES CONFLITS ARMES",
  "LIVRE XV - CRIMES INTERNATIONAUX MAJEURS ET RESPONSABILITE INDIVIDUELLE",
  "LIVRE XVI - DROITS FONDAMENTAUX, DETENTION ET PROTECTION DES PERSONNES",
  "LIVRE XVII - DIPLOMATIE, TRAITES ET RELATIONS OFFICIELLES",
  "LIVRE XVIII - FRONTIERES, TERRITOIRES, OCCUPATION ET SOUVERAINETE",
  "LIVRE XIX - COMMERCE, FINANCE, SANCTIONS ET CRIMINALITE ECONOMIQUE",
  "LIVRE XX - ENTREPRISES, ORGANISATIONS, CORRUPTION ET CRIMINALITE ORGANISEE",
  "LIVRE XXI - AIDE HUMANITAIRE, SANTE, DEPLACEMENTS ET PROTECTION DES POPULATIONS",
  "LIVRE XXII - RESSOURCES, ENVIRONNEMENT, MATIERES DANGEREUSES ET ZONES CONTAMINEES",
  "LIVRE XXIII - TECHNOLOGIES, COMMUNICATIONS, COMPUTERS, CYBERSECURITE ET PREUVES NUMERIQUES",
  "LIVRE XXIV - RENSEIGNEMENT, SECRETS, INFORMATION PUBLIQUE ET INFRASTRUCTURES STRATEGIQUES",
  "LIVRE XXV - URGENCES, APOCALYPSE, RECONSTRUCTION, ARCHIVES ET DISPOSITIONS FINALES"
}

local function loadSeed()
  local laws = {}
  for i = 1, 5 do
    local path = string.format("/international_code/seed/%03d.lua", i)
    if fs.exists(path) then
      local ok, chunk = pcall(dofile, path)
      if ok and type(chunk) == "table" then
        for _, entry in ipairs(chunk) do
          local law = entry
          if entry.number == nil and type(entry[1]) == "number" then
            local n = entry[1]
            law = {
              number = n,
              ref = string.format("UNS-ART-%03d", n),
              title = entry[2] or ("Article " .. n),
              body = entry[3] or "",
              book = bookNames[math.ceil(n / 20)] or "",
              section = "",
              status = "draft",
              version = 1,
              history = {}
            }
          end
          if type(law) == "table" and law.number and law.ref then
            laws[#laws + 1] = law
          end
        end
      end
    end
  end
  table.sort(laws, function(a,b) return (a.number or 0) < (b.number or 0) end)
  return laws
end

local function freshState()
  local seed = loadSeed()
  local laws = {}
  local maxN = 0
  local now = common.now()
  for _, law in ipairs(seed) do
    law.createdAt = law.createdAt or now
    law.updatedAt = law.updatedAt or now
    law.version = law.version or 1
    law.status = law.status or "draft"
    law.history = law.history or {}
    laws[law.ref] = law
    if (law.number or 0) > maxN then maxN = law.number end
  end
  return {
    meta = {
      schema = 1, version = common.VERSION, revision = 0,
      createdAt = now, updatedAt = now, codeStatus = "PROJECT_NON_RATIFIED",
      organization = "Union des Nations Souveraines",
      court = "Cour internationale de l'Union",
      proposingState = "North Coalition"
    },
    laws = laws,
    nextArticle = maxN + 1,
    cases = {},
    caseCounters = {},
    clients = {},
    pairing = nil,
    audit = {}
  }
end

local function loadState()
  common.ensureLayout()
  local state = common.loadTable(common.STATE, nil)
  if not state then
    state = freshState()
    common.saveTableAtomic(common.STATE, state)
  end
  state.laws = state.laws or {}
  state.cases = state.cases or {}
  state.clients = state.clients or {}
  state.audit = state.audit or {}
  state.caseCounters = state.caseCounters or {}
  state.nextArticle = state.nextArticle or 1
  return state
end

local function saveState(state)
  state.meta.updatedAt = common.now()
  common.saveTableAtomic(common.STATE, state)
end

local function backup(state, reason)
  common.ensureLayout()
  local stamp = tostring(common.nowMs())
  local path = common.BACKUPS .. "/state-" .. stamp .. ".tbl"
  common.saveTableAtomic(path, state)
  local files = fs.list(common.BACKUPS)
  table.sort(files)
  while #files > 12 do
    fs.delete(common.BACKUPS .. "/" .. table.remove(files, 1))
  end
  return path
end

local function audit(state, actor, action, objectId, details)
  local entry = {
    at = common.now(), actor = actor.label or actor.clientId or "server",
    role = actor.role or "server", action = action, objectId = objectId,
    details = details or "", revision = (state.meta.revision or 0) + 1
  }
  state.meta.revision = entry.revision
  state.audit[#state.audit + 1] = entry
  while #state.audit > 1200 do table.remove(state.audit, 1) end
end

local function mutate(state, actor, action, objectId, details)
  audit(state, actor, action, objectId, details)
  saveState(state)
  if state.meta.revision % 10 == 0 then backup(state, "revision") end
end

local function listLaws(state, payload)
  payload = payload or {}
  local q = common.trim(payload.query)
  local status = common.trim(payload.status)
  local items = {}
  for _, law in pairs(state.laws) do
    local hit = (q == "" or common.contains(law.ref, q) or common.contains(law.title, q) or common.contains(law.body, q))
    local statusHit = (status == "" or law.status == status)
    if hit and statusHit then items[#items + 1] = {
      ref=law.ref, number=law.number, title=law.title, status=law.status,
      version=law.version, book=law.book, section=law.section, updatedAt=law.updatedAt
    } end
  end
  table.sort(items, function(a,b) return (a.number or 0) < (b.number or 0) end)
  return items
end

local function listCases(state, payload)
  payload = payload or {}
  local q = common.trim(payload.query)
  local items = {}
  for _, c in pairs(state.cases) do
    if q == "" or common.contains(c.id, q) or common.contains(c.title, q) or common.contains(c.accused, q) or common.contains(c.complainant, q) then
      items[#items+1] = { id=c.id, title=c.title, status=c.status, accused=c.accused, complainant=c.complainant, updatedAt=c.updatedAt }
    end
  end
  table.sort(items, function(a,b) return tostring(a.id) > tostring(b.id) end)
  return items
end

local function normalizeArticleRef(s)
  s = common.trim(s):upper()
  local n = tonumber(s:match("(%d+)$"))
  if n then return string.format("UNS-ART-%03d", n) end
  return s
end

local function makeCaseId(state)
  local year = os.date and os.date("%Y") or "0000"
  local n = (state.caseCounters[year] or 0) + 1
  state.caseCounters[year] = n
  return string.format("CASE-%s-%04d", year, n)
end

local function handleAction(state, actor, action, p)
  p = p or {}
  if action == "PING" then return { pong=true, time=common.now(), revision=state.meta.revision } end
  if action == "SERVER_INFO" then
    return { meta=state.meta, clientsCount=(function() local n=0 for _ in pairs(state.clients) do n=n+1 end return n end)() }
  end
  if action == "DASHBOARD" then
    local lc, cc = 0, 0
    for _ in pairs(state.laws) do lc=lc+1 end
    for _ in pairs(state.cases) do cc=cc+1 end
    return { laws=lc, cases=cc, revision=state.meta.revision, codeStatus=state.meta.codeStatus }
  end
  if action == "LAW_LIST" then return listLaws(state, p) end
  if action == "LAW_GET" then return common.deepcopy(state.laws[normalizeArticleRef(p.ref)]) end

  if action == "LAW_CREATE" then
    local n = state.nextArticle
    state.nextArticle = n + 1
    local ref = string.format("UNS-ART-%03d", n)
    local law = {
      number=n, ref=ref, title=common.trim(p.title), body=common.trim(p.body),
      book=common.trim(p.book), section=common.trim(p.section), status=p.status or "draft",
      version=1, createdAt=common.now(), updatedAt=common.now(), history={}
    }
    if law.title == "" or law.body == "" then return nil, "Titre et texte obligatoires." end
    state.laws[ref] = law
    mutate(state, actor, "LAW_CREATE", ref, law.title)
    return common.deepcopy(law)
  end

  if action == "LAW_AMEND" then
    local ref = normalizeArticleRef(p.ref)
    local law = state.laws[ref]
    if not law then return nil, "Article introuvable." end
    law.history = law.history or {}
    law.history[#law.history+1] = {
      version=law.version, title=law.title, body=law.body, book=law.book,
      section=law.section, status=law.status, archivedAt=common.now(), archivedBy=actor.label
    }
    law.version = (law.version or 1) + 1
    if common.trim(p.title) ~= "" then law.title = common.trim(p.title) end
    if common.trim(p.body) ~= "" then law.body = common.trim(p.body) end
    if p.book ~= nil then law.book = common.trim(p.book) end
    if p.section ~= nil then law.section = common.trim(p.section) end
    law.updatedAt = common.now()
    mutate(state, actor, "LAW_AMEND", ref, "Version " .. law.version)
    return common.deepcopy(law)
  end

  if action == "LAW_REPEAL" then
    local ref = normalizeArticleRef(p.ref)
    local law = state.laws[ref]
    if not law then return nil, "Article introuvable." end
    if law.status == "repealed" then return nil, "Article deja abroge." end
    law.history = law.history or {}
    law.history[#law.history+1] = {
      version=law.version, status=law.status, body=law.body,
      archivedAt=common.now(), archivedBy=actor.label
    }
    law.version = (law.version or 1) + 1
    law.status = "repealed"
    law.repealReason = common.trim(p.reason)
    law.updatedAt = common.now()
    mutate(state, actor, "LAW_REPEAL", ref, law.repealReason)
    return common.deepcopy(law)
  end

  if action == "LAW_SET_STATUS" then
    local ref = normalizeArticleRef(p.ref)
    local law = state.laws[ref]
    if not law then return nil, "Article introuvable." end
    local allowed = {draft=true, active=true, suspended=true, repealed=true}
    if not allowed[p.status] then return nil, "Statut invalide." end
    law.history = law.history or {}
    law.history[#law.history+1] = {
      version=law.version, status=law.status,
      archivedAt=common.now(), archivedBy=actor.label
    }
    law.version = (law.version or 1) + 1
    law.status = p.status
    law.updatedAt = common.now()
    mutate(state, actor, "LAW_SET_STATUS", ref, p.status)
    return common.deepcopy(law)
  end

  if action == "CASE_LIST" then return listCases(state, p) end
  if action == "CASE_GET" then return common.deepcopy(state.cases[common.trim(p.id):upper()]) end

  if action == "CASE_CREATE" then
    local id = makeCaseId(state)
    local c = {
      id=id, title=common.trim(p.title), complainant=common.trim(p.complainant), accused=common.trim(p.accused),
      summary=common.trim(p.summary), status="open", facts={}, evidence={}, citedArticles={}, judgments={},
      createdAt=common.now(), updatedAt=common.now(), createdBy=actor.label
    }
    if c.title == "" then return nil, "Titre obligatoire." end
    state.cases[id] = c
    mutate(state, actor, "CASE_CREATE", id, c.title)
    return common.deepcopy(c)
  end

  if action == "CASE_UPDATE_SUMMARY" then
    local c = state.cases[common.trim(p.id):upper()]
    if not c then return nil, "Dossier introuvable." end
    c.summary = common.trim(p.summary)
    c.updatedAt = common.now()
    mutate(state, actor, "CASE_UPDATE_SUMMARY", c.id, "Contexte modifie")
    return common.deepcopy(c)
  end

  if action == "CASE_ADD_FACT" then
    local c = state.cases[common.trim(p.id):upper()]
    if not c then return nil, "Dossier introuvable." end
    local fact = { id=#c.facts+1, text=common.trim(p.text), at=common.now(), by=actor.label }
    if fact.text == "" then return nil, "Fait vide." end
    c.facts[#c.facts+1] = fact
    c.updatedAt=common.now()
    mutate(state, actor, "CASE_ADD_FACT", c.id, fact.text:sub(1,80))
    return common.deepcopy(c)
  end

  if action == "CASE_ADD_EVIDENCE" then
    local c = state.cases[common.trim(p.id):upper()]
    if not c then return nil, "Dossier introuvable." end
    local e = {
      id=#c.evidence+1, label=common.trim(p.label), description=common.trim(p.description),
      source=common.trim(p.source), at=common.now(), by=actor.label
    }
    if e.label == "" then e.label = "Preuve " .. e.id end
    c.evidence[#c.evidence+1] = e
    c.updatedAt=common.now()
    mutate(state, actor, "CASE_ADD_EVIDENCE", c.id, e.label)
    return common.deepcopy(c)
  end

  if action == "CASE_ADD_ARTICLE" then
    local c = state.cases[common.trim(p.id):upper()]
    if not c then return nil, "Dossier introuvable." end
    local ref = normalizeArticleRef(p.ref)
    if not state.laws[ref] then return nil, "Article introuvable." end
    for _, x in ipairs(c.citedArticles) do
      if x == ref then return common.deepcopy(c) end
    end
    c.citedArticles[#c.citedArticles+1] = ref
    c.updatedAt=common.now()
    mutate(state, actor, "CASE_ADD_ARTICLE", c.id, ref)
    return common.deepcopy(c)
  end

  if action == "CASE_REMOVE_ARTICLE" then
    local c = state.cases[common.trim(p.id):upper()]
    if not c then return nil, "Dossier introuvable." end
    local ref = normalizeArticleRef(p.ref)
    for i=#c.citedArticles,1,-1 do
      if c.citedArticles[i] == ref then table.remove(c.citedArticles,i) end
    end
    c.updatedAt=common.now()
    mutate(state, actor, "CASE_REMOVE_ARTICLE", c.id, ref)
    return common.deepcopy(c)
  end

  if action == "CASE_ADD_JUDGMENT" then
    local c = state.cases[common.trim(p.id):upper()]
    if not c then return nil, "Dossier introuvable." end
    local j = {
      id=#c.judgments+1, date=common.now(), judge=actor.label,
      verdict=common.trim(p.verdict), reasoning=common.trim(p.reasoning),
      sanctions=common.trim(p.sanctions), citedArticles=common.deepcopy(c.citedArticles),
      final=p.final == true
    }
    if j.verdict == "" or j.reasoning == "" then return nil, "Decision et motifs obligatoires." end
    c.judgments[#c.judgments+1] = j
    if j.final then c.status = "judged" end
    c.updatedAt=common.now()
    mutate(state, actor, "CASE_ADD_JUDGMENT", c.id, j.verdict:sub(1,80))
    return common.deepcopy(c)
  end

  if action == "CASE_SET_STATUS" then
    local c = state.cases[common.trim(p.id):upper()]
    if not c then return nil, "Dossier introuvable." end
    local allowed={open=true,investigation=true,hearing=true,judged=true,appeal=true,closed=true,archived=true}
    if not allowed[p.status] then return nil, "Statut invalide." end
    c.status=p.status
    c.updatedAt=common.now()
    mutate(state, actor, "CASE_SET_STATUS", c.id, p.status)
    return common.deepcopy(c)
  end

  if action == "AUDIT_LIST" then
    local out = {}
    local start = math.max(1, #state.audit - (tonumber(p.limit) or 60) + 1)
    for i=#state.audit,start,-1 do out[#out+1]=common.deepcopy(state.audit[i]) end
    return out
  end

  return nil, "Action inconnue."
end

local function auth(state, sender, msg)
  if type(msg) ~= "table" then return nil, "Message invalide." end
  local client = state.clients[msg.clientId or ""]
  if not client then return nil, "Terminal non autorise." end
  if client.token ~= msg.token then return nil, "Jeton invalide." end
  if client.computerId and client.computerId ~= sender then return nil, "Identite terminal invalide." end
  if not can(client.role, msg.action) then return nil, "Permission refusee pour " .. tostring(msg.action) end
  return client
end

local function pair(state, sender, msg)
  local p = state.pairing
  if not p or p.used then return false, "Aucun appairage actif." end
  if common.nowMs() > (p.expiresMs or 0) then
    state.pairing=nil
    saveState(state)
    return false, "Code expire."
  end
  if tostring(msg.code or "") ~= tostring(p.code) then return false, "Code incorrect." end

  local id = "CLIENT-" .. tostring(sender) .. "-" .. common.randomToken(6)
  local token = common.randomToken(38)
  state.clients[id] = {
    clientId=id, computerId=sender, token=token, role=p.role,
    label=common.safeName(msg.label), createdAt=common.now(), lastSeen=common.now()
  }
  p.used = true
  audit(state, {label="server",role="server"}, "CLIENT_PAIR", id, p.role .. ": " .. state.clients[id].label)
  state.pairing = nil
  saveState(state)

  return true, {
    clientId=id, token=token, role=state.clients[id].role,
    label=state.clients[id].label, serverId=os.getComputerID()
  }
end

local function generatePair(state, role)
  if not permissions[role] then return nil end
  state.pairing = {
    code=common.pairCode(), role=role,
    expiresMs=common.nowMs()+300000,
    createdAt=common.now(), used=false
  }
  saveState(state)
  return state.pairing.code
end

local function serverUI(state, lastEvent)
  local w,h=term.getSize()
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setBackgroundColor(colors.blue)
  term.setCursorPos(1,1)
  term.clearLine()
  term.write(common.fit(" UNS / INTERNATIONAL CODE SERVER",w))

  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.lightGray)
  term.setCursorPos(2,3)
  term.write("Server ID : " .. os.getComputerID())
  term.setCursorPos(2,4)
  term.write("Revision  : " .. tostring(state.meta.revision))

  local lc,cc,cl=0,0,0
  for _ in pairs(state.laws) do lc=lc+1 end
  for _ in pairs(state.cases) do cc=cc+1 end
  for _ in pairs(state.clients) do cl=cl+1 end

  term.setCursorPos(2,5)
  term.write("Articles  : "..lc.."   Dossiers: "..cc.."   Clients: "..cl)
  term.setTextColor(colors.cyan)
  term.setCursorPos(2,7)
  term.write("[P] Appairer un terminal   [B] Backup   [Q] Arreter")

  if state.pairing then
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.setCursorPos(2,9)
    term.write(common.fit(" CODE "..state.pairing.code.." / role "..state.pairing.role.." / 5 min ", math.max(1,w-2)))
    term.setBackgroundColor(colors.black)
  end

  term.setTextColor(colors.lightGray)
  term.setCursorPos(2,h-2)
  term.write(common.fit("Dernier evenement: "..tostring(lastEvent or "Serveur demarre"), math.max(1,w-3)))
  term.setCursorPos(2,h)
  term.setTextColor(colors.gray)
  term.write(common.fit("UNS-CIC / v"..common.VERSION.." / rednet "..common.PROTOCOL, math.max(1,w-2)))
end

local function chooseRole()
  local roles={"writer","clerk","judge","viewer","admin"}
  term.setBackgroundColor(colors.black)
  term.clear()
  term.setCursorPos(2,2)
  term.setTextColor(colors.cyan)
  term.write("ROLE DU TERMINAL")
  for i,r in ipairs(roles) do
    term.setCursorPos(4,3+i)
    term.setTextColor(colors.white)
    term.write(i..". "..r)
  end
  term.setCursorPos(2,10)
  term.setTextColor(colors.lightGray)
  term.write("Choix: ")
  local n=tonumber(read())
  return roles[n or 0]
end

function S.run()
  common.ensureLayout()
  local cfg = common.loadConfig()
  if not cfg or cfg.role ~= "server" then
    error("Ce PC n'est pas configure comme serveur. Lancez: ic setup server",0)
  end
  if common.openModems() == 0 then
    error("Aucun modem detecte. Connectez un modem avant de lancer le serveur.",0)
  end

  local state=loadState()
  pcall(rednet.host, common.PROTOCOL, cfg.serverName or ("uns-code-"..os.getComputerID()))
  local lastEvent="Serveur pret"
  serverUI(state,lastEvent)

  while true do
    local timer=os.startTimer(1)
    local ev,a,b,c = os.pullEvent()

    if ev=="rednet_message" and c==common.PROTOCOL then
      local sender,msg=a,b
      if type(msg)=="table" and msg.kind=="pair_request" then
        local ok,data=pair(state,sender,msg)
        rednet.send(sender,{
          kind="pair_response",requestId=msg.requestId,ok=ok,
          data=ok and data or nil,error=ok and nil or data
        },common.PROTOCOL)
        lastEvent=ok and ("Appairage PC #"..sender) or ("Appairage refuse PC #"..sender)

      elseif type(msg)=="table" and msg.kind=="request" then
        local actor,err=auth(state,sender,msg)
        local ok,data,actionErr=false,nil,nil
        if actor then
          actor.lastSeen=common.now()
          local callOk,r1,r2=pcall(handleAction,state,actor,msg.action,msg.payload)
          if callOk and r1~=nil then
            ok=true
            data=r1
          else
            actionErr=callOk and r2 or r1
          end
        else
          actionErr=err
        end

        rednet.send(sender,{
          kind="response",requestId=msg.requestId,ok=ok,
          data=data,error=actionErr
        },common.PROTOCOL)
        lastEvent=(msg.action or "?").." / PC #"..sender..(ok and " / OK" or " / REFUS")
      end
      serverUI(state,lastEvent)

    elseif ev=="key" then
      if a==keys.p then
        local role=chooseRole()
        if role then
          local code=generatePair(state,role)
          lastEvent="Code "..code.." cree pour "..role
        else
          lastEvent="Appairage annule"
        end
        serverUI(state,lastEvent)
      elseif a==keys.b then
        local path=backup(state,"manual")
        lastEvent="Backup: "..path
        serverUI(state,lastEvent)
      elseif a==keys.q then
        saveState(state)
        term.setBackgroundColor(colors.black)
        term.clear()
        term.setCursorPos(1,1)
        return
      end

    elseif ev=="timer" and a==timer then
      if state.pairing and common.nowMs() > state.pairing.expiresMs then
        state.pairing=nil
        saveState(state)
        lastEvent="Code d'appairage expire"
      end
      serverUI(state,lastEvent)
    end
  end
end

function S.setupServer()
  common.ensureLayout()
  term.setTextColor(colors.white)
  print("Nom du serveur [UNS-Code]:")
  local name=common.trim(read())
  if name=="" then name="UNS-Code" end
  local cfg={
    role="server",serverName=name,installedAt=common.now(),version=common.VERSION
  }
  common.saveConfig(cfg)
  if not fs.exists(common.STATE) then
    common.saveTableAtomic(common.STATE,freshState())
  end
  print("Serveur configure. ID #"..os.getComputerID())
  print("Connectez un modem puis lancez: ic server")
end

function S.manualPair(role)
  local state=loadState()
  if not permissions[role] then error("Role invalide",0) end
  local code=generatePair(state,role)
  print("Code d'appairage unique (5 min): "..code)
  print("Le serveur doit ensuite etre lance avec: ic server")
end

function S.backupNow()
  local state=loadState()
  print("Backup cree: "..backup(state,"manual"))
end

return S
