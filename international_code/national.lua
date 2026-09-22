local common = dofile("/international_code/common.lua")

local N = {}
local CORPUS_PATH = "/international_code/national/corpus_v2.json"
local NORTH_STATE_ID = "STATE-001"

local function loadCorpus()
  local raw = common.readAll(CORPUS_PATH)
  if not raw or raw=="" then return nil,"Corpus national absent: "..CORPUS_PATH end
  local ok,data = pcall(textutils.unserializeJSON, raw)
  if not ok or type(data)~="table" then return nil,"Corpus national JSON invalide." end
  if type(data.articles)~="table" or #data.articles<1 then return nil,"Corpus national vide." end
  return data
end

local function seal(prefix,payload)
  local raw=textutils.serialize(payload,{compact=true}).."|"..tostring(common.nowMs()).."|"..common.randomToken(8)
  return prefix.."-"..common.simpleChecksum(raw):upper()
end

local function yearNow()
  return os.date and os.date("%Y") or "0000"
end

local function copy(v)
  return common.deepcopy(v)
end

local function identity(actor)
  return common.trim(actor and (actor.nationalIdentity or actor.label or actor.clientId) or "")
end

local function nationalRole(state,actor)
  if not actor then return nil end
  if actor.role=="admin" then return actor.nationalRole or "admin" end
  if actor.nationalRole and actor.nationalRole~="" then return actor.nationalRole end
  local n=state.national
  if n and actor.stateId and actor.stateId==(n.meta.stateId or NORTH_STATE_ID) then return "citizen" end
  return nil
end

local function hasAccess(state,actor)
  return nationalRole(state,actor)~=nil
end

local function roleIs(state,actor,...)
  local r=nationalRole(state,actor)
  for i=1,select("#",...) do if r==select(i,...) then return true end end
  return false
end

local function isPresident(state,actor)
  return actor and (actor.role=="admin" or nationalRole(state,actor)=="president")
end

local function isCouncil(state,actor)
  return actor and (actor.role=="admin" or nationalRole(state,actor)=="president" or nationalRole(state,actor)=="council")
end

local function isMinister(state,actor)
  return actor and nationalRole(state,actor)=="minister" and actor.ministryCode and actor.ministryCode~=""
end

local function requireAccess(state,actor)
  if not hasAccess(state,actor) then return nil,"Acces refuse: terminal non autorise sur l'intranet national de North Coalition." end
  return true
end

local function normalizeRef(raw)
  local s=common.trim(raw):upper()
  local n=tonumber(s:match("(%d+)$"))
  if n then return string.format("NC-ART-%03d",n) end
  return s
end

