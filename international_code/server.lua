local common = dofile("/international_code/common.lua")
local S = {}

local permissions = {
  viewer = {
    PING=true, DASHBOARD=true, SERVER_INFO=true, VERIFY_SEAL=true,
    NOTICE_LIST=true, NOTICE_MARK_READ=true, NOTICE_MARK_ALL=true,
    ENFORCEMENT_LIST=true, ENFORCEMENT_GET=true,
    LAW_LIST=true, LAW_GET=true, LAW_BOOKS=true,
    CASE_LIST=true, CASE_GET=true,
    STATE_LIST=true, STATE_GET=true,
    BILL_LIST=true, BILL_GET=true, TREATY_LIST=true, TREATY_GET=true
  },
  writer = {
    PING=true, DASHBOARD=true, SERVER_INFO=true, VERIFY_SEAL=true,
    NOTICE_LIST=true, NOTICE_MARK_READ=true, NOTICE_MARK_ALL=true,
    ENFORCEMENT_LIST=true, ENFORCEMENT_GET=true,
    LAW_LIST=true, LAW_GET=true, LAW_BOOKS=true,
    CASE_LIST=true, CASE_GET=true,
    STATE_LIST=true, STATE_GET=true,
    BILL_LIST=true, BILL_GET=true, TREATY_LIST=true, TREATY_GET=true, BILL_CREATE=true, BILL_EDIT=true, BILL_SET_STAGE=true,
    BILL_OPEN_VOTE=true, BILL_CLOSE=true, BILL_ENACT=true,
    TREATY_CREATE=true, TREATY_EDIT=true, TREATY_OPEN_SIGNATURE=true, TREATY_ACTIVATE=true, TREATY_TERMINATE=true,
    LAW_CREATE=true, LAW_AMEND=true, LAW_REPEAL=true, LAW_SET_STATUS=true,
    AUDIT_LIST=true
  },
  clerk = {
    PING=true, DASHBOARD=true, SERVER_INFO=true, VERIFY_SEAL=true,
    NOTICE_LIST=true, NOTICE_MARK_READ=true, NOTICE_MARK_ALL=true,
    ENFORCEMENT_LIST=true, ENFORCEMENT_GET=true,
    LAW_LIST=true, LAW_GET=true, LAW_BOOKS=true,
    CASE_LIST=true, CASE_GET=true, CASE_CREATE=true, CASE_UPDATE_SUMMARY=true,
    CASE_ADD_FACT=true, CASE_ADD_EVIDENCE=true, CASE_ADD_ARTICLE=true, CASE_ADD_ARTICLES=true,
    CASE_REMOVE_ARTICLE=true, CASE_SET_STATUS=true,
    CASE_ADD_HEARING=true, CASE_SET_HEARING_STATUS=true, CASE_FILE_APPEAL=true,
    ENFORCEMENT_ADD_PROGRESS=true,
    STATE_LIST=true, STATE_GET=true, BILL_LIST=true, BILL_GET=true, TREATY_LIST=true, TREATY_GET=true,
    AUDIT_LIST=true
  },
  judge = {
    PING=true, DASHBOARD=true, SERVER_INFO=true, VERIFY_SEAL=true,
    NOTICE_LIST=true, NOTICE_MARK_READ=true, NOTICE_MARK_ALL=true,
    ENFORCEMENT_LIST=true, ENFORCEMENT_GET=true,
    LAW_LIST=true, LAW_GET=true, LAW_BOOKS=true,
    CASE_LIST=true, CASE_GET=true, CASE_CREATE=true, CASE_UPDATE_SUMMARY=true,
    CASE_ADD_FACT=true, CASE_ADD_EVIDENCE=true, CASE_ADD_ARTICLE=true, CASE_ADD_ARTICLES=true,
    CASE_REMOVE_ARTICLE=true, CASE_ADD_JUDGMENT=true, CASE_SET_STATUS=true, CASE_SET_VISIBILITY=true,
    CASE_ADD_HEARING=true, CASE_SET_HEARING_STATUS=true, CASE_FILE_APPEAL=true, CASE_DECIDE_APPEAL=true,
    CASE_ADD_ORDER=true, CASE_SET_ORDER_STATUS=true,
    ENFORCEMENT_CREATE=true, ENFORCEMENT_UPDATE=true, ENFORCEMENT_ADD_PROGRESS=true,
    STATE_LIST=true, STATE_GET=true, BILL_LIST=true, BILL_GET=true, TREATY_LIST=true, TREATY_GET=true,
    AUDIT_LIST=true
  },
  delegate = {
    PING=true, DASHBOARD=true, SERVER_INFO=true, VERIFY_SEAL=true,
    NOTICE_LIST=true, NOTICE_MARK_READ=true, NOTICE_MARK_ALL=true,
    ENFORCEMENT_LIST=true, ENFORCEMENT_GET=true,
    LAW_LIST=true, LAW_GET=true, LAW_BOOKS=true,
    CASE_LIST=true, CASE_GET=true,
    STATE_LIST=true, STATE_GET=true,
    BILL_LIST=true, BILL_GET=true, TREATY_LIST=true, TREATY_GET=true, TREATY_SIGN=true, BILL_VOTE=true
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
    states = {
      ["STATE-001"] = {
        id="STATE-001", name="North Coalition", shortName="North Coalition",
        status="member", government="", representative="", notes="Etat proposant du projet initial.",
        createdAt=now, updatedAt=now
      }
    },
    nextState = 2,
    bills = {},
    billCounters = {},
    treaties = {},
    treatyCounters = {},
    enforcements = {},
    enforcementCounters = {},
    notices = {},
    noticeCounter = 0,
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
  state.states = state.states or {}
  state.bills = state.bills or {}
  state.billCounters = state.billCounters or {}
  state.treaties = state.treaties or {}
  state.treatyCounters = state.treatyCounters or {}
  state.enforcements = state.enforcements or {}
  state.enforcementCounters = state.enforcementCounters or {}
  state.notices = state.notices or {}
  state.noticeCounter = state.noticeCounter or 0
  state.meta = state.meta or {}

  if next(state.states)==nil then
    local now=common.now()
    state.states["STATE-001"]={
      id="STATE-001", name="North Coalition", shortName="North Coalition",
      status="member", government="", representative="", notes="Etat proposant du projet initial.",
      createdAt=now, updatedAt=now
    }
  end

  local maxState=0
  for id in pairs(state.states) do
    local n=tonumber(tostring(id):match("STATE%-(%d+)")) or 0
    if n>maxState then maxState=n end
  end
  state.nextState=state.nextState or (maxState+1)

  for _,c in pairs(state.cases) do
    c.visibility=c.visibility or "restricted"
    c.hearings=c.hearings or {}
    c.orders=c.orders or {}
    c.appeals=c.appeals or {}
  end

  state.meta.version = common.VERSION
  state.meta.schema = math.max(tonumber(state.meta.schema) or 1,3)
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

local function lawSearchScore(law, query)
  local q=common.normalizeSearch(query)
  if q=="" then return 0 end

  local ref=common.normalizeSearch(law.ref or "")
  local title=common.normalizeSearch(law.title or "")
  local body=common.normalizeSearch(law.body or "")
  local section=common.normalizeSearch(law.section or "")
  local book=common.normalizeSearch(law.book or "")

  if ref==q then return 1000 end
  if string.find(ref,q,1,true) then return 900 end
  if title==q then return 850 end
  if title:sub(1,#q)==q then return 800 end
  if string.find(title,q,1,true) then return 750 end
  if string.find(section,q,1,true) then return 650 end
  if string.find(book,q,1,true) then return 600 end
  if string.find(body,q,1,true) then return 500 end

  local combined=table.concat({ref,title,section,book,body}," ")
  if common.containsAllTokens(combined,q) then return 350 end
  return -1
end

local function listLaws(state, payload)
  payload = payload or {}
  local q = common.trim(payload.query)
  local status = common.trim(payload.status)
  local book = common.trim(payload.book)
  local items = {}
  for _, law in pairs(state.laws) do
    local score=lawSearchScore(law,q)
    local hit = (q == "" or score>=0)
    local statusHit = (status == "" or law.status == status)
    local bookHit = (book == "" or law.book == book)
    if hit and statusHit and bookHit then items[#items + 1] = {
      ref=law.ref, number=law.number, title=law.title, status=law.status,
      version=law.version, book=law.book, section=law.section, updatedAt=law.updatedAt,
      _score=score
    } end
  end
  table.sort(items, function(a,b)
    if q~="" and (a._score or 0)~=(b._score or 0) then return (a._score or 0)>(b._score or 0) end
    return (a.number or 0) < (b.number or 0)
  end)
  for _,item in ipairs(items) do item._score=nil end
  return items
end

local function listBooks(state)
  local map={}
  for _,law in pairs(state.laws) do
    local name=(law.book and law.book~="") and law.book or "SANS CATEGORIE"
    local b=map[name]
    if not b then
      b={name=name,count=0,first=law.number or 999999,last=law.number or 0}
      map[name]=b
    end
    b.count=b.count+1
    if (law.number or 999999)<b.first then b.first=law.number end
    if (law.number or 0)>b.last then b.last=law.number end
  end
  local out={}
  for _,b in pairs(map) do out[#out+1]=b end
  table.sort(out,function(a,b) return a.first<b.first end)
  return out
end

local function canViewCase(actor,c)
  if not c then return false end
  local role=actor and actor.role or "viewer"
  local visibility=c.visibility or "restricted"
  if role=="admin" or role=="judge" then return true end
  if role=="clerk" then return visibility~="sealed" end
  return visibility=="public"
end

local function listCases(state, payload, actor)
  payload = payload or {}
  local q = common.trim(payload.query)
  local status = common.trim(payload.status)
  local visibility = common.trim(payload.visibility)
  local items = {}
  for _, c in pairs(state.cases) do
    local hit = (q == "" or common.contains(c.id, q) or common.contains(c.title, q) or common.contains(c.accused, q) or common.contains(c.complainant, q))
    local statusHit = (status == "" or c.status == status)
    local visibilityHit = (visibility=="" or (c.visibility or "restricted")==visibility)
    if hit and statusHit and visibilityHit and canViewCase(actor,c) then
      items[#items+1] = {
        id=c.id, title=c.title, status=c.status, visibility=c.visibility or "restricted",
        accused=c.accused, complainant=c.complainant, updatedAt=c.updatedAt
      }
    end
  end
  table.sort(items, function(a,b) return tostring(a.id) > tostring(b.id) end)
  return items
end

local function listStates(state,payload)
  payload=payload or {}
  local q=common.trim(payload.query)
  local status=common.trim(payload.status)
  local out={}
  for _,st in pairs(state.states or {}) do
    local hit=(q=="" or common.contains(st.id,q) or common.contains(st.name,q) or common.contains(st.shortName,q) or common.contains(st.representative,q))
    local statusHit=(status=="" or st.status==status)
    if hit and statusHit then
      out[#out+1]=common.deepcopy(st)
    end
  end
  table.sort(out,function(a,b) return tostring(a.id)<tostring(b.id) end)
  return out
end

local function listBills(state,payload)
  payload=payload or {}
  local q=common.trim(payload.query)
  local stage=common.trim(payload.stage)
  local out={}
  for _,bill in pairs(state.bills or {}) do
    local hit=(q=="" or common.contains(bill.id,q) or common.contains(bill.title,q) or common.contains(bill.summary,q) or common.contains(bill.targetRef,q))
    local stageHit=(stage=="" or bill.stage==stage)
    if hit and stageHit then
      local copy=common.deepcopy(bill)
      copy.votes=nil
      copy.voteHistory=nil
      out[#out+1]=copy
    end
  end
  table.sort(out,function(a,b) return tostring(a.id)>tostring(b.id) end)
  return out
end

local function listTreaties(state,payload)
  payload=payload or {}
  local q=common.trim(payload.query)
  local stage=common.trim(payload.stage)
  local stateId=common.trim(payload.stateId):upper()
  local out={}
  for _,t in pairs(state.treaties or {}) do
    local hit=(q=="" or common.contains(t.id,q) or common.contains(t.title,q) or common.contains(t.summary,q) or common.contains(t.body,q) or common.contains(t.treatyType,q))
    local stageHit=(stage=="" or t.stage==stage)
    local partyHit=(stateId=="")
    if stateId~="" then
      for _,id in ipairs(t.parties or {}) do if id==stateId then partyHit=true break end end
    end
    if hit and stageHit and partyHit then
      local copy=common.deepcopy(t)
      copy.body=nil
      copy.signatureHistory=nil
      out[#out+1]=copy
    end
  end
  table.sort(out,function(a,b) return tostring(a.id)>tostring(b.id) end)
  return out
end

local function makeTreatyId(state)
  local year=os.date and os.date("%Y") or "0000"
  local n=(state.treatyCounters[year] or 0)+1
  state.treatyCounters[year]=n
  return string.format("TREATY-%s-%04d",year,n)
end

local function treatySignatureStatus(state,treaty)
  local required=0
  local signed=0
  local missing={}
  for _,id in ipairs(treaty.parties or {}) do
    if state.states[id] then
      required=required+1
      if treaty.signatures and treaty.signatures[id] then
        signed=signed+1
      else
        missing[#missing+1]=id
      end
    end
  end
  return {required=required,signed=signed,missing=missing,complete=required>0 and signed==required}
end

local function eligibleVotingStates(state)
  local n=0
  for _,st in pairs(state.states or {}) do
    if st.status=="member" then n=n+1 end
  end
  return n
end

local function billTally(state,bill)
  local eligibleSet={}
  local eligible=0

  if type(bill.eligibleStateIds)=="table" and #bill.eligibleStateIds>0 then
    for _,id in ipairs(bill.eligibleStateIds) do
      eligibleSet[id]=true
      eligible=eligible+1
    end
  else
    for id,st in pairs(state.states or {}) do
      if st.status=="member" then
        eligibleSet[id]=true
        eligible=eligible+1
      end
    end
  end

  local yes,no,abstain=0,0,0
  for stateId,v in pairs(bill.votes or {}) do
    if eligibleSet[stateId] then
      if v.choice=="yes" then yes=yes+1
      elseif v.choice=="no" then no=no+1
      else abstain=abstain+1 end
    end
  end

  local participation=yes+no+abstain
  local cast=yes+no
  local quorumRequired=math.ceil(eligible/2)
  local quorumMet=eligible>0 and participation>=quorumRequired
  local threshold=bill.threshold or "simple_cast"
  local adopted=false

  if quorumMet then
    if threshold=="simple_cast" then
      adopted=cast>0 and yes>no
    elseif threshold=="absolute_members" then
      adopted=yes>(eligible/2)
    elseif threshold=="two_thirds_cast" then
      adopted=cast>0 and yes*3>=cast*2
    elseif threshold=="three_quarters_members" then
      adopted=eligible>0 and yes*4>=eligible*3
    end
  end

  return {
    yes=yes,no=no,abstain=abstain,eligible=eligible,cast=cast,
    participation=participation,quorumRequired=quorumRequired,quorumMet=quorumMet,
    threshold=threshold,adopted=adopted
  }
end

local function makeBillId(state)
  local year=os.date and os.date("%Y") or "0000"
  local n=(state.billCounters[year] or 0)+1
  state.billCounters[year]=n
  return string.format("BILL-%s-%04d",year,n)
end

local function getClientState(state,actor)
  if not actor then return nil end
  if actor.stateId and state.states[actor.stateId] then return state.states[actor.stateId] end
  return nil
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

local function ensureCaseShape(c)
  c.facts = c.facts or {}
  c.evidence = c.evidence or {}
  c.citedArticles = c.citedArticles or {}
  c.judgments = c.judgments or {}
  c.timeline = c.timeline or {}
  c.hearings = c.hearings or {}
  c.orders = c.orders or {}
  c.appeals = c.appeals or {}
  c.visibility = c.visibility or "restricted"
  return c
end

local function caseEvent(c, actor, kind, title, details)
  ensureCaseShape(c)
  c.timeline[#c.timeline+1] = {
    at = common.now(),
    by = actor.label or actor.clientId or "server",
    role = actor.role or "server",
    kind = kind,
    title = title or kind,
    details = details or ""
  }
  while #c.timeline > 500 do table.remove(c.timeline,1) end
end

local function officialSeal(prefix,parts)
  local raw={}
  for _,v in ipairs(parts or {}) do
    if type(v)=="table" then raw[#raw+1]=textutils.serialize(v,{compact=true})
    else raw[#raw+1]=tostring(v or "") end
  end
  return tostring(prefix or "UNS").."-"..string.upper(common.simpleChecksum(table.concat(raw,"|")))
end

local function noticeVisible(actor,n)
  if not actor or not n then return false end
  if actor.role=="admin" then return true end

  local targeted=false
  if n.targetClientId then
    targeted=true
    if n.targetClientId~=actor.clientId then return false end
  end
  if n.targetStateId then
    targeted=true
    if n.targetStateId~=actor.stateId then return false end
  end
  if type(n.roles)=="table" and next(n.roles)~=nil then
    targeted=true
    if not n.roles[actor.role] then return false end
  end
  return targeted or n.global==true
end

local function pushNotice(state,spec)
  state.noticeCounter=(state.noticeCounter or 0)+1
  local id=string.format("NOTICE-%06d",state.noticeCounter)
  local n={
    id=id,title=common.trim(spec.title),body=common.trim(spec.body),
    severity=spec.severity or "info",
    objectType=spec.objectType,objectId=spec.objectId,
    targetStateId=spec.targetStateId,targetClientId=spec.targetClientId,
    roles=spec.roles,global=spec.global==true,
    createdAt=common.now(),readBy={}
  }
  state.notices[#state.notices+1]=n
  while #state.notices>800 do table.remove(state.notices,1) end
  return n
end

local function listNotices(state,actor,payload)
  payload=payload or {}
  local unreadOnly=payload.unreadOnly==true
  local out={}
  for i=#(state.notices or {}),1,-1 do
    local n=state.notices[i]
    if noticeVisible(actor,n) then
      local copy=common.deepcopy(n)
      copy.read=(n.readBy and n.readBy[actor.clientId])==true
      copy.readBy=nil
      if (not unreadOnly) or not copy.read then out[#out+1]=copy end
    end
    if #out>120 then break end
  end
  return out
end

local function countUnreadNotices(state,actor)
  local n=0
  for _,notice in ipairs(state.notices or {}) do
    if noticeVisible(actor,notice) and not (notice.readBy and notice.readBy[actor.clientId]) then n=n+1 end
  end
  return n
end

local function makeEnforcementId(state)
  local year=os.date and os.date("%Y") or "0000"
  local n=(state.enforcementCounters[year] or 0)+1
  state.enforcementCounters[year]=n
  return string.format("ENF-%s-%04d",year,n)
end

local function canViewEnforcement(actor,e)
  if not actor or not e then return false end
  if actor.role=="admin" or actor.role=="judge" or actor.role=="clerk" then return true end
  return (e.visibility or "restricted")=="public"
end

local function listEnforcements(state,actor,payload)
  payload=payload or {}
  local q=common.trim(payload.query)
  local status=common.trim(payload.status)
  local stateId=common.trim(payload.stateId):upper()
  local caseId=common.trim(payload.caseId):upper()
  local visibility=common.trim(payload.visibility)
  local out={}
  for _,e in pairs(state.enforcements or {}) do
    local hit=(q=="" or common.contains(e.id,q) or common.contains(e.targetName,q) or common.contains(e.summary,q) or common.contains(e.enforcementType,q) or common.contains(e.caseId,q))
    local statusHit=(status=="" or e.status==status)
    local stateHit=(stateId=="" or e.targetStateId==stateId)
    local caseHit=(caseId=="" or e.caseId==caseId)
    local visibilityHit=(visibility=="" or (e.visibility or "restricted")==visibility)
    if hit and statusHit and stateHit and caseHit and visibilityHit and canViewEnforcement(actor,e) then
      out[#out+1]=common.deepcopy(e)
    end
  end
  table.sort(out,function(a,b) return tostring(a.id)>tostring(b.id) end)
  return out
end

local function handleAction(state, actor, action, p)
  p = p or {}
  if action:match("^CASE_") and action~="CASE_LIST" and action~="CASE_GET" and action~="CASE_CREATE" and p.id then
    local guarded=state.cases[common.trim(p.id):upper()]
    if guarded and not canViewCase(actor,guarded) then return nil,"Acces refuse a ce dossier." end
  end
  if action == "NOTICE_LIST" then
    return listNotices(state,actor,p)
  end

  if action == "NOTICE_MARK_READ" then
    local id=common.trim(p.id)
    for _,n in ipairs(state.notices or {}) do
      if n.id==id and noticeVisible(actor,n) then
        n.readBy=n.readBy or {}
        n.readBy[actor.clientId]=true
        saveState(state)
        return {ok=true,id=id}
      end
    end
    return nil,"Notification introuvable."
  end

  if action == "NOTICE_MARK_ALL" then
    local count=0
    for _,n in ipairs(state.notices or {}) do
      if noticeVisible(actor,n) then
        n.readBy=n.readBy or {}
        if not n.readBy[actor.clientId] then
          n.readBy[actor.clientId]=true
          count=count+1
        end
      end
    end
    saveState(state)
    return {count=count}
  end

  if action == "ENFORCEMENT_LIST" then
    return listEnforcements(state,actor,p)
  end

  if action == "ENFORCEMENT_GET" then
    local e=state.enforcements[common.trim(p.id):upper()]
    if not e then return nil,"Mesure d'execution introuvable." end
    if not canViewEnforcement(actor,e) then return nil,"Acces refuse a cette mesure." end
    return common.deepcopy(e)
  end

  if action == "ENFORCEMENT_CREATE" then
    local caseId=common.trim(p.caseId):upper()
    local case=nil
    if caseId~="" then
      case=state.cases[caseId]
      if not case then return nil,"Dossier lie introuvable." end
      if not canViewCase(actor,case) then return nil,"Acces refuse au dossier lie." end
    end

    local targetStateId=common.trim(p.targetStateId):upper()
    local targetName=common.trim(p.targetName)
    if targetStateId~="" then
      local st=state.states[targetStateId]
      if not st then return nil,"Etat cible introuvable." end
      if targetName=="" then targetName=st.name end
    end
    if targetName=="" then return nil,"Cible obligatoire." end

    local enforcementType=common.trim(p.enforcementType)
    if enforcementType=="" then enforcementType="other" end
    local terms=common.trim(p.terms)
    if terms=="" then return nil,"Conditions d'execution obligatoires." end

    local id=makeEnforcementId(state)
    local e={
      id=id,caseId=caseId,judgmentId=common.trim(p.judgmentId),
      targetType=common.trim(p.targetType),targetStateId=targetStateId,targetName=targetName,
      enforcementType=enforcementType,summary=common.trim(p.summary),terms=terms,
      amount=common.trim(p.amount),deadline=common.trim(p.deadline),
      status="ordered",visibility=p.visibility=="public" and "public" or "restricted",
      progress={},statusHistory={},
      createdAt=common.now(),createdBy=actor.label,updatedAt=common.now()
    }
    if e.targetType=="" then e.targetType=targetStateId~="" and "state" or "other" end
    e.seal=officialSeal("CIU-ENF",{e.id,e.caseId,e.judgmentId,e.targetType,e.targetStateId,e.targetName,e.enforcementType,e.summary,e.terms,e.amount,e.deadline,e.createdAt,e.createdBy})
    state.enforcements[id]=e

    if targetStateId~="" then
      pushNotice(state,{
        title="Nouvelle mesure d'execution "..id,
        body=e.enforcementType.." / "..e.summary,
        severity="warning",objectType="enforcement",objectId=id,targetStateId=targetStateId
      })
    end
    pushNotice(state,{
      title="Mesure d'execution enregistree",
      body=id.." / "..targetName,
      severity="info",objectType="enforcement",objectId=id,
      roles={judge=true,clerk=true,admin=true}
    })

    mutate(state,actor,"ENFORCEMENT_CREATE",id,targetName.." / "..enforcementType)
    return common.deepcopy(e)
  end

  if action == "ENFORCEMENT_ADD_PROGRESS" then
    local e=state.enforcements[common.trim(p.id):upper()]
    if not e then return nil,"Mesure d'execution introuvable." end
    if not canViewEnforcement(actor,e) then return nil,"Acces refuse a cette mesure." end
    local note=common.trim(p.note)
    if note=="" then return nil,"Compte rendu vide." end
    e.progress=e.progress or {}
    local row={
      id=#e.progress+1,note=note,at=common.now(),by=actor.label,
      reference=common.trim(p.reference)
    }
    row.seal=officialSeal("CIU-ENFLOG",{e.id,row.id,row.note,row.reference,row.at,row.by})
    e.progress[#e.progress+1]=row
    e.updatedAt=common.now()
    mutate(state,actor,"ENFORCEMENT_ADD_PROGRESS",e.id,note:sub(1,100))
    return common.deepcopy(e)
  end

  if action == "ENFORCEMENT_UPDATE" then
    local e=state.enforcements[common.trim(p.id):upper()]
    if not e then return nil,"Mesure d'execution introuvable." end
    local allowed={ordered=true,active=true,partial=true,complied=true,breached=true,lifted=true,expired=true}
    if not allowed[p.status] then return nil,"Statut d'execution invalide." end
    if e.status==p.status and common.trim(p.reason)=="" then return common.deepcopy(e) end

    local previous=e.status
    local reason=common.trim(p.reason)
    e.statusHistory=e.statusHistory or {}
    local row={
      from=previous,to=p.status,reason=reason,at=common.now(),by=actor.label
    }
    row.seal=officialSeal("CIU-ENFSTAT",{e.id,row.from,row.to,row.reason,row.at,row.by,e.seal})
    e.statusHistory[#e.statusHistory+1]=row
    e.status=p.status
    e.updatedAt=common.now()
    e.updatedBy=actor.label

    if e.targetStateId and e.targetStateId~="" then
      pushNotice(state,{
        title="Mise a jour execution "..e.id,
        body=previous.." -> "..p.status..(reason~="" and (" / "..reason) or ""),
        severity=p.status=="breached" and "critical" or "info",
        objectType="enforcement",objectId=e.id,targetStateId=e.targetStateId
      })
    end

    mutate(state,actor,"ENFORCEMENT_UPDATE",e.id,previous.." -> "..p.status..(reason~="" and (" / "..reason) or ""))
    return common.deepcopy(e)
  end

  if action == "VERIFY_SEAL" then
    local seal=common.trim(p.seal):upper()
    if seal=="" then return nil,"Sceau vide." end

    for _,c in pairs(state.cases or {}) do
      ensureCaseShape(c)
      local visible=canViewCase(actor,c)
      for _,j in ipairs(c.judgments or {}) do
        if tostring(j.seal or ""):upper()==seal then
          return {
            valid=true,kind="judgment",seal=seal,parentId=c.id,
            title=visible and c.title or "Document judiciaire confidentiel",
            reference="J"..tostring(j.id or "?"),status=j.final and "final" or "intermediate",
            issuedAt=j.date,issuedBy=visible and j.judge or nil,confidential=not visible
          }
        end
      end
      for _,h in ipairs(c.hearings or {}) do
        if tostring(h.seal or ""):upper()==seal then
          return {
            valid=true,kind="hearing",seal=seal,parentId=c.id,
            title=visible and h.subject or "Document judiciaire confidentiel",
            reference=h.id,status=h.status,issuedAt=h.createdAt,
            issuedBy=visible and h.createdBy or nil,confidential=not visible
          }
        end
      end
      for _,o in ipairs(c.orders or {}) do
        if tostring(o.seal or ""):upper()==seal then
          return {
            valid=true,kind="order",seal=seal,parentId=c.id,
            title=visible and o.subject or "Document judiciaire confidentiel",
            reference=o.id,status=o.status,issuedAt=o.createdAt,
            issuedBy=visible and o.createdBy or nil,confidential=not visible
          }
        end
      end
      for _,a in ipairs(c.appeals or {}) do
        if tostring(a.seal or ""):upper()==seal then
          return {
            valid=true,kind="appeal_filing",seal=seal,parentId=c.id,
            title=visible and ("Appel "..(a.id or "")) or "Document judiciaire confidentiel",
            reference=a.id,status=a.status,issuedAt=a.filedAt,
            issuedBy=visible and a.filedBy or nil,confidential=not visible
          }
        end
        if tostring(a.decisionSeal or ""):upper()==seal then
          return {
            valid=true,kind="appeal_decision",seal=seal,parentId=c.id,
            title=visible and ("Decision d'appel "..(a.id or "")) or "Document judiciaire confidentiel",
            reference=a.id,status=a.result,issuedAt=a.decidedAt,
            issuedBy=visible and a.decidedBy or nil,confidential=not visible
          }
        end
      end
    end

    for _,e in pairs(state.enforcements or {}) do
      if tostring(e.seal or ""):upper()==seal then
        local visible=canViewEnforcement(actor,e)
        return {
          valid=true,kind="enforcement",seal=seal,parentId=e.caseId~="" and e.caseId or e.id,
          title=visible and (e.summary~="" and e.summary or e.targetName) or "Mesure d'execution confidentielle",
          reference=e.id,status=e.status,issuedAt=e.createdAt,
          issuedBy=visible and e.createdBy or nil,confidential=not visible
        }
      end
      for _,row in ipairs(e.progress or {}) do
        if tostring(row.seal or ""):upper()==seal then
          local visible=canViewEnforcement(actor,e)
          return {
            valid=true,kind="enforcement_log",seal=seal,parentId=e.id,
            title=visible and ("Suivi d'execution #"..tostring(row.id or "?")) or "Suivi d'execution confidentiel",
            reference=tostring(row.id or "?"),status=e.status,issuedAt=row.at,
            issuedBy=visible and row.by or nil,confidential=not visible
          }
        end
      end
      for i,row in ipairs(e.statusHistory or {}) do
        if tostring(row.seal or ""):upper()==seal then
          local visible=canViewEnforcement(actor,e)
          return {
            valid=true,kind="enforcement_status",seal=seal,parentId=e.id,
            title=visible and ("Changement de statut "..tostring(row.from).." -> "..tostring(row.to)) or "Suivi d'execution confidentiel",
            reference=tostring(i),status=row.to,issuedAt=row.at,
            issuedBy=visible and row.by or nil,confidential=not visible
          }
        end
      end
    end

    for _,bill in pairs(state.bills or {}) do
      if tostring(bill.resultSeal or ""):upper()==seal then
        return {valid=true,kind="vote_result",seal=seal,parentId=bill.id,title=bill.title,status=bill.result,issuedAt=bill.closedAt,issuedBy=bill.closedBy}
      end
      if tostring(bill.enactmentSeal or ""):upper()==seal then
        return {valid=true,kind="promulgation",seal=seal,parentId=bill.id,title=bill.title,status=bill.stage,issuedAt=bill.enactedAt,issuedBy=bill.enactedBy}
      end
    end

    for _,t in pairs(state.treaties or {}) do
      if tostring(t.signatureTextSeal or ""):upper()==seal then
        return {valid=true,kind="treaty_text",seal=seal,parentId=t.id,title=t.title,status=t.stage,issuedAt=t.signingOpenedAt,issuedBy=t.signingOpenedBy}
      end
      if tostring(t.activationSeal or ""):upper()==seal then
        return {valid=true,kind="treaty_activation",seal=seal,parentId=t.id,title=t.title,status=t.stage,issuedAt=t.effectiveAt,issuedBy=t.activatedBy}
      end
      if tostring(t.terminationSeal or ""):upper()==seal then
        return {valid=true,kind="treaty_termination",seal=seal,parentId=t.id,title=t.title,status=t.stage,issuedAt=t.terminatedAt,issuedBy=t.terminatedBy}
      end
      for stateId,sig in pairs(t.signatures or {}) do
        if tostring(sig.seal or ""):upper()==seal then
          return {valid=true,kind="treaty_signature",seal=seal,parentId=t.id,title=t.title,reference=stateId,status="signed",issuedAt=sig.at,issuedBy=sig.by,stateName=sig.stateName}
        end
      end
    end

    return {valid=false,seal=seal}
  end

  if action == "PING" then return { pong=true, time=common.now(), revision=state.meta.revision } end
  if action == "SERVER_INFO" then
    return { meta=state.meta, clientsCount=(function() local n=0 for _ in pairs(state.clients) do n=n+1 end return n end)() }
  end
  if action == "DASHBOARD" then
    local lc, cc, openCases, activeLaws, sc, votingBills, activeTreaties, signingTreaties, activeEnforcements = 0, 0, 0, 0, 0, 0, 0, 0, 0
    for _,law in pairs(state.laws) do lc=lc+1 if law.status=="active" then activeLaws=activeLaws+1 end end
    for _,c in pairs(state.cases) do
      if canViewCase(actor,c) then
        cc=cc+1
        if c.status~="closed" and c.status~="archived" then openCases=openCases+1 end
      end
    end
    for _,st in pairs(state.states or {}) do if st.status=="member" then sc=sc+1 end end
    for _,bill in pairs(state.bills or {}) do if bill.stage=="voting" then votingBills=votingBills+1 end end
    for _,t in pairs(state.treaties or {}) do
      if t.stage=="in_force" then activeTreaties=activeTreaties+1 end
      if t.stage=="signing" or t.stage=="ready" then signingTreaties=signingTreaties+1 end
    end
    for _,e in pairs(state.enforcements or {}) do
      if canViewEnforcement(actor,e) and (e.status=="ordered" or e.status=="active" or e.status=="partial" or e.status=="breached") then
        activeEnforcements=activeEnforcements+1
      end
    end
    return {
      laws=lc, activeLaws=activeLaws, cases=cc, openCases=openCases,
      states=sc, votingBills=votingBills, activeTreaties=activeTreaties, signingTreaties=signingTreaties,
      activeEnforcements=activeEnforcements, unreadNotices=countUnreadNotices(state,actor),
      stateId=actor.stateId,
      revision=state.meta.revision, codeStatus=state.meta.codeStatus
    }
  end
  if action == "STATE_LIST" then return listStates(state,p) end
  if action == "STATE_GET" then
    return common.deepcopy(state.states[common.trim(p.id):upper()])
  end

  if action == "STATE_CREATE" then
    local name=common.trim(p.name)
    if name=="" then return nil,"Nom d'Etat obligatoire." end
    for _,st in pairs(state.states) do
      if common.normalizeSearch(st.name)==common.normalizeSearch(name) then
        return nil,"Un Etat avec ce nom existe deja."
      end
    end
    local id=string.format("STATE-%03d",state.nextState or 1)
    state.nextState=(state.nextState or 1)+1
    local st={
      id=id,name=name,shortName=common.trim(p.shortName),
      status=p.status or "candidate",government=common.trim(p.government),
      representative=common.trim(p.representative),notes=common.trim(p.notes),
      createdAt=common.now(),updatedAt=common.now()
    }
    if st.shortName=="" then st.shortName=st.name end
    state.states[id]=st
    mutate(state,actor,"STATE_CREATE",id,st.name.." / "..st.status)
    return common.deepcopy(st)
  end

  if action == "STATE_UPDATE" then
    local id=common.trim(p.id):upper()
    local st=state.states[id]
    if not st then return nil,"Etat introuvable." end
    local allowed={candidate=true,member=true,suspended=true,withdrawn=true,excluded=true}
    if p.status and not allowed[p.status] then return nil,"Statut d'Etat invalide." end
    if p.name~=nil and common.trim(p.name)~="" then st.name=common.trim(p.name) end
    if p.shortName~=nil then st.shortName=common.trim(p.shortName) end
    if p.government~=nil then st.government=common.trim(p.government) end
    if p.representative~=nil then st.representative=common.trim(p.representative) end
    if p.notes~=nil then st.notes=common.trim(p.notes) end
    if p.status~=nil then st.status=p.status end
    st.updatedAt=common.now()
    mutate(state,actor,"STATE_UPDATE",id,st.name.." / "..st.status)
    return common.deepcopy(st)
  end

  if action == "CLIENT_LIST" then
    local out={}
    for _,client in pairs(state.clients or {}) do
      out[#out+1]={
        clientId=client.clientId,computerId=client.computerId,label=client.label,
        role=client.role,stateId=client.stateId,createdAt=client.createdAt,lastSeen=client.lastSeen
      }
    end
    table.sort(out,function(a,b) return tostring(a.label)<tostring(b.label) end)
    return out
  end

  if action == "CLIENT_SET_STATE" then
    local client=state.clients[common.trim(p.clientId)]
    if not client then return nil,"Terminal introuvable." end
    local stateId=common.trim(p.stateId):upper()
    if stateId~="" and not state.states[stateId] then return nil,"Etat introuvable." end
    client.stateId=stateId~="" and stateId or nil
    mutate(state,actor,"CLIENT_SET_STATE",client.clientId,client.stateId or "aucun")
    return common.deepcopy(client)
  end

  if action == "BILL_LIST" then return listBills(state,p) end
  if action == "BILL_GET" then
    local bill=state.bills[common.trim(p.id):upper()]
    if not bill then return nil,"Proposition introuvable." end
    local out=common.deepcopy(bill)
    out.tally=billTally(state,bill)
    return out
  end

  if action == "BILL_CREATE" then
    local title=common.trim(p.title)
    local validTypes={new_law=true,amendment=true,ratification_bundle=true}
    local proposalType=validTypes[p.proposalType] and p.proposalType or "new_law"
    if title=="" then return nil,"Titre obligatoire." end

    local targetRef=""
    local targetRefs={}
    if proposalType=="amendment" then
      targetRef=normalizeArticleRef(p.targetRef)
      if not state.laws[targetRef] then return nil,"Article cible introuvable." end
    elseif proposalType=="ratification_bundle" then
      local seen={}
      for _,raw in ipairs(type(p.targetRefs)=="table" and p.targetRefs or {}) do
        local ref=normalizeArticleRef(raw)
        if state.laws[ref] and not seen[ref] then
          seen[ref]=true
          targetRefs[#targetRefs+1]=ref
        end
      end
      table.sort(targetRefs,function(a,b)
        return (state.laws[a].number or 0)<(state.laws[b].number or 0)
      end)
      if #targetRefs==0 then return nil,"Selection d'articles a ratifier vide." end
    end

    local id=makeBillId(state)
    local threshold=p.threshold or "simple_cast"
    local validThreshold={simple_cast=true,absolute_members=true,two_thirds_cast=true,three_quarters_members=true}
    if not validThreshold[threshold] then threshold="simple_cast" end
    local bill={
      id=id,title=title,summary=common.trim(p.summary),proposalType=proposalType,
      targetRef=targetRef,targetRefs=targetRefs,
      proposedTitle=common.trim(p.proposedTitle),proposedBody=common.trim(p.proposedBody),
      proposedBook=common.trim(p.proposedBook),proposedSection=common.trim(p.proposedSection),
      stage="draft",threshold=threshold,votes={},voteHistory={},voteRounds={},
      eligibleStateIds={},votingRound=0,
      createdAt=common.now(),updatedAt=common.now(),createdBy=actor.label,
      result=nil,enactedRef=nil,enactedRefs={}
    }
    if proposalType~="ratification_bundle" and (bill.proposedTitle=="" or bill.proposedBody=="") then
      return nil,"Titre et texte proposes obligatoires."
    end
    state.bills[id]=bill
    mutate(state,actor,"BILL_CREATE",id,bill.title.." / "..proposalType)
    return common.deepcopy(bill)
  end

  if action == "BILL_EDIT" then
    local bill=state.bills[common.trim(p.id):upper()]
    if not bill then return nil,"Proposition introuvable." end
    if bill.stage~="draft" and bill.stage~="debate" then return nil,"La proposition n'est plus modifiable a ce stade." end

    local validatedRefs=nil
    if bill.proposalType=="ratification_bundle" and type(p.targetRefs)=="table" then
      local seen={}
      validatedRefs={}
      for _,raw in ipairs(p.targetRefs) do
        local ref=normalizeArticleRef(raw)
        if state.laws[ref] and not seen[ref] then
          seen[ref]=true
          validatedRefs[#validatedRefs+1]=ref
        end
      end
      table.sort(validatedRefs,function(a,b) return (state.laws[a].number or 0)<(state.laws[b].number or 0) end)
      if #validatedRefs==0 then return nil,"Le lot de ratification ne peut pas etre vide." end
    end

    if p.title~=nil and common.trim(p.title)~="" then bill.title=common.trim(p.title) end
    if p.summary~=nil then bill.summary=common.trim(p.summary) end
    if p.proposedTitle~=nil and common.trim(p.proposedTitle)~="" then bill.proposedTitle=common.trim(p.proposedTitle) end
    if p.proposedBody~=nil and common.trim(p.proposedBody)~="" then bill.proposedBody=common.trim(p.proposedBody) end
    if p.proposedBook~=nil then bill.proposedBook=common.trim(p.proposedBook) end
    if p.proposedSection~=nil then bill.proposedSection=common.trim(p.proposedSection) end
    if validatedRefs then bill.targetRefs=validatedRefs end
    if p.threshold~=nil then
      local valid={simple_cast=true,absolute_members=true,two_thirds_cast=true,three_quarters_members=true}
      if valid[p.threshold] then bill.threshold=p.threshold end
    end
    bill.updatedAt=common.now()
    mutate(state,actor,"BILL_EDIT",bill.id,bill.title)
    local out=common.deepcopy(bill); out.tally=billTally(state,bill); return out
  end

  if action == "BILL_SET_STAGE" then
    local bill=state.bills[common.trim(p.id):upper()]
    if not bill then return nil,"Proposition introuvable." end
    if p.stage~="draft" and p.stage~="debate" then return nil,"Etape legislative invalide." end
    if bill.stage~="draft" and bill.stage~="debate" then return nil,"Cette proposition ne peut plus revenir en phase de redaction/debat." end
    if bill.stage==p.stage then
      local out=common.deepcopy(bill);out.tally=billTally(state,bill);return out
    end
    local previous=bill.stage
    bill.stage=p.stage
    bill.updatedAt=common.now()
    mutate(state,actor,"BILL_SET_STAGE",bill.id,previous.." -> "..bill.stage)
    local out=common.deepcopy(bill);out.tally=billTally(state,bill);return out
  end

  if action == "BILL_OPEN_VOTE" then
    local bill=state.bills[common.trim(p.id):upper()]
    if not bill then return nil,"Proposition introuvable." end
    if bill.stage=="adopted" or bill.stage=="rejected" or bill.stage=="enacted" or bill.stage=="withdrawn" then
      return nil,"Cette proposition est deja terminee."
    end
    bill.voteRounds=bill.voteRounds or {}
    if bill.votingRound and bill.votingRound>0 then
      bill.voteRounds[#bill.voteRounds+1]={
        round=bill.votingRound,
        openedAt=bill.votingOpenedAt,
        closedAt=bill.closedAt,
        result=bill.result,
        votes=common.deepcopy(bill.votes or {}),
        tally=billTally(state,bill)
      }
    end
    bill.votingRound=(bill.votingRound or 0)+1
    bill.votes={}
    bill.eligibleStateIds={}
    for id,st in pairs(state.states or {}) do
      if st.status=="member" then bill.eligibleStateIds[#bill.eligibleStateIds+1]=id end
    end
    table.sort(bill.eligibleStateIds)
    bill.stage="voting"
    bill.result=nil
    bill.closedAt=nil
    bill.votingOpenedAt=common.now()
    bill.updatedAt=common.now()
    for _,stateId in ipairs(bill.eligibleStateIds) do
      pushNotice(state,{
        title="Vote ouvert: "..bill.id,
        body=bill.title.." / tour "..tostring(bill.votingRound).." / votre Etat doit voter.",
        severity="action",objectType="bill",objectId=bill.id,targetStateId=stateId
      })
    end
    mutate(state,actor,"BILL_OPEN_VOTE",bill.id,bill.title.." / round "..bill.votingRound.." / electorate "..#bill.eligibleStateIds)
    local out=common.deepcopy(bill); out.tally=billTally(state,bill); return out
  end

  if action == "BILL_VOTE" then
    local bill=state.bills[common.trim(p.id):upper()]
    if not bill then return nil,"Proposition introuvable." end
    if bill.stage~="voting" then return nil,"Le vote n'est pas ouvert." end
    local st=getClientState(state,actor)
    if not st then return nil,"Ce terminal delegue n'est rattache a aucun Etat." end
    local eligible=false
    for _,id in ipairs(bill.eligibleStateIds or {}) do if id==st.id then eligible=true break end end
    if not eligible then return nil,"Cet Etat ne faisait pas partie du corps electoral a l'ouverture de ce vote." end
    local choice=common.lower(p.choice)
    if choice~="yes" and choice~="no" and choice~="abstain" then return nil,"Vote invalide." end
    bill.votes=bill.votes or {}
    bill.voteHistory=bill.voteHistory or {}
    local previous=bill.votes[st.id]
    bill.votes[st.id]={choice=choice,at=common.now(),by=actor.label,stateName=st.name}
    bill.voteHistory[#bill.voteHistory+1]={
      at=common.now(),stateId=st.id,stateName=st.name,choice=choice,
      previous=previous and previous.choice or nil,by=actor.label
    }
    bill.updatedAt=common.now()
    mutate(state,actor,"BILL_VOTE",bill.id,st.id.."="..choice)
    local out=common.deepcopy(bill); out.tally=billTally(state,bill); return out
  end

  if action == "BILL_CLOSE" then
    local bill=state.bills[common.trim(p.id):upper()]
    if not bill then return nil,"Proposition introuvable." end
    if bill.stage~="voting" then return nil,"Le vote n'est pas ouvert." end
    local tally=billTally(state,bill)
    if not tally.quorumMet then
      bill.result="no_quorum"
      bill.stage="no_quorum"
    else
      bill.result=tally.adopted and "adopted" or "rejected"
      bill.stage=bill.result
    end
    bill.closedAt=common.now()
    bill.closedBy=actor.label
    bill.resultSeal=officialSeal("UNS-VOTE",{bill.id,bill.votingRound,bill.result,tally,bill.eligibleStateIds,bill.votes,bill.closedAt})
    bill.updatedAt=common.now()
    for _,stateId in ipairs(bill.eligibleStateIds or {}) do
      pushNotice(state,{
        title="Resultat du scrutin: "..bill.id,
        body=bill.title.." / "..string.upper(tostring(bill.result)).." / POUR "..tally.yes.." CONTRE "..tally.no.." ABST "..tally.abstain,
        severity=bill.result=="adopted" and "success" or "info",
        objectType="bill",objectId=bill.id,targetStateId=stateId
      })
    end
    mutate(state,actor,"BILL_CLOSE",bill.id,bill.result.." / yes="..tally.yes.." no="..tally.no.." abst="..tally.abstain)
    local out=common.deepcopy(bill); out.tally=tally; return out
  end

  if action == "BILL_ENACT" then
    local bill=state.bills[common.trim(p.id):upper()]
    if not bill then return nil,"Proposition introuvable." end
    if bill.stage~="adopted" then return nil,"La proposition doit etre adoptee avant promulgation." end

    local enactedRef=nil
    local enactedRefs={}

    if bill.proposalType=="new_law" then
      local n=state.nextArticle
      state.nextArticle=n+1
      enactedRef=string.format("UNS-ART-%03d",n)
      state.laws[enactedRef]={
        number=n,ref=enactedRef,title=bill.proposedTitle,body=bill.proposedBody,
        book=bill.proposedBook,section=bill.proposedSection,status="active",
        version=1,createdAt=common.now(),updatedAt=common.now(),history={},
        lastChangedBy=actor.label,lastChangeReason="Promulgue depuis "..bill.id
      }
      enactedRefs[1]=enactedRef

    elseif bill.proposalType=="amendment" then
      enactedRef=bill.targetRef
      local law=state.laws[enactedRef]
      if not law then return nil,"Article cible introuvable au moment de la promulgation." end
      law.history=law.history or {}
      law.history[#law.history+1]={
        version=law.version,title=law.title,body=law.body,book=law.book,section=law.section,status=law.status,
        archivedAt=common.now(),archivedBy=actor.label,supersededByReason="Adoption de "..bill.id
      }
      law.version=(law.version or 1)+1
      law.title=bill.proposedTitle
      law.body=bill.proposedBody
      if bill.proposedBook~="" then law.book=bill.proposedBook end
      law.section=bill.proposedSection
      law.status="active"
      law.updatedAt=common.now()
      law.lastChangedBy=actor.label
      law.lastChangeReason="Promulgue depuis "..bill.id
      enactedRefs[1]=enactedRef

    elseif bill.proposalType=="ratification_bundle" then
      for _,ref in ipairs(bill.targetRefs or {}) do
        local law=state.laws[ref]
        if law then
          law.history=law.history or {}
          law.history[#law.history+1]={
            version=law.version,title=law.title,body=law.body,book=law.book,section=law.section,status=law.status,
            archivedAt=common.now(),archivedBy=actor.label,supersededByReason="Ratification par "..bill.id
          }
          law.version=(law.version or 1)+1
          law.status="active"
          law.updatedAt=common.now()
          law.lastChangedBy=actor.label
          law.lastChangeReason="Ratification par "..bill.id
          enactedRefs[#enactedRefs+1]=ref
        end
      end
      if #enactedRefs==0 then return nil,"Aucun article du lot n'existe encore." end
      enactedRef=enactedRefs[1]

    else
      return nil,"Type de proposition inconnu."
    end

    bill.stage="enacted"
    bill.enactedRef=enactedRef
    bill.enactedRefs=enactedRefs
    bill.enactedAt=common.now()
    bill.enactedBy=actor.label
    bill.enactmentSeal=officialSeal("UNS-PROM",{bill.id,enactedRefs,bill.enactedAt,bill.enactedBy,bill.resultSeal})
    bill.updatedAt=common.now()
    pushNotice(state,{
      title="Promulgation: "..bill.id,
      body=bill.title.." / "..table.concat(enactedRefs,", "),
      severity="success",objectType="bill",objectId=bill.id,global=true
    })
    mutate(state,actor,"BILL_ENACT",bill.id,table.concat(enactedRefs,","))
    local out=common.deepcopy(bill); out.tally=billTally(state,bill); return out
  end

  if action == "TREATY_LIST" then return listTreaties(state,p) end

  if action == "TREATY_GET" then
    local treaty=state.treaties[common.trim(p.id):upper()]
    if not treaty then return nil,"Traite introuvable." end
    local out=common.deepcopy(treaty)
    out.signatureStatus=treatySignatureStatus(state,treaty)
    return out
  end

  if action == "TREATY_CREATE" then
    local title=common.trim(p.title)
    local body=common.trim(p.body)
    if title=="" or body=="" then return nil,"Titre et texte du traite obligatoires." end

    local allowedTypes={bilateral=true,multilateral=true,defense=true,trade=true,border=true,ceasefire=true,non_aggression=true,other=true}
    local treatyType=allowedTypes[p.treatyType] and p.treatyType or "other"

    local parties={}
    local seen={}
    for _,raw in ipairs(type(p.parties)=="table" and p.parties or {}) do
      local id=common.trim(raw):upper()
      if state.states[id] and not seen[id] then
        seen[id]=true
        parties[#parties+1]=id
      end
    end
    table.sort(parties)
    if #parties<2 then return nil,"Un traite doit comporter au moins deux Etats parties." end

    local id=makeTreatyId(state)
    local treaty={
      id=id,title=title,treatyType=treatyType,summary=common.trim(p.summary),body=body,
      parties=parties,stage="draft",version=1,history={},
      signatures={},signatureHistory={},
      createdAt=common.now(),updatedAt=common.now(),createdBy=actor.label
    }
    state.treaties[id]=treaty
    mutate(state,actor,"TREATY_CREATE",id,title.." / "..treatyType)
    local out=common.deepcopy(treaty);out.signatureStatus=treatySignatureStatus(state,treaty);return out
  end

  if action == "TREATY_EDIT" then
    local treaty=state.treaties[common.trim(p.id):upper()]
    if not treaty then return nil,"Traite introuvable." end
    if treaty.stage~="draft" then return nil,"Le traite est fige des l'ouverture des signatures." end

    local validatedParties=nil
    if type(p.parties)=="table" then
      local seen={}
      validatedParties={}
      for _,raw in ipairs(p.parties) do
        local id=common.trim(raw):upper()
        if state.states[id] and not seen[id] then
          seen[id]=true
          validatedParties[#validatedParties+1]=id
        end
      end
      table.sort(validatedParties)
      if #validatedParties<2 then return nil,"Un traite doit comporter au moins deux Etats parties." end
    end

    local allowedTypes={bilateral=true,multilateral=true,defense=true,trade=true,border=true,ceasefire=true,non_aggression=true,other=true}
    local validatedType=treaty.treatyType
    if p.treatyType~=nil then
      if not allowedTypes[p.treatyType] then return nil,"Type de traite invalide." end
      validatedType=p.treatyType
    end

    treaty.history=treaty.history or {}
    treaty.history[#treaty.history+1]={
      version=treaty.version,title=treaty.title,treatyType=treaty.treatyType,
      summary=treaty.summary,body=treaty.body,parties=common.deepcopy(treaty.parties),
      archivedAt=common.now(),archivedBy=actor.label
    }

    if p.title~=nil and common.trim(p.title)~="" then treaty.title=common.trim(p.title) end
    if p.summary~=nil then treaty.summary=common.trim(p.summary) end
    if p.body~=nil and common.trim(p.body)~="" then treaty.body=common.trim(p.body) end
    treaty.treatyType=validatedType
    if validatedParties then treaty.parties=validatedParties end

    treaty.version=(treaty.version or 1)+1
    treaty.signatures={}
    treaty.updatedAt=common.now()
    mutate(state,actor,"TREATY_EDIT",treaty.id,"Version "..treaty.version)
    local out=common.deepcopy(treaty);out.signatureStatus=treatySignatureStatus(state,treaty);return out
  end

  if action == "TREATY_OPEN_SIGNATURE" then
    local treaty=state.treaties[common.trim(p.id):upper()]
    if not treaty then return nil,"Traite introuvable." end
    if treaty.stage~="draft" then return nil,"Le traite n'est plus au stade brouillon." end
    treaty.stage="signing"
    treaty.signatureTextSeal=officialSeal("UNS-TXT",{treaty.id,treaty.version,treaty.title,treaty.treatyType,treaty.parties,treaty.body})
    treaty.signingOpenedAt=common.now()
    treaty.signingOpenedBy=actor.label
    treaty.updatedAt=common.now()
    for _,stateId in ipairs(treaty.parties or {}) do
      pushNotice(state,{
        title="Signature requise: "..treaty.id,
        body=treaty.title.." / texte fige v"..tostring(treaty.version)..".",
        severity="action",objectType="treaty",objectId=treaty.id,targetStateId=stateId
      })
    end
    mutate(state,actor,"TREATY_OPEN_SIGNATURE",treaty.id,treaty.signatureTextSeal)
    local out=common.deepcopy(treaty);out.signatureStatus=treatySignatureStatus(state,treaty);return out
  end

  if action == "TREATY_SIGN" then
    local treaty=state.treaties[common.trim(p.id):upper()]
    if not treaty then return nil,"Traite introuvable." end
    if treaty.stage~="signing" then return nil,"Les signatures ne sont pas ouvertes." end
    local st=getClientState(state,actor)
    if not st then return nil,"Ce terminal delegue n'est rattache a aucun Etat." end

    local isParty=false
    for _,id in ipairs(treaty.parties or {}) do if id==st.id then isParty=true break end end
    if not isParty then return nil,"Votre Etat n'est pas partie a ce traite." end
    if treaty.signatures[st.id] then
      local out=common.deepcopy(treaty);out.signatureStatus=treatySignatureStatus(state,treaty);return out
    end

    local signature={
      stateId=st.id,stateName=st.name,at=common.now(),by=actor.label,
      seal=officialSeal("UNS-SIGN",{treaty.id,treaty.version,treaty.signatureTextSeal,st.id,st.name,actor.label,common.now()})
    }
    treaty.signatures[st.id]=signature
    treaty.signatureHistory=treaty.signatureHistory or {}
    treaty.signatureHistory[#treaty.signatureHistory+1]=common.deepcopy(signature)
    treaty.updatedAt=common.now()

    local sigStatus=treatySignatureStatus(state,treaty)
    if sigStatus.complete then
      treaty.stage="ready"
      treaty.readyAt=common.now()
      pushNotice(state,{
        title="Traite pret a entrer en vigueur",
        body=treaty.id.." / "..treaty.title.." / toutes les signatures sont reunies.",
        severity="success",objectType="treaty",objectId=treaty.id,
        roles={writer=true,admin=true}
      })
    end
    mutate(state,actor,"TREATY_SIGN",treaty.id,st.id)
    local out=common.deepcopy(treaty);out.signatureStatus=sigStatus;return out
  end

  if action == "TREATY_ACTIVATE" then
    local treaty=state.treaties[common.trim(p.id):upper()]
    if not treaty then return nil,"Traite introuvable." end
    local sigStatus=treatySignatureStatus(state,treaty)
    if treaty.stage~="ready" or not sigStatus.complete then return nil,"Toutes les parties doivent signer avant l'entree en vigueur." end
    treaty.stage="in_force"
    treaty.effectiveAt=common.now()
    treaty.activatedBy=actor.label
    treaty.activationSeal=officialSeal("UNS-TRT",{treaty.id,treaty.version,treaty.signatureTextSeal,treaty.signatures,treaty.effectiveAt})
    treaty.updatedAt=common.now()
    pushNotice(state,{
      title="Traite entre en vigueur",
      body=treaty.id.." / "..treaty.title,
      severity="success",objectType="treaty",objectId=treaty.id,global=true
    })
    mutate(state,actor,"TREATY_ACTIVATE",treaty.id,treaty.activationSeal)
    local out=common.deepcopy(treaty);out.signatureStatus=sigStatus;return out
  end

  if action == "TREATY_TERMINATE" then
    local treaty=state.treaties[common.trim(p.id):upper()]
    if not treaty then return nil,"Traite introuvable." end
    if treaty.stage~="in_force" then return nil,"Seul un traite en vigueur peut etre termine." end
    local reason=common.trim(p.reason)
    if reason=="" then return nil,"Motif de fin du traite obligatoire." end
    treaty.stage="terminated"
    treaty.terminatedAt=common.now()
    treaty.terminatedBy=actor.label
    treaty.terminationReason=reason
    treaty.terminationSeal=officialSeal("UNS-END",{treaty.id,treaty.activationSeal,treaty.terminatedAt,reason})
    treaty.updatedAt=common.now()
    mutate(state,actor,"TREATY_TERMINATE",treaty.id,reason)
    local out=common.deepcopy(treaty);out.signatureStatus=treatySignatureStatus(state,treaty);return out
  end

  if action == "LAW_BOOKS" then return listBooks(state) end
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
    local changeReason=common.trim(p.reason)
    law.history[#law.history+1] = {
      version=law.version, title=law.title, body=law.body, book=law.book,
      section=law.section, status=law.status, archivedAt=common.now(), archivedBy=actor.label,
      supersededByReason=changeReason
    }
    law.version = (law.version or 1) + 1
    if common.trim(p.title) ~= "" then law.title = common.trim(p.title) end
    if common.trim(p.body) ~= "" then law.body = common.trim(p.body) end
    if p.book ~= nil then law.book = common.trim(p.book) end
    if p.section ~= nil then law.section = common.trim(p.section) end
    law.updatedAt = common.now()
    law.lastChangedBy=actor.label
    law.lastChangeReason=changeReason
    mutate(state, actor, "LAW_AMEND", ref, "Version " .. law.version .. (changeReason~="" and (" - "..changeReason) or ""))
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
    if law.status==p.status then return common.deepcopy(law) end
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

  if action == "CASE_LIST" then return listCases(state, p, actor) end
  if action == "CASE_GET" then
    local c=state.cases[common.trim(p.id):upper()]
    if c then ensureCaseShape(c) end
    if c and not canViewCase(actor,c) then return nil,"Dossier non public ou acces refuse." end
    return common.deepcopy(c)
  end

  if action == "CASE_CREATE" then
    local id = makeCaseId(state)
    local c = {
      id=id, title=common.trim(p.title), complainant=common.trim(p.complainant), accused=common.trim(p.accused),
      summary=common.trim(p.summary), status="open", visibility=p.visibility=="public" and "public" or "restricted", facts={}, evidence={}, citedArticles={}, judgments={}, timeline={},
      createdAt=common.now(), updatedAt=common.now(), createdBy=actor.label
    }
    if c.title == "" then return nil, "Titre obligatoire." end
    caseEvent(c,actor,"CASE_CREATED","Dossier ouvert",c.title)
    state.cases[id] = c
    mutate(state, actor, "CASE_CREATE", id, c.title)
    return common.deepcopy(c)
  end

  if action == "CASE_UPDATE_SUMMARY" then
    local c = state.cases[common.trim(p.id):upper()]
    if not c then return nil, "Dossier introuvable." end
    ensureCaseShape(c)
    c.summary = common.trim(p.summary)
    c.updatedAt = common.now()
    caseEvent(c,actor,"SUMMARY_UPDATED","Contexte mis a jour","")
    mutate(state, actor, "CASE_UPDATE_SUMMARY", c.id, "Contexte modifie")
    return common.deepcopy(c)
  end

  if action == "CASE_ADD_FACT" then
    local c = state.cases[common.trim(p.id):upper()]
    if not c then return nil, "Dossier introuvable." end
    ensureCaseShape(c)
    local fact = { id=#c.facts+1, text=common.trim(p.text), at=common.now(), by=actor.label }
    if fact.text == "" then return nil, "Fait vide." end
    c.facts[#c.facts+1] = fact
    c.updatedAt=common.now()
    caseEvent(c,actor,"FACT_ADDED","Fait #"..fact.id,fact.text:sub(1,120))
    mutate(state, actor, "CASE_ADD_FACT", c.id, fact.text:sub(1,80))
    return common.deepcopy(c)
  end

  if action == "CASE_ADD_EVIDENCE" then
    local c = state.cases[common.trim(p.id):upper()]
    if not c then return nil, "Dossier introuvable." end
    ensureCaseShape(c)
    local e = {
      id=#c.evidence+1, label=common.trim(p.label), description=common.trim(p.description),
      source=common.trim(p.source), at=common.now(), by=actor.label
    }
    if e.label == "" then e.label = "Preuve " .. e.id end
    c.evidence[#c.evidence+1] = e
    c.updatedAt=common.now()
    caseEvent(c,actor,"EVIDENCE_ADDED","Preuve #"..e.id.." - "..e.label,e.source)
    mutate(state, actor, "CASE_ADD_EVIDENCE", c.id, e.label)
    return common.deepcopy(c)
  end

  if action == "CASE_ADD_ARTICLE" then
    local c = state.cases[common.trim(p.id):upper()]
    if not c then return nil, "Dossier introuvable." end
    ensureCaseShape(c)
    local ref = normalizeArticleRef(p.ref)
    if not state.laws[ref] then return nil, "Article introuvable." end
    for _, x in ipairs(c.citedArticles) do
      if x == ref then return common.deepcopy(c) end
    end
    c.citedArticles[#c.citedArticles+1] = ref
    c.updatedAt=common.now()
    caseEvent(c,actor,"ARTICLE_CITED","Article cite",ref)
    mutate(state, actor, "CASE_ADD_ARTICLE", c.id, ref)
    return common.deepcopy(c)
  end

  if action == "CASE_ADD_ARTICLES" then
    local c = state.cases[common.trim(p.id):upper()]
    if not c then return nil, "Dossier introuvable." end
    ensureCaseShape(c)
    local refs = type(p.refs)=="table" and p.refs or {}
    local added = {}
    local existing = {}
    for _,x in ipairs(c.citedArticles) do existing[x]=true end
    for _,raw in ipairs(refs) do
      local ref=normalizeArticleRef(raw)
      if state.laws[ref] and not existing[ref] then
        c.citedArticles[#c.citedArticles+1]=ref
        existing[ref]=true
        added[#added+1]=ref
      end
    end
    if #added==0 then return common.deepcopy(c) end
    c.updatedAt=common.now()
    caseEvent(c,actor,"ARTICLES_CITED","Selection d'articles ajoutee",table.concat(added,", "))
    mutate(state,actor,"CASE_ADD_ARTICLES",c.id,table.concat(added,", "))
    return common.deepcopy(c)
  end

  if action == "CASE_REMOVE_ARTICLE" then
    local c = state.cases[common.trim(p.id):upper()]
    if not c then return nil, "Dossier introuvable." end
    ensureCaseShape(c)
    local ref = normalizeArticleRef(p.ref)
    local removed=false
    for i=#c.citedArticles,1,-1 do
      if c.citedArticles[i] == ref then table.remove(c.citedArticles,i) removed=true end
    end
    if not removed then return common.deepcopy(c) end
    c.updatedAt=common.now()
    caseEvent(c,actor,"ARTICLE_REMOVED","Article retire",ref)
    mutate(state, actor, "CASE_REMOVE_ARTICLE", c.id, ref)
    return common.deepcopy(c)
  end

  if action == "CASE_ADD_JUDGMENT" then
    local c = state.cases[common.trim(p.id):upper()]
    if not c then return nil, "Dossier introuvable." end
    ensureCaseShape(c)
    local snapshot={}
    for _,ref in ipairs(c.citedArticles) do
      local law=state.laws[ref]
      snapshot[#snapshot+1]={
        ref=ref,
        title=law and law.title or "",
        version=law and law.version or nil,
        status=law and law.status or nil
      }
    end
    local j = {
      id=#c.judgments+1, date=common.now(), judge=actor.label,
      verdict=common.trim(p.verdict), reasoning=common.trim(p.reasoning),
      sanctions=common.trim(p.sanctions), citedArticles=common.deepcopy(c.citedArticles),
      articleSnapshot=snapshot,
      final=p.final == true
    }
    j.seal=officialSeal("CIU-JUG",{c.id,j.id,j.date,j.judge,j.verdict,j.reasoning,j.sanctions,j.articleSnapshot,j.final})
    if j.verdict == "" or j.reasoning == "" then return nil, "Decision et motifs obligatoires." end
    c.judgments[#c.judgments+1] = j
    if j.final then c.status = "judged" end
    c.updatedAt=common.now()
    caseEvent(c,actor,"JUDGMENT_ADDED","Jugement #"..j.id,(j.final and "FINAL - " or "")..j.verdict:sub(1,120))
    mutate(state, actor, "CASE_ADD_JUDGMENT", c.id, j.verdict:sub(1,80))
    return common.deepcopy(c)
  end

  if action == "CASE_SET_STATUS" then
    local c = state.cases[common.trim(p.id):upper()]
    if not c then return nil, "Dossier introuvable." end
    local allowed={open=true,investigation=true,hearing=true,judged=true,appeal=true,closed=true,archived=true}
    if not allowed[p.status] then return nil, "Statut invalide." end
    ensureCaseShape(c)
    if c.status==p.status then return common.deepcopy(c) end
    local previous=c.status
    c.status=p.status
    c.updatedAt=common.now()
    caseEvent(c,actor,"STATUS_CHANGED","Statut: "..tostring(previous).." -> "..tostring(p.status),"")
    mutate(state, actor, "CASE_SET_STATUS", c.id, p.status)
    return common.deepcopy(c)
  end

  if action == "CASE_SET_VISIBILITY" then
    local c=state.cases[common.trim(p.id):upper()]
    if not c then return nil,"Dossier introuvable." end
    ensureCaseShape(c)
    local allowed={public=true,restricted=true,sealed=true}
    if not allowed[p.visibility] then return nil,"Visibilite invalide." end
    if c.visibility==p.visibility then return common.deepcopy(c) end
    local previous=c.visibility
    c.visibility=p.visibility
    c.updatedAt=common.now()
    caseEvent(c,actor,"VISIBILITY_CHANGED","Visibilite: "..tostring(previous).." -> "..tostring(p.visibility),"")
    mutate(state,actor,"CASE_SET_VISIBILITY",c.id,p.visibility)
    return common.deepcopy(c)
  end

  if action == "CASE_ADD_HEARING" then
    local c=state.cases[common.trim(p.id):upper()]
    if not c then return nil,"Dossier introuvable." end
    ensureCaseShape(c)
    local subject=common.trim(p.subject)
    if subject=="" then return nil,"Objet de l'audience obligatoire." end
    local hearing={
      id=string.format("H-%03d",#c.hearings+1),
      subject=subject,scheduledFor=common.trim(p.scheduledFor),
      location=common.trim(p.location),notes=common.trim(p.notes),
      status="scheduled",createdAt=common.now(),createdBy=actor.label
    }
    hearing.seal=officialSeal("CIU-AUD",{c.id,hearing.id,hearing.subject,hearing.scheduledFor,hearing.location,hearing.createdAt})
    c.hearings[#c.hearings+1]=hearing
    c.updatedAt=common.now()
    caseEvent(c,actor,"HEARING_CREATED","Audience "..hearing.id,hearing.subject.." / "..hearing.scheduledFor)
    pushNotice(state,{
      title="Audience programmee: "..c.id,
      body=hearing.scheduledFor.." / "..hearing.subject.." / "..hearing.location,
      severity="action",objectType="case",objectId=c.id,
      roles={clerk=true,judge=true,admin=true}
    })
    mutate(state,actor,"CASE_ADD_HEARING",c.id,hearing.id.." "..hearing.subject)
    return common.deepcopy(c)
  end

  if action == "CASE_SET_HEARING_STATUS" then
    local c=state.cases[common.trim(p.id):upper()]
    if not c then return nil,"Dossier introuvable." end
    ensureCaseShape(c)
    local allowed={scheduled=true,held=true,cancelled=true,postponed=true}
    if not allowed[p.status] then return nil,"Statut d'audience invalide." end
    local target=nil
    for _,h in ipairs(c.hearings) do if h.id==p.hearingId then target=h break end end
    if not target then return nil,"Audience introuvable." end
    if target.status==p.status then return common.deepcopy(c) end
    target.status=p.status
    target.updatedAt=common.now()
    target.updatedBy=actor.label
    caseEvent(c,actor,"HEARING_STATUS","Audience "..target.id.." -> "..p.status,target.subject)
    c.updatedAt=common.now()
    mutate(state,actor,"CASE_SET_HEARING_STATUS",c.id,target.id.."="..p.status)
    return common.deepcopy(c)
  end

  if action == "CASE_ADD_ORDER" then
    local c=state.cases[common.trim(p.id):upper()]
    if not c then return nil,"Dossier introuvable." end
    ensureCaseShape(c)
    local orderType=common.trim(p.orderType)
    local subject=common.trim(p.subject)
    local body=common.trim(p.body)
    if subject=="" or body=="" then return nil,"Objet et contenu de l'ordonnance obligatoires." end
    if orderType=="" then orderType="order" end
    local order={
      id=string.format("O-%03d",#c.orders+1),
      orderType=orderType,subject=subject,body=body,status="active",
      expiresAt=common.trim(p.expiresAt),createdAt=common.now(),createdBy=actor.label
    }
    order.seal=officialSeal("CIU-ORD",{c.id,order.id,order.orderType,order.subject,order.body,order.createdBy,order.createdAt,order.expiresAt})
    c.orders[#c.orders+1]=order
    c.updatedAt=common.now()
    caseEvent(c,actor,"ORDER_CREATED","Ordonnance "..order.id.." / "..orderType,subject)
    mutate(state,actor,"CASE_ADD_ORDER",c.id,order.id.." "..subject)
    return common.deepcopy(c)
  end

  if action == "CASE_SET_ORDER_STATUS" then
    local c=state.cases[common.trim(p.id):upper()]
    if not c then return nil,"Dossier introuvable." end
    ensureCaseShape(c)
    local allowed={active=true,executed=true,revoked=true,expired=true}
    if not allowed[p.status] then return nil,"Statut d'ordonnance invalide." end
    local target=nil
    for _,o in ipairs(c.orders) do if o.id==p.orderId then target=o break end end
    if not target then return nil,"Ordonnance introuvable." end
    if target.status==p.status then return common.deepcopy(c) end
    target.status=p.status
    target.updatedAt=common.now()
    target.updatedBy=actor.label
    c.updatedAt=common.now()
    caseEvent(c,actor,"ORDER_STATUS","Ordonnance "..target.id.." -> "..p.status,target.subject)
    mutate(state,actor,"CASE_SET_ORDER_STATUS",c.id,target.id.."="..p.status)
    return common.deepcopy(c)
  end

  if action == "CASE_FILE_APPEAL" then
    local c=state.cases[common.trim(p.id):upper()]
    if not c then return nil,"Dossier introuvable." end
    ensureCaseShape(c)
    local grounds=common.trim(p.grounds)
    local request=common.trim(p.request)
    if grounds=="" then return nil,"Motifs d'appel obligatoires." end
    local appeal={
      id=string.format("A-%03d",#c.appeals+1),
      appellant=common.trim(p.appellant),grounds=grounds,request=request,
      status="pending",filedAt=common.now(),filedBy=actor.label
    }
    appeal.seal=officialSeal("CIU-APP",{c.id,appeal.id,appeal.appellant,appeal.grounds,appeal.request,appeal.filedAt,appeal.filedBy})
    c.appeals[#c.appeals+1]=appeal
    c.status="appeal"
    c.updatedAt=common.now()
    caseEvent(c,actor,"APPEAL_FILED","Appel "..appeal.id,appeal.appellant.." / "..appeal.request)
    pushNotice(state,{
      title="Nouvel appel: "..c.id.." / "..appeal.id,
      body=appeal.appellant.." / "..appeal.request,
      severity="action",objectType="case",objectId=c.id,
      roles={judge=true,admin=true}
    })
    mutate(state,actor,"CASE_FILE_APPEAL",c.id,appeal.id)
    return common.deepcopy(c)
  end

  if action == "CASE_DECIDE_APPEAL" then
    local c=state.cases[common.trim(p.id):upper()]
    if not c then return nil,"Dossier introuvable." end
    ensureCaseShape(c)
    local target=nil
    for _,a in ipairs(c.appeals) do if a.id==p.appealId then target=a break end end
    if not target then return nil,"Appel introuvable." end
    if target.status~="pending" then return nil,"Cet appel a deja ete tranche." end
    local valid={upheld=true,modified=true,overturned=true,remanded=true,rejected=true}
    if not valid[p.result] then return nil,"Resultat d'appel invalide." end
    local reasoning=common.trim(p.reasoning)
    if reasoning=="" then return nil,"Motivation de l'appel obligatoire." end
    target.status="decided"
    target.result=p.result
    target.reasoning=reasoning
    target.decidedAt=common.now()
    target.decidedBy=actor.label
    target.decisionSeal=officialSeal("CIU-APPDEC",{c.id,target.id,target.result,target.reasoning,target.decidedAt,target.decidedBy,target.seal})
    c.updatedAt=common.now()
    if p.result=="remanded" then c.status="hearing" else c.status="judged" end
    caseEvent(c,actor,"APPEAL_DECIDED","Appel "..target.id.." -> "..target.result,target.reasoning:sub(1,120))
    mutate(state,actor,"CASE_DECIDE_APPEAL",c.id,target.id.."="..target.result)
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

  local lc,cc,cl,sc,bv,tr,enf=0,0,0,0,0,0,0
  for _ in pairs(state.laws) do lc=lc+1 end
  for _ in pairs(state.cases) do cc=cc+1 end
  for _ in pairs(state.clients) do cl=cl+1 end
  for _,st in pairs(state.states or {}) do if st.status=="member" then sc=sc+1 end end
  for _,bill in pairs(state.bills or {}) do if bill.stage=="voting" then bv=bv+1 end end
  for _,t in pairs(state.treaties or {}) do if t.stage=="in_force" then tr=tr+1 end end
  for _,e in pairs(state.enforcements or {}) do
    if e.status=="ordered" or e.status=="active" or e.status=="partial" or e.status=="breached" then enf=enf+1 end
  end

  term.setCursorPos(2,5)
  term.write("Articles: "..lc.." Dossiers: "..cc.." Clients: "..cl)
  term.setCursorPos(2,6)
  term.write("Etats: "..sc.." Votes: "..bv.." Traites: "..tr)
  term.setCursorPos(2,7)
  term.write("Execution: "..enf.." Notifications: "..tostring(#(state.notices or {})))
  term.setTextColor(colors.cyan)
  term.setCursorPos(2,9)
  term.write("[P] Appairer un terminal   [B] Backup   [Q] Arreter")

  if state.pairing then
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.setCursorPos(2,11)
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
  local roles={"writer","clerk","judge","delegate","viewer","admin"}
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
  term.setCursorPos(2,11)
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