local function lawSearchScore(law,q)
  q=common.normalizeSearch(q)
  if q=="" then return 0 end
  local fields={
    law.id,law.display_reference,law.title,law.text,law.category_code,law.category_name,
    law.legal_branch,law.book_title,law.title_group,law.chapter,law.responsible_authority,
    law.responsible_ministry,table.concat(law.search_tags or {}," ")
  }
  local ref=common.normalizeSearch(law.id or "")
  local display=common.normalizeSearch(law.display_reference or "")
  local title=common.normalizeSearch(law.title or "")
  if ref==q or display==q then return 1000 end
  if string.find(ref,q,1,true) or string.find(display,q,1,true) then return 920 end
  if title==q then return 880 end
  if title:sub(1,#q)==q then return 820 end
  if string.find(title,q,1,true) then return 780 end
  local combined=common.normalizeSearch(table.concat(fields," "))
  if string.find(combined,q,1,true) then return 600 end
  if common.containsAllTokens(combined,q) then return 350 end
  return -1
end

local function makeLaw(seed)
  return {
    id=seed.id,
    number=seed.number,
    book=seed.book,
    book_title=seed.book_title,
    title_group=seed.title_group,
    title=seed.title,
    text=seed.text,
    status=seed.status or "draft",
    version=seed.version or "1.0",
    severity=seed.severity,
    effective_at=seed.effective_at,
    repealed_at=seed.repealed_at,
    history=copy(seed.history or {}),
    category_code=seed.category_code,
    category_name=seed.category_name,
    legal_branch=seed.legal_branch,
    title_code=seed.title_code,
    chapter=seed.chapter,
    chapter_code=seed.chapter_code,
    article_kind=seed.article_kind,
    responsible_authority=seed.responsible_authority,
    responsible_ministry=seed.responsible_ministry,
    display_reference=seed.display_reference,
    search_tags=copy(seed.search_tags or {}),
    createdAt=common.now(),
    updatedAt=common.now()
  }
end

local function makeMinistry(seed)
  return {
    code=seed.code,name=seed.name,scope=copy(seed.scope or {}),
    holderClientId=nil,holderIdentity=nil,appointedAt=nil,appointmentMode=nil,
    appointmentSeal=nil,vacantSince=common.now(),vacantSinceMs=common.nowMs(),
    failedElections=0,lastElectionId=nil,history={}
  }
end

function N.newState()
  local corpus,err=loadCorpus()
  if not corpus then error(err,0) end
  local laws={}
  local maxN=0
  for _,seed in ipairs(corpus.articles or {}) do
    local law=makeLaw(seed)
    laws[law.id]=law
    if (law.number or 0)>maxN then maxN=law.number end
  end
  local ministries={}
  for _,m in ipairs(corpus.ministries or {}) do ministries[m.code]=makeMinistry(m) end
  return {
    meta={
      country=corpus.country or "North Coalition",
      corpusId=corpus.corpus_id or "NC-CORPUS-400-V2.0",
      corpusVersion=corpus.version or "2.0",
      status=corpus.status or "draft",
      projectAuthor=corpus.project_author or "NexoFr_",
      foundingAccount=((corpus.government_system or {}).founding_phase_account or "NexoFr_"),
      presidentIdentity=((corpus.government_system or {}).founding_phase_account or "NexoFr_"),
      presidentClientId=nil,
      stateId=NORTH_STATE_ID,
      foundingMode=true,
      bootstrapAt=nil,
      fallbackNoVoteHours=((corpus.government_system or {}).fallback_no_vote_hours or 48),
      createdAt=common.now(),
      updatedAt=common.now()
    },
    governmentSystem=copy(corpus.government_system or {}),
    categories=copy(corpus.categories or {}),
    laws=laws,
    nextArticle=maxN+1,
    ministries=ministries,
    bills={},billCounters={},
    elections={},electionCounters={},
    decrees={},decreeCounters={},
    nationalAudit={}
  }
end

function N.ensure(state)
  if not state.national then
    state.national=N.newState()
    return state.national,true
  end

  local n=state.national
  n.meta=n.meta or {}
  n.meta.country=n.meta.country or "North Coalition"
  n.meta.stateId=n.meta.stateId or NORTH_STATE_ID
  n.meta.foundingAccount=n.meta.foundingAccount or "NexoFr_"
  n.meta.presidentIdentity=n.meta.presidentIdentity or "NexoFr_"
  if n.meta.foundingMode==nil then n.meta.foundingMode=true end
  n.meta.fallbackNoVoteHours=n.meta.fallbackNoVoteHours or 48
  n.laws=n.laws or {}
  n.categories=n.categories or {}
  n.ministries=n.ministries or {}
  n.bills=n.bills or {}
  n.billCounters=n.billCounters or {}
  n.elections=n.elections or {}
  n.electionCounters=n.electionCounters or {}
  n.decrees=n.decrees or {}
  n.decreeCounters=n.decreeCounters or {}
  n.nationalAudit=n.nationalAudit or {}

  local corpus=loadCorpus()
  if corpus then
    if #n.categories==0 then n.categories=copy(corpus.categories or {}) end
    n.governmentSystem=n.governmentSystem or copy(corpus.government_system or {})
    n.meta.corpusId=n.meta.corpusId or corpus.corpus_id
    n.meta.corpusVersion=n.meta.corpusVersion or corpus.version
    n.meta.projectAuthor=n.meta.projectAuthor or corpus.project_author
    local maxN=tonumber(n.nextArticle or 1)-1
    for _,seed in ipairs(corpus.articles or {}) do
      if not n.laws[seed.id] then n.laws[seed.id]=makeLaw(seed) end
      if (seed.number or 0)>maxN then maxN=seed.number end
    end
    n.nextArticle=math.max(tonumber(n.nextArticle) or 1,maxN+1)
    for _,m in ipairs(corpus.ministries or {}) do
      if not n.ministries[m.code] then n.ministries[m.code]=makeMinistry(m) end
    end
  end

  for _,m in pairs(n.ministries) do
    m.history=m.history or {}
    m.failedElections=m.failedElections or 0
    m.vacantSince=m.vacantSince or common.now()
    m.vacantSinceMs=m.vacantSinceMs or common.nowMs()
  end
  return n,false
end

local function nationalAudit(state,actor,action,objectId,details)
  local n=state.national
  local row={
    at=common.now(),actor=identity(actor),clientId=actor and actor.clientId,
    nationalRole=nationalRole(state,actor),action=action,objectId=objectId,details=details or ""
  }
  n.nationalAudit[#n.nationalAudit+1]=row
  while #n.nationalAudit>1500 do table.remove(n.nationalAudit,1) end
end

local function mutate(ctx,state,actor,action,objectId,details)
  state.national.meta.updatedAt=common.now()
  nationalAudit(state,actor,action,objectId,details)
  ctx.mutate(state,actor,action,objectId,details)
end

local function categoryRows(n)
  local rows={}
  local counts={}
  for _,law in pairs(n.laws) do
    local code=law.category_code or "NC-OTHER"
    counts[code]=counts[code] or {total=0,active=0,draft=0,repealed=0}
    counts[code].total=counts[code].total+1
    counts[code][law.status or "draft"]=(counts[code][law.status or "draft"] or 0)+1
  end
  for _,cat in ipairs(n.categories or {}) do
    local c=copy(cat)
    c.counts=counts[c.code] or {total=0,active=0,draft=0,repealed=0}
    rows[#rows+1]=c
  end
  table.sort(rows,function(a,b) return (a.article_start or 0)<(b.article_start or 0) end)
  return rows
end

local function listLaws(n,p)
  p=p or {}
  local q=common.trim(p.query)
  local status=common.trim(p.status)
  local category=common.trim(p.category_code):upper()
  local titleCode=common.trim(p.title_code):upper()
  local chapterCode=common.trim(p.chapter_code):upper()
  local ministry=common.trim(p.ministry)
  local out={}
  for _,law in pairs(n.laws) do
    local score=lawSearchScore(law,q)
    if (q=="" or score>=0) and
       (status=="" or law.status==status) and
       (category=="" or tostring(law.category_code or ""):upper()==category) and
       (titleCode=="" or tostring(law.title_code or ""):upper()==titleCode) and
       (chapterCode=="" or tostring(law.chapter_code or ""):upper()==chapterCode) and
       (ministry=="" or law.responsible_ministry==ministry) then
      out[#out+1]={
        id=law.id,number=law.number,display_reference=law.display_reference,
        title=law.title,status=law.status,version=law.version,severity=law.severity,
        category_code=law.category_code,category_name=law.category_name,
        legal_branch=law.legal_branch,book=law.book,book_title=law.book_title,
        title_group=law.title_group,title_code=law.title_code,
        chapter=law.chapter,chapter_code=law.chapter_code,
        responsible_ministry=law.responsible_ministry,_score=score
      }
    end
  end
  table.sort(out,function(a,b)
    if q~="" and (a._score or 0)~=(b._score or 0) then return (a._score or 0)>(b._score or 0) end
    return (a.number or 0)<(b.number or 0)
  end)
  for _,row in ipairs(out) do row._score=nil end
  return out
end

local function getLaw(n,raw)
  local ref=normalizeRef(raw)
  local law=n.laws[ref]
  if law then return law end
  local q=common.trim(raw):upper()
  for _,x in pairs(n.laws) do
    if tostring(x.display_reference or ""):upper()==q then return x end
  end
  return nil
end

local function nextId(counterTable,prefix)
  local y=yearNow()
  local v=(counterTable[y] or 0)+1
  counterTable[y]=v
  return string.format("%s-%s-%04d",prefix,y,v)
end

local function uniqueEligibleIdentities(state,electorate)
  local seen,out={},{}
  for _,cl in pairs(state.clients or {}) do
    local r=nationalRole(state,cl)
    local allowed=false
    if electorate=="council" then
      allowed=(r=="president" or r=="council")
    elseif electorate=="citizen" then
      allowed=(r~=nil and r~="public")
    end
    if allowed then
      local id=identity(cl)
      if id~="" and not seen[id] then seen[id]=true;out[#out+1]=id end
    end
  end
  table.sort(out)
  return out
end

local function isEligible(identityValue,eligible)
  for _,x in ipairs(eligible or {}) do if x==identityValue then return true end end
  return false
end

local function billTally(bill)
  local yes,no,abstain=0,0,0
  for _,v in pairs(bill.votes or {}) do
    if v.choice=="yes" then yes=yes+1 elseif v.choice=="no" then no=no+1 else abstain=abstain+1 end
  end
  local eligible=#(bill.eligibleIdentities or {})
  local participation=yes+no+abstain
  local quorumRequired=eligible>0 and math.max(1,math.ceil(eligible*0.5)) or 0
  local quorumMet=eligible>0 and participation>=quorumRequired
  local cast=yes+no
  local adopted=false
  if quorumMet then
    if bill.threshold=="two_thirds_cast" then adopted=cast>0 and yes*3>=cast*2
    elseif bill.threshold=="absolute_members" then adopted=yes>eligible/2
    else adopted=yes>no end
  end
  return {yes=yes,no=no,abstain=abstain,eligible=eligible,participation=participation,quorumRequired=quorumRequired,quorumMet=quorumMet,adopted=adopted}
end

local function electionTally(e)
  local counts={}
  local abstain=0
  for _,v in pairs(e.votes or {}) do
    if v.choice=="abstain" then abstain=abstain+1
    else counts[v.choice]=(counts[v.choice] or 0)+1 end
  end
  local eligible=#(e.eligibleIdentities or {})
  local participation=0
  for _ in pairs(e.votes or {}) do participation=participation+1 end
  local quorumRequired=eligible>0 and math.max(1,math.ceil(eligible*0.5)) or 0
  local quorumMet=eligible>0 and participation>=quorumRequired
  local best,bestN,tie=nil,-1,false
  for clientId,n in pairs(counts) do
    if n>bestN then best,bestN,tie=clientId,n,false
    elseif n==bestN then tie=true end
  end
  if bestN<=0 then best=nil end
  return {
    counts=counts,abstain=abstain,eligible=eligible,participation=participation,
    quorumRequired=quorumRequired,quorumMet=quorumMet,winnerClientId=(quorumMet and not tie) and best or nil,
    tie=tie
  }
end

local function listMinistries(n)
  local out={}
  for _,m in pairs(n.ministries) do out[#out+1]=copy(m) end
  table.sort(out,function(a,b) return tostring(a.code)<tostring(b.code) end)
  return out
end

local function clearMinisterClient(state,clientId)
  if not clientId or clientId=="" then return end
  local cl=state.clients and state.clients[clientId]
  if cl and cl.nationalRole=="minister" then
    cl.nationalRole="citizen"
    cl.ministryCode=nil
  end
end

local function appointMinister(state,n,ctx,actor,ministry,target,mode,sourceId,reason)
  if not ministry or not target then return nil,"Ministere ou terminal candidat invalide." end
  if ministry.holderClientId then return nil,"Ce ministere possede deja un titulaire. Revoquez ou faites demissionner le titulaire avant remplacement." end
  if target.nationalRole=="president" then return nil,"Le terminal presidentiel ne peut pas etre converti en poste ministeriel." end
  if target.ministryCode and target.ministryCode~="" then return nil,"Ce terminal detient deja un portefeuille ministeriel." end
  if not hasAccess(state,target) and target.role~="admin" then return nil,"Le candidat n'est pas autorise sur l'intranet national." end

  target.nationalRole="minister"
  target.ministryCode=ministry.code
  target.nationalIdentity=target.nationalIdentity or target.label
  target.stateId=target.stateId or n.meta.stateId

  ministry.holderClientId=target.clientId
  ministry.holderIdentity=identity(target)
  ministry.appointedAt=common.now()
  ministry.appointmentMode=mode
  ministry.appointmentSourceId=sourceId
  ministry.appointmentReason=reason or ""
  ministry.appointmentSeal=seal("NC-MIN",{
    ministry.code,ministry.holderClientId,ministry.holderIdentity,mode,sourceId,reason,ministry.appointedAt
  })
  ministry.vacantSince=nil
  ministry.vacantSinceMs=nil
  ministry.failedElections=0
  ministry.history[#ministry.history+1]={
    event="appointed",at=ministry.appointedAt,identity=ministry.holderIdentity,
    clientId=target.clientId,mode=mode,sourceId=sourceId,reason=reason or "",seal=ministry.appointmentSeal
  }
  mutate(ctx,state,actor,"NC_MINISTER_APPOINT",ministry.code,ministry.holderIdentity.." / "..mode)
  return copy(ministry)
end

local function directAppointmentAllowed(n,ministry)
  if n.meta.foundingMode then return true,"phase_fondatrice" end
  if (ministry.failedElections or 0)>=2 then return true,"deux_scrutins_echoues" end
  local vacant=tonumber(ministry.vacantSinceMs or 0)
  local wait=(tonumber(n.meta.fallbackNoVoteHours) or 48)*60*60*1000
  if vacant>0 and common.nowMs()>=vacant+wait then return true,"delai_sans_vote_expire" end
  return false,"delai_ou_scrutins_non_satisfaits"
end

local function listBills(n,p)
  p=p or {}
  local q=common.trim(p.query)
  local stage=common.trim(p.stage)
  local out={}
  for _,b in pairs(n.bills) do
    local hit=q=="" or common.contains(b.id,q) or common.contains(b.title,q) or common.contains(b.summary,q) or common.contains(b.targetRef,q) or common.contains(b.categoryCode,q)
    if hit and (stage=="" or b.stage==stage) then
      local row=copy(b)
      row.votes=nil
      row.voteHistory=nil
      row.tally=billTally(b)
      out[#out+1]=row
    end
  end
  table.sort(out,function(a,b) return tostring(a.id)>tostring(b.id) end)
  return out
end

local function listElections(n,p)
  p=p or {}
  local stage=common.trim(p.stage)
  local ministry=common.trim(p.ministryCode):upper()
  local out={}
  for _,e in pairs(n.elections) do
    if (stage=="" or e.stage==stage) and (ministry=="" or e.ministryCode==ministry) then
      local row=copy(e);row.votes=nil;row.tally=electionTally(e);out[#out+1]=row
    end
  end
  table.sort(out,function(a,b) return tostring(a.id)>tostring(b.id) end)
  return out
end

local function listDecrees(n,p)
  p=p or {}
  local q=common.trim(p.query)
  local status=common.trim(p.status)
  local ministry=common.trim(p.ministryCode):upper()
  local out={}
  for _,d in pairs(n.decrees) do
    local hit=q=="" or common.contains(d.id,q) or common.contains(d.title,q) or common.contains(d.body,q) or common.contains(d.legalBasis,q)
    if hit and (status=="" or d.status==status) and (ministry=="" or d.ministryCode==ministry) then out[#out+1]=copy(d) end
  end
  table.sort(out,function(a,b) return tostring(a.id)>tostring(b.id) end)
  return out
end

local function ministryScopeAllowed(state,actor,ministryCode)
  if actor.role=="admin" or nationalRole(state,actor)=="president" then return true end
  return nationalRole(state,actor)=="minister" and actor.ministryCode==ministryCode
end

function N.handle(state,actor,action,p,ctx)
  p=p or {}
  local n=N.ensure(state)

  if action=="NC_INFO" then
    local ok,err=requireAccess(state,actor)
    if not ok then return nil,err end
    return {
      country=n.meta.country,corpusId=n.meta.corpusId,corpusVersion=n.meta.corpusVersion,
      status=n.meta.status,stateId=n.meta.stateId,foundingMode=n.meta.foundingMode,
      foundingAccount=n.meta.foundingAccount,presidentIdentity=n.meta.presidentIdentity,
      presidentClientId=n.meta.presidentClientId,nationalRole=nationalRole(state,actor),
      nationalIdentity=identity(actor),ministryCode=actor.ministryCode,
      fallbackNoVoteHours=n.meta.fallbackNoVoteHours
    }
  end

  if action=="NC_BOOTSTRAP" then
    if actor.role~="admin" then return nil,"Seul un terminal administrateur international peut initialiser l'intranet national." end
    actor.nationalRole="president"
    actor.nationalIdentity=n.meta.foundingAccount or "NexoFr_"
    actor.ministryCode=nil
    actor.stateId=n.meta.stateId
    n.meta.presidentClientId=actor.clientId
    n.meta.presidentIdentity=actor.nationalIdentity
    n.meta.bootstrapAt=n.meta.bootstrapAt or common.now()
    n.meta.foundingMode=true
    mutate(ctx,state,actor,"NC_BOOTSTRAP",actor.clientId,"President fondateur: "..actor.nationalIdentity)
    return {
      nationalRole=actor.nationalRole,nationalIdentity=actor.nationalIdentity,
      presidentClientId=n.meta.presidentClientId,foundingMode=n.meta.foundingMode
    }
  end

  local access,accessErr=requireAccess(state,actor)
  if not access then return nil,accessErr end

  if action=="NC_DASHBOARD" then
    local total,active,draft,repealed=0,0,0,0
    for _,law in pairs(n.laws) do
      total=total+1
      if law.status=="active" then active=active+1 elseif law.status=="repealed" then repealed=repealed+1 else draft=draft+1 end
    end
    local ministriesTotal,filled=0,0
    for _,m in pairs(n.ministries) do ministriesTotal=ministriesTotal+1;if m.holderClientId then filled=filled+1 end end
    local openElections=0
    for _,e in pairs(n.elections) do if e.stage=="open" then openElections=openElections+1 end end
    local votingBills=0
    for _,b in pairs(n.bills) do if b.stage=="voting" then votingBills=votingBills+1 end end
    local publishedDecrees=0
    for _,d in pairs(n.decrees) do if d.status=="published" then publishedDecrees=publishedDecrees+1 end end
    return {
      laws=total,activeLaws=active,draftLaws=draft,repealedLaws=repealed,
      categories=#(n.categories or {}),ministries=ministriesTotal,filledMinistries=filled,
      openElections=openElections,votingBills=votingBills,publishedDecrees=publishedDecrees,
      foundingMode=n.meta.foundingMode,presidentIdentity=n.meta.presidentIdentity,
      nationalRole=nationalRole(state,actor),nationalIdentity=identity(actor),ministryCode=actor.ministryCode
    }
  end

  if action=="NC_CATEGORY_LIST" then return categoryRows(n) end
  if action=="NC_LAW_LIST" then return listLaws(n,p) end
  if action=="NC_LAW_GET" then
    local law=getLaw(n,p.ref or p.id)
    if not law then return nil,"Article national introuvable." end
    return copy(law)
  end

  if action=="NC_GOVERNMENT_GET" then
    return {
      meta=copy(n.meta),governmentSystem=copy(n.governmentSystem),
      ministries=listMinistries(n)
    }
  end

  if action=="NC_MINISTRY_LIST" then return listMinistries(n) end
  if action=="NC_MINISTRY_GET" then
    local m=n.ministries[common.trim(p.code):upper()]
    if not m then return nil,"Ministere introuvable." end
    local out=copy(m)
    out.directAppointmentAllowed,out.directAppointmentReason=directAppointmentAllowed(n,m)
    return out
  end

  if action=="NC_CLIENT_LIST" then
    if not isPresident(state,actor) then return nil,"Reserve a la Presidence ou a l'administration." end
    local out={}
    for _,cl in pairs(state.clients or {}) do
      out[#out+1]={
        clientId=cl.clientId,computerId=cl.computerId,label=cl.label,role=cl.role,
        stateId=cl.stateId,nationalRole=nationalRole(state,cl),storedNationalRole=cl.nationalRole,
        nationalIdentity=identity(cl),ministryCode=cl.ministryCode
      }
    end
    table.sort(out,function(a,b) return tostring(a.nationalIdentity)<tostring(b.nationalIdentity) end)
    return out
  end

  if action=="NC_CLIENT_SET_ROLE" then
    if not isPresident(state,actor) then return nil,"Reserve a la Presidence ou a l'administration." end
    local target=state.clients[common.trim(p.clientId)]
    if not target then return nil,"Terminal introuvable." end
    local wanted=common.trim(p.nationalRole)
    local valid={citizen=true,council=true,judge=true,police=true,civil_servant=true}
    if actor.role=="admin" then valid.president=true;valid.public=true end
    if wanted~="" and not valid[wanted] then
      if wanted=="minister" then return nil,"Un ministre doit etre installe par le registre ministeriel, pas par un changement manuel de role." end
      return nil,"Role national invalide."
    end
    if target.ministryCode and target.ministryCode~="" and wanted~="minister" then
      return nil,"Ce terminal detient un ministere. Retirez d'abord le titulaire via le registre gouvernemental."
    end
    target.nationalRole=(wanted~="" and wanted or nil)
    target.nationalIdentity=common.trim(p.identity)~="" and common.safeName(p.identity) or (target.nationalIdentity or target.label)
    if target.nationalRole then target.stateId=n.meta.stateId end
    if wanted=="president" then
      if actor.role~="admin" then return nil,"Seul l'administrateur peut transferer la fonction presidentielle." end
      local old=n.meta.presidentClientId and state.clients[n.meta.presidentClientId]
      if old and old.clientId~=target.clientId and old.nationalRole=="president" then old.nationalRole="citizen" end
      n.meta.presidentClientId=target.clientId
      n.meta.presidentIdentity=target.nationalIdentity
    end
    mutate(ctx,state,actor,"NC_CLIENT_SET_ROLE",target.clientId,(target.nationalRole or "aucun").." / "..target.nationalIdentity)
    return copy(target)
  end

  if action=="NC_FOUNDING_CLOSE" then
    if not isPresident(state,actor) then return nil,"Reserve a la Presidence." end
    if not n.meta.foundingMode then return {foundingMode=false} end
    n.meta.foundingMode=false
    n.meta.foundingClosedAt=common.now()
    n.meta.foundingClosedBy=identity(actor)
    n.meta.foundingSeal=seal("NC-FOUNDING",{n.meta.foundingClosedAt,n.meta.foundingClosedBy,n.meta.presidentIdentity})
    for _,m in pairs(n.ministries) do
      if not m.holderClientId then m.vacantSince=common.now();m.vacantSinceMs=common.nowMs() end
    end
    mutate(ctx,state,actor,"NC_FOUNDING_CLOSE","NORTH-COALITION",n.meta.foundingSeal)
    return {foundingMode=false,seal=n.meta.foundingSeal}
  end

  if action=="NC_MINISTER_APPOINT_DIRECT" then
    if not isPresident(state,actor) then return nil,"Seule la Presidence peut effectuer une nomination directe." end
    local m=n.ministries[common.trim(p.ministryCode):upper()]
    if not m then return nil,"Ministere introuvable." end
    local target=state.clients[common.trim(p.clientId)]
    if not target then return nil,"Terminal candidat introuvable." end
    local allowed,reason=directAppointmentAllowed(n,m)
    if not allowed and actor.role~="admin" then
      return nil,"Nomination directe non ouverte: attendre "..tostring(n.meta.fallbackNoVoteHours).." h sans scrutin ou deux scrutins echoues."
    end
    return appointMinister(state,n,ctx,actor,m,target,"direct",nil,common.trim(p.reason)~="" and common.trim(p.reason) or reason)
  end

  if action=="NC_MINISTER_REMOVE" then
    if not isPresident(state,actor) then return nil,"Seule la Presidence peut revoquer un ministre." end
    local m=n.ministries[common.trim(p.ministryCode):upper()]
    if not m then return nil,"Ministere introuvable." end
    if not m.holderClientId then return nil,"Ce ministere est deja vacant." end
    local reason=common.trim(p.reason)
    if reason=="" then return nil,"Motif publie obligatoire." end
    local oldId,oldIdentity=m.holderClientId,m.holderIdentity
    local row={
      event="removed",at=common.now(),identity=oldIdentity,clientId=oldId,reason=reason,
      by=identity(actor)
    }
    row.seal=seal("NC-MIN-END",{m.code,oldId,oldIdentity,reason,row.at,row.by})
    m.history[#m.history+1]=row
    clearMinisterClient(state,oldId)
    m.holderClientId=nil;m.holderIdentity=nil;m.appointedAt=nil;m.appointmentMode=nil;m.appointmentSourceId=nil;m.appointmentReason=nil;m.appointmentSeal=nil
    m.vacantSince=common.now();m.vacantSinceMs=common.nowMs()
    mutate(ctx,state,actor,"NC_MINISTER_REMOVE",m.code,oldIdentity.." / "..reason)
    return copy(m)
  end

  if action=="NC_ELECTION_LIST" then return listElections(n,p) end
  if action=="NC_ELECTION_GET" then
    local e=n.elections[common.trim(p.id):upper()]
    if not e then return nil,"Scrutin national introuvable." end
    local out=copy(e);out.tally=electionTally(e);return out
  end

  if action=="NC_ELECTION_CREATE" then
    if not isPresident(state,actor) then return nil,"Le President choisit l'ouverture d'un scrutin ministeriel." end
    local ministry=n.ministries[common.trim(p.ministryCode):upper()]
    if not ministry then return nil,"Ministere introuvable." end
    if ministry.holderClientId then return nil,"Le ministere n'est pas vacant." end
    for _,e in pairs(n.elections) do
      if e.ministryCode==ministry.code and (e.stage=="draft" or e.stage=="open") then return nil,"Un scrutin est deja en cours pour ce ministere." end
    end
    local electorate=(p.electorate=="citizen") and "citizen" or "council"
    local id=nextId(n.electionCounters,"NC-ELECT")
    local e={
      id=id,title=common.trim(p.title)~="" and common.trim(p.title) or ("Election - "..ministry.name),
      ministryCode=ministry.code,electorate=electorate,stage="draft",
      candidates={},votes={},eligibleIdentities={},createdAt=common.now(),createdBy=identity(actor),
      openedAt=nil,closedAt=nil,result=nil,winnerClientId=nil,winnerIdentity=nil
    }
    n.elections[id]=e
    ministry.lastElectionId=id
    mutate(ctx,state,actor,"NC_ELECTION_CREATE",id,ministry.code.." / "..electorate)
    return copy(e)
  end

  if action=="NC_ELECTION_ADD_CANDIDATE" then
    if not isPresident(state,actor) then return nil,"Reserve a la Presidence." end
    local e=n.elections[common.trim(p.id):upper()]
    if not e then return nil,"Scrutin introuvable." end
    if e.stage~="draft" then return nil,"Les candidatures sont verrouillees apres ouverture." end
    local target=state.clients[common.trim(p.clientId)]
    if not target then return nil,"Terminal candidat introuvable." end
    if not hasAccess(state,target) and target.role~="admin" then return nil,"Candidat hors intranet national." end
    if target.nationalRole=="president" or (target.ministryCode and target.ministryCode~="") then return nil,"Candidat deja titulaire d'une fonction incompatible." end
    for _,c in ipairs(e.candidates) do if c.clientId==target.clientId then return copy(e) end end
    e.candidates[#e.candidates+1]={clientId=target.clientId,identity=identity(target),addedAt=common.now()}
    mutate(ctx,state,actor,"NC_ELECTION_ADD_CANDIDATE",e.id,identity(target))
    return copy(e)
  end

  if action=="NC_ELECTION_OPEN" then
    if not isPresident(state,actor) then return nil,"Reserve a la Presidence." end
    local e=n.elections[common.trim(p.id):upper()]
    if not e then return nil,"Scrutin introuvable." end
    if e.stage~="draft" then return nil,"Scrutin deja ouvert ou termine." end
    if #e.candidates==0 then return nil,"Aucun candidat enregistre." end
    e.eligibleIdentities=uniqueEligibleIdentities(state,e.electorate)
    if #e.eligibleIdentities==0 then return nil,"Aucun electeur eligible." end
    e.votes={}
    e.stage="open"
    e.openedAt=common.now()
    e.openedBy=identity(actor)
    e.openSeal=seal("NC-ELECT-OPEN",{e.id,e.ministryCode,e.electorate,e.candidates,e.eligibleIdentities,e.openedAt})
    mutate(ctx,state,actor,"NC_ELECTION_OPEN",e.id,e.openSeal)
    local out=copy(e);out.tally=electionTally(e);return out
  end

  if action=="NC_ELECTION_VOTE" then
    local e=n.elections[common.trim(p.id):upper()]
    if not e then return nil,"Scrutin introuvable." end
    if e.stage~="open" then return nil,"Scrutin ferme." end
    local who=identity(actor)
    if not isEligible(who,e.eligibleIdentities) then return nil,"Vous ne faites pas partie du corps electoral de ce scrutin." end
    local choice=common.trim(p.choice)
    if choice~="abstain" then
      local found=false
      for _,c in ipairs(e.candidates) do if c.clientId==choice then found=true break end end
      if not found then return nil,"Candidat invalide." end
    end
    e.votes[who]={choice=choice,at=common.now(),clientId=actor.clientId}
    local tally=electionTally(e)
    mutate(ctx,state,actor,"NC_ELECTION_VOTE",e.id,who.." -> "..choice)
    local out=copy(e);out.tally=tally;return out
  end

  if action=="NC_ELECTION_CLOSE" then
    if not isPresident(state,actor) then return nil,"Reserve a la Presidence." end
    local e=n.elections[common.trim(p.id):upper()]
    if not e then return nil,"Scrutin introuvable." end
    if e.stage~="open" then return nil,"Scrutin non ouvert." end
    local ministry=n.ministries[e.ministryCode]
    if not ministry then return nil,"Ministere du scrutin introuvable." end
    local tally=electionTally(e)
    e.closedAt=common.now();e.closedBy=identity(actor);e.tallyAtClose=tally
    if not tally.quorumMet then
      e.stage="failed";e.result="no_quorum";ministry.failedElections=(ministry.failedElections or 0)+1
    elseif tally.tie or not tally.winnerClientId then
      e.stage="failed";e.result="tie_or_no_winner";ministry.failedElections=(ministry.failedElections or 0)+1
    else
      e.stage="elected";e.result="elected";e.winnerClientId=tally.winnerClientId
      local target=state.clients[e.winnerClientId]
      e.winnerIdentity=target and identity(target) or e.winnerClientId
    end
    e.resultSeal=seal("NC-ELECT",{e.id,e.ministryCode,e.electorate,e.candidates,e.eligibleIdentities,e.votes,e.result,e.winnerClientId,e.closedAt})
    if e.stage=="elected" then
      local target=state.clients[e.winnerClientId]
      if not target then return nil,"Candidat elu introuvable au moment de la nomination." end
      local appointed,err=appointMinister(state,n,ctx,actor,ministry,target,"elected",e.id,"Election reguliere")
      if not appointed then return nil,err end
      e.appointmentSeal=appointed.appointmentSeal
      -- appointMinister already persisted, but the election fields above are part of the same state table.
      return {election=copy(e),ministry=appointed,tally=tally}
    end
    mutate(ctx,state,actor,"NC_ELECTION_CLOSE",e.id,e.result.." / "..e.resultSeal)
    return {election=copy(e),ministry=copy(ministry),tally=tally}
  end

  if action=="NC_BILL_LIST" then return listBills(n,p) end
  if action=="NC_BILL_GET" then
    local b=n.bills[common.trim(p.id):upper()]
    if not b then return nil,"Projet de loi introuvable." end
    local out=copy(b);out.tally=billTally(b);return out
  end

  if action=="NC_BILL_CREATE" then
    if not roleIs(state,actor,"admin","president","council","minister") then return nil,"Vous ne pouvez pas deposer de projet de loi." end
    local typ=common.trim(p.proposalType)
    local valid={amendment=true,repeal=true,ratification_bundle=true,new_law=true}
    if not valid[typ] then typ="amendment" end
    local title=common.trim(p.title)
    if title=="" then return nil,"Titre du projet obligatoire." end
    local id=nextId(n.billCounters,"NC-BILL")
    local b={
      id=id,title=title,summary=common.trim(p.summary),proposalType=typ,
      stage="draft",threshold=p.threshold=="two_thirds_cast" and "two_thirds_cast" or
        (p.threshold=="absolute_members" and "absolute_members" or "simple_cast"),
      electorate=p.electorate=="citizen" and "citizen" or "council",
      targetRef="",targetRefs={},categoryCode=common.trim(p.categoryCode):upper(),
      proposedTitle=common.trim(p.proposedTitle),proposedText=common.trim(p.proposedText),
      proposedCategoryCode=common.trim(p.proposedCategoryCode):upper(),
      proposedTitleGroup=common.trim(p.proposedTitleGroup),proposedChapter=common.trim(p.proposedChapter),
      proposedKind=common.trim(p.proposedKind),proposedMinistry=common.trim(p.proposedMinistry),
      votes={},voteHistory={},eligibleIdentities={},
      createdAt=common.now(),createdBy=identity(actor),result=nil,enactedRefs={}
    }
    if typ=="amendment" or typ=="repeal" then
      local law=getLaw(n,p.targetRef)
      if not law then return nil,"Article cible introuvable." end
      b.targetRef=law.id
      if typ=="amendment" and b.proposedText=="" then return nil,"Nouveau texte obligatoire." end
      if typ=="amendment" and b.proposedTitle=="" then b.proposedTitle=law.title end
    elseif typ=="ratification_bundle" then
      local seen={}
      if type(p.targetRefs)=="table" then
        for _,raw in ipairs(p.targetRefs) do
          local law=getLaw(n,raw)
          if law and not seen[law.id] then seen[law.id]=true;b.targetRefs[#b.targetRefs+1]=law.id end
        end
      end
      if #b.targetRefs==0 and b.categoryCode~="" then
        for _,law in pairs(n.laws) do if law.category_code==b.categoryCode then b.targetRefs[#b.targetRefs+1]=law.id end end
      end
      table.sort(b.targetRefs)
      if #b.targetRefs==0 then return nil,"Lot de ratification vide." end
    elseif typ=="new_law" then
      if b.proposedTitle=="" or b.proposedText=="" or b.proposedCategoryCode=="" then return nil,"Titre, texte et categorie obligatoires." end
    end
    n.bills[id]=b
    mutate(ctx,state,actor,"NC_BILL_CREATE",id,title.." / "..typ)
    return copy(b)
  end

  if action=="NC_BILL_OPEN" then
    if not isCouncil(state,actor) then return nil,"Ouverture du vote reservee a la Presidence ou au Conseil." end
    local b=n.bills[common.trim(p.id):upper()]
    if not b then return nil,"Projet introuvable." end
    if b.stage~="draft" and b.stage~="debate" and b.stage~="no_quorum" then return nil,"Projet non ouvrable au vote." end
    b.eligibleIdentities=uniqueEligibleIdentities(state,b.electorate)
    if #b.eligibleIdentities==0 then return nil,"Aucun electeur eligible." end
    b.votes={};b.stage="voting";b.openedAt=common.now();b.openedBy=identity(actor)
    b.openSeal=seal("NC-BILL-OPEN",{b.id,b.proposalType,b.electorate,b.threshold,b.eligibleIdentities,b.openedAt})
    mutate(ctx,state,actor,"NC_BILL_OPEN",b.id,b.openSeal)
    local out=copy(b);out.tally=billTally(b);return out
  end

  if action=="NC_BILL_VOTE" then
    local b=n.bills[common.trim(p.id):upper()]
    if not b then return nil,"Projet introuvable." end
    if b.stage~="voting" then return nil,"Vote ferme." end
    local who=identity(actor)
    if not isEligible(who,b.eligibleIdentities) then return nil,"Vous ne faites pas partie du corps electoral." end
    local choice=common.lower(p.choice)
    if choice~="yes" and choice~="no" and choice~="abstain" then return nil,"Vote invalide." end
    b.votes[who]={choice=choice,at=common.now(),clientId=actor.clientId}
    b.voteHistory[#b.voteHistory+1]={identity=who,choice=choice,at=common.now()}
    mutate(ctx,state,actor,"NC_BILL_VOTE",b.id,who.."="..choice)
    local out=copy(b);out.tally=billTally(b);return out
  end

  if action=="NC_BILL_CLOSE" then
    if not isCouncil(state,actor) then return nil,"Cloture reservee a la Presidence ou au Conseil." end
    local b=n.bills[common.trim(p.id):upper()]
    if not b then return nil,"Projet introuvable." end
    if b.stage~="voting" then return nil,"Vote non ouvert." end
    local tally=billTally(b)
    b.closedAt=common.now();b.closedBy=identity(actor)
    if not tally.quorumMet then b.stage="no_quorum";b.result="no_quorum"
    elseif tally.adopted then b.stage="adopted";b.result="adopted"
    else b.stage="rejected";b.result="rejected" end
    b.resultSeal=seal("NC-BILL",{b.id,b.result,b.threshold,b.eligibleIdentities,b.votes,b.closedAt})
    mutate(ctx,state,actor,"NC_BILL_CLOSE",b.id,b.result.." / "..b.resultSeal)
    local out=copy(b);out.tally=tally;return out
  end

  if action=="NC_BILL_ENACT" then
    if not isPresident(state,actor) then return nil,"La promulgation est reservee a la Presidence." end
    local b=n.bills[common.trim(p.id):upper()]
    if not b then return nil,"Projet introuvable." end
    if b.stage~="adopted" then return nil,"Le projet doit etre adopte avant promulgation." end
    local enacted={}
    if b.proposalType=="amendment" then
      local law=n.laws[b.targetRef]
      if not law then return nil,"Article cible introuvable." end
      law.history=law.history or {}
      law.history[#law.history+1]={
        version=law.version,status=law.status,title=law.title,text=law.text,
        archivedAt=common.now(),archivedBy=identity(actor),sourceBill=b.id
      }
      law.title=b.proposedTitle~="" and b.proposedTitle or law.title
      law.text=b.proposedText
      law.version=tostring((tonumber(law.version) or 1)+1)..".0"
      law.updatedAt=common.now();law.updatedBy=identity(actor)
      enacted[#enacted+1]=law.id
    elseif b.proposalType=="repeal" then
      local law=n.laws[b.targetRef]
      if not law then return nil,"Article cible introuvable." end
      law.history[#law.history+1]={version=law.version,status=law.status,title=law.title,text=law.text,archivedAt=common.now(),archivedBy=identity(actor),sourceBill=b.id}
      law.status="repealed";law.repealed_at=common.now();law.updatedAt=common.now()
      enacted[#enacted+1]=law.id
    elseif b.proposalType=="ratification_bundle" then
      for _,ref in ipairs(b.targetRefs or {}) do
        local law=n.laws[ref]
        if law then
          law.history[#law.history+1]={version=law.version,status=law.status,title=law.title,text=law.text,archivedAt=common.now(),archivedBy=identity(actor),sourceBill=b.id}
          law.status="active";law.effective_at=law.effective_at or common.now();law.updatedAt=common.now()
          enacted[#enacted+1]=law.id
        end
      end
    elseif b.proposalType=="new_law" then
      local number=n.nextArticle;n.nextArticle=number+1
      local ref=string.format("NC-ART-%03d",number)
      local cat=nil
      for _,x in ipairs(n.categories) do if x.code==b.proposedCategoryCode then cat=x break end end
      if not cat then return nil,"Categorie cible introuvable." end
      local law={
        id=ref,number=number,book=cat.book,book_title=cat.book_title,
        title_group=b.proposedTitleGroup~="" and b.proposedTitleGroup or "Dispositions nouvelles",
        title=b.proposedTitle,text=b.proposedText,status="active",version="1.0",
        severity=nil,effective_at=common.now(),history={},
        category_code=cat.code,category_name=cat.name,legal_branch=cat.legal_branch,
        title_code=cat.code.."-NEW",chapter=b.proposedChapter~="" and b.proposedChapter or "Dispositions nouvelles",
        chapter_code=cat.code.."-NEW-C1",article_kind=b.proposedKind~="" and b.proposedKind or "legislatif",
        responsible_authority=cat.responsible_authority,responsible_ministry=b.proposedMinistry,
        display_reference=string.format("%s-%03d",cat.code,number),
        search_tags={cat.name,b.proposedTitle,b.proposedMinistry},
        createdAt=common.now(),updatedAt=common.now()
      }
      n.laws[ref]=law
      enacted[#enacted+1]=ref
    end
    b.stage="enacted";b.enactedAt=common.now();b.enactedBy=identity(actor);b.enactedRefs=enacted
    b.enactmentSeal=seal("NC-LAW",{b.id,b.resultSeal,enacted,b.enactedAt,b.enactedBy})
    mutate(ctx,state,actor,"NC_BILL_ENACT",b.id,table.concat(enacted,",").." / "..b.enactmentSeal)
    return copy(b)
  end

  if action=="NC_DECREE_LIST" then return listDecrees(n,p) end
  if action=="NC_DECREE_GET" then
    local d=n.decrees[common.trim(p.id):upper()]
    if not d then return nil,"Decret introuvable." end
    return copy(d)
  end

  if action=="NC_DECREE_CREATE" then
    if not (isPresident(state,actor) or isMinister(state,actor)) then return nil,"Seuls la Presidence et les ministres peuvent rediger un decret." end
    local ministryCode=common.trim(p.ministryCode):upper()
    local scope=common.trim(p.scope)
    if isMinister(state,actor) then
      ministryCode=actor.ministryCode
      scope="ministry"
    elseif scope~="ministry" then
      scope="national"
      ministryCode=""
    elseif ministryCode=="" or not n.ministries[ministryCode] then
      return nil,"Ministere du decret invalide."
    end
    local title=common.trim(p.title)
    local body=common.trim(p.body)
    if title=="" or body=="" then return nil,"Titre et texte obligatoires." end
    local legalBasis=common.trim(p.legalBasis)
    if legalBasis~="" and not getLaw(n,legalBasis) then return nil,"Base legale introuvable." end
    local id=nextId(n.decreeCounters,"NC-DEC")
    local d={
      id=id,title=title,body=body,scope=scope,ministryCode=ministryCode,
      legalBasis=legalBasis,status="draft",createdAt=common.now(),createdBy=identity(actor),
      history={}
    }
    n.decrees[id]=d
    mutate(ctx,state,actor,"NC_DECREE_CREATE",id,title.." / "..scope)
    return copy(d)
  end

  if action=="NC_DECREE_PUBLISH" then
    local d=n.decrees[common.trim(p.id):upper()]
    if not d then return nil,"Decret introuvable." end
    if d.status~="draft" then return nil,"Decret non publiable." end
    if d.scope=="national" then
      if not isPresident(state,actor) then return nil,"Un decret national doit etre publie par la Presidence." end
    else
      if not ministryScopeAllowed(state,actor,d.ministryCode) then return nil,"Vous ne dirigez pas ce ministere." end
    end
    d.status="published";d.publishedAt=common.now();d.publishedBy=identity(actor)
    d.seal=seal("NC-DEC",{d.id,d.title,d.body,d.scope,d.ministryCode,d.legalBasis,d.publishedAt,d.publishedBy})
    mutate(ctx,state,actor,"NC_DECREE_PUBLISH",d.id,d.seal)
    return copy(d)
  end

  if action=="NC_DECREE_REPEAL" then
    local d=n.decrees[common.trim(p.id):upper()]
    if not d then return nil,"Decret introuvable." end
    if d.status~="published" then return nil,"Seul un decret publie peut etre abroge." end
    if d.scope=="national" and not isPresident(state,actor) then return nil,"Reserve a la Presidence." end
    if d.scope=="ministry" and not ministryScopeAllowed(state,actor,d.ministryCode) then return nil,"Vous ne dirigez pas ce ministere." end
    local reason=common.trim(p.reason)
    if reason=="" then return nil,"Motif d'abrogation obligatoire." end
    d.status="repealed";d.repealedAt=common.now();d.repealedBy=identity(actor);d.repealReason=reason
    d.repealSeal=seal("NC-DEC-END",{d.id,d.seal,reason,d.repealedAt,d.repealedBy})
    mutate(ctx,state,actor,"NC_DECREE_REPEAL",d.id,reason.." / "..d.repealSeal)
    return copy(d)
  end

  if action=="NC_AUDIT_LIST" then
    if not roleIs(state,actor,"admin","president","council","judge") then return nil,"Journal national reserve aux institutions autorisees." end
    local limit=math.min(tonumber(p.limit) or 100,300)
    local out={}
    for i=#n.nationalAudit,math.max(1,#n.nationalAudit-limit+1),-1 do out[#out+1]=copy(n.nationalAudit[i]) end
    return out
  end

  return nil,"Action nationale inconnue: "..tostring(action)
end

return N
