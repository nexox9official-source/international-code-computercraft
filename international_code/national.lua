local common = dofile("/international_code/common.lua")
local services,finance,democracy,network

local function loadOperationalModules()
  if not services then services=dofile("/international_code/national_services.lua") end
  if not finance then finance=dofile("/international_code/national_finance.lua") end
  if not democracy then democracy=dofile("/international_code/national_democracy.lua") end
  if not network then network=dofile("/international_code/national_network.lua") end
end

local N = {}
local CORPUS_PATH = "/international_code/national/corpus_v2.json"
local CORPUS_META_PATH = "/international_code/national/corpus_meta.json"
local CORPUS_SHARDS = {
  "/international_code/national/articles_001_100.json",
  "/international_code/national/articles_101_200.json",
  "/international_code/national/articles_201_300.json",
  "/international_code/national/articles_301_400.json"
}
local NORTH_STATE_ID = "STATE-001"

local function readJson(path)
  local raw=common.readAll(path)
  if not raw or raw=="" then return nil,"Fichier absent ou vide: "..path end
  local ok,data=pcall(textutils.unserializeJSON,raw)
  raw=nil
  if not ok or type(data)~="table" then return nil,"JSON invalide: "..path end
  return data
end

local function loadCorpusMeta()
  local meta,err=readJson(CORPUS_META_PATH)
  if meta then return meta end

  -- Compatibilite avec une ancienne installation avant le corpus fragmente.
  local legacy,legacyErr=readJson(CORPUS_PATH)
  if not legacy then return nil,err or legacyErr end
  legacy.articles=nil
  return legacy
end

local function eachCorpusArticle(fn)
  local total=0
  local haveShards=true
  for _,path in ipairs(CORPUS_SHARDS) do
    if not fs.exists(path) then haveShards=false break end
  end

  if haveShards then
    for _,path in ipairs(CORPUS_SHARDS) do
      local rows,err=readJson(path)
      if not rows then return nil,err end
      for _,seed in ipairs(rows) do
        total=total+1
        fn(seed)
      end
      rows=nil
      if collectgarbage then pcall(collectgarbage,"collect") end
    end
    if total~=400 then return nil,"Corpus national incomplet: "..tostring(total).."/400 articles." end
    return total
  end

  -- Fallback temporaire pour les installations qui n'ont pas encore lance ic update.
  local raw=common.readAll(CORPUS_PATH)
  if not raw or raw=="" then return nil,"Corpus national absent. Lancez la mise a jour depuis le centre de controle." end
  local ok,legacy=pcall(textutils.unserializeJSON,raw)
  raw=nil
  if not ok or type(legacy)~="table" or type(legacy.articles)~="table" then
    return nil,"Corpus national historique invalide."
  end
  for _,seed in ipairs(legacy.articles) do total=total+1;fn(seed) end
  legacy=nil
  if collectgarbage then pcall(collectgarbage,"collect") end
  return total
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

local function isSovereignAuthority(state,actor)
  if not actor then return false end
  local meta=state and state.national and state.national.meta or {}
  if meta.sovereignAuthorityActive==false then return false end
  local expected=common.trim(meta.sovereignAuthorityIdentity or "NexoFr_")
  return expected~="" and common.normalizeSearch(identity(actor))==common.normalizeSearch(expected)
end

local function nationalRole(state,actor)
  if not actor then return nil end
  if actor.role=="admin" then return actor.nationalRole or "admin" end
  if actor.nationalRole and actor.nationalRole~="" then return actor.nationalRole end
  return nil
end

local function hasAccess(state,actor)
  return isSovereignAuthority(state,actor) or nationalRole(state,actor)~=nil
end

local function isNationalMember(state,actor)
  if not actor then return false end
  if isSovereignAuthority(state,actor) then return true end
  if actor.role=="admin" and (actor.nationalRole=="admin" or not actor.nationalRole) then return true end
  return actor.nationalRole~=nil and actor.nationalRole~=""
end

local function roleIs(state,actor,...)
  if actor and actor.nationalRoot then return true end
  local r=nationalRole(state,actor)
  for i=1,select("#",...) do if r==select(i,...) then return true end end
  return false
end

local function isPresident(state,actor)
  return actor and (actor.nationalRoot==true or actor.role=="admin" or nationalRole(state,actor)=="president")
end

local function isCouncil(state,actor)
  return actor and (actor.nationalRoot==true or actor.role=="admin" or nationalRole(state,actor)=="president" or nationalRole(state,actor)=="council")
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
  -- Les metadonnees de categorie repetitives sont derivees de n.categories
  -- au moment de l'affichage. Cela economise plusieurs centaines de Ko
  -- dans state.tbl sans retirer le texte ni les references juridiques.
  return {
    id=seed.id,
    number=seed.number,
    book=seed.book,
    title_group=seed.title_group,
    title=seed.title,
    text=seed.text,
    status=seed.status or "draft",
    version=seed.version or "1.0",
    severity=seed.severity,
    effective_at=seed.effective_at,
    repealed_at=seed.repealed_at,
    history={},
    category_code=seed.category_code,
    title_code=seed.title_code,
    chapter=seed.chapter,
    chapter_code=seed.chapter_code,
    article_kind=seed.article_kind,
    responsible_ministry=seed.responsible_ministry,
    display_reference=seed.display_reference
  }
end

local function categoryFor(n,code)
  for _,cat in ipairs(n.categories or {}) do
    if cat.code==code then return cat end
  end
  return nil
end

local function lawView(n,law)
  local out=copy(law)
  local cat=categoryFor(n,law.category_code)
  if cat then
    out.category_name=out.category_name or cat.name
    out.legal_branch=out.legal_branch or cat.legal_branch
    out.book_title=out.book_title or cat.book_title
    out.responsible_authority=out.responsible_authority or cat.responsible_authority
  end
  out.history=out.history or {}
  out.search_tags=out.search_tags or {}
  return out
end

local function compactLawInPlace(law)
  if not law then return end
  law.category_name=nil
  law.legal_branch=nil
  law.book_title=nil
  law.responsible_authority=nil
  law.search_tags=nil
  -- Les deux traces de creation/ratification du corpus sont deja encodees
  -- par status/version/effective_at. Les changements ulterieurs restent.
  if type(law.history)=="table" and #law.history>0 then
    local kept={}
    for _,h in ipairs(law.history) do
      local note=tostring(h.note or h.event or "")
      local initial=(note=="Projet initial du Code national" or
        note=="Ratification et adoption du Corpus national v2.0")
      if not initial then kept[#kept+1]=h end
    end
    law.history=kept
  end
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
  local corpus,err=loadCorpusMeta()
  if not corpus then error(err,0) end
  local laws={}
  local maxN=0
  local count,articleErr=eachCorpusArticle(function(seed)
    local law=makeLaw(seed)
    laws[law.id]=law
    if (law.number or 0)>maxN then maxN=law.number end
  end)
  if not count then error(articleErr,0) end
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
      sovereignAuthorityIdentity=((corpus.government_system or {}).sovereign_authority_account or "NexoFr_"),
      sovereignAuthorityTitle=((corpus.government_system or {}).sovereign_authority_title or "Dirigeant de North Coalition"),
      sovereignAuthorityPowers=copy((corpus.government_system or {}).sovereign_authority_powers or {}),
      sovereignAuthorityActive=((corpus.government_system or {}).sovereign_authority_active~=false),
      sovereignAuthorityTenure=((corpus.government_system or {}).sovereign_authority_tenure or "perpetual_until_voluntary_relinquishment"),
      sovereignAuthorityRelinquishedAt=nil,
      sovereignAuthorityRelinquishedSeal=nil,
      ratifiedAt=((corpus.ratification or {}).ratified_at),
      ratifiedBy=((corpus.ratification or {}).promulgated_by or "NexoFr_"),
      corpusRatificationApplied=(corpus.status=="ratified"),
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
    cases={},caseCounters={},
    sessions={},sessionCounters={},
    gazette={},gazetteCounters={},
    citizens={},nextCitizen=1,
    organizations={},nextOrganization=1,
    licenses={},licenseCounters={},
    fines={},fineCounters={},
    generalElections={},generalElectionCounters={},
    mandates={},mandateCounters={},councilMembers={},
    nationalAudit={}
  }
end

function N.ensure(state)
  loadOperationalModules()
  if not state.national then
    state.national=N.newState()
    democracy.ensure(state.national)
    return state.national,true
  end

  local n=state.national
  local changed=false
  n.meta=n.meta or {}
  n.meta.country=n.meta.country or "North Coalition"
  n.meta.stateId=n.meta.stateId or NORTH_STATE_ID
  n.meta.foundingAccount=n.meta.foundingAccount or "NexoFr_"
  n.meta.presidentIdentity=n.meta.presidentIdentity or "NexoFr_"
  n.meta.sovereignAuthorityIdentity=n.meta.sovereignAuthorityIdentity or "NexoFr_"
  n.meta.sovereignAuthorityTitle=n.meta.sovereignAuthorityTitle or "Dirigeant de North Coalition"
  n.meta.sovereignAuthorityPowers=n.meta.sovereignAuthorityPowers or {}
  if n.meta.sovereignAuthorityActive==nil then n.meta.sovereignAuthorityActive=true end
  n.meta.sovereignAuthorityTenure=n.meta.sovereignAuthorityTenure or "perpetual_until_voluntary_relinquishment"
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
  n.cases=n.cases or {}
  n.caseCounters=n.caseCounters or {}
  n.sessions=n.sessions or {}
  n.sessionCounters=n.sessionCounters or {}
  n.gazette=n.gazette or {}
  n.gazetteCounters=n.gazetteCounters or {}
  n.citizens=n.citizens or {}
  local maxCitizen=0
  for id in pairs(n.citizens) do
    local num=tonumber(tostring(id):match("NC%-CIT%-(%d+)")) or 0
    if num>maxCitizen then maxCitizen=num end
  end
  n.nextCitizen=math.max(tonumber(n.nextCitizen) or 1,maxCitizen+1)
  services.ensure(n)
  finance.ensure(n)
  democracy.ensure(n)
  network.ensure(n)
  n.nationalAudit=n.nationalAudit or {}

  if n.meta.compactLawStorageV1~=true then
    for _,law in pairs(n.laws or {}) do compactLawInPlace(law) end
    n.meta.compactLawStorageV1=true
    changed=true
  end

  local corpus=loadCorpusMeta()
  if corpus then
    if #n.categories==0 then n.categories=copy(corpus.categories or {}) end
    n.governmentSystem=n.governmentSystem or copy(corpus.government_system or {})
    for k,v in pairs(corpus.government_system or {}) do
      if k=="sovereign_authority_powers" then n.governmentSystem[k]=copy(v)
      else n.governmentSystem[k]=v end
    end
    n.meta.corpusId=corpus.corpus_id or n.meta.corpusId
    n.meta.corpusVersion=corpus.version or n.meta.corpusVersion
    n.meta.projectAuthor=corpus.project_author or n.meta.projectAuthor
    n.meta.status=corpus.status or n.meta.status
    n.meta.sovereignAuthorityIdentity=((corpus.government_system or {}).sovereign_authority_account or n.meta.sovereignAuthorityIdentity or "NexoFr_")
    n.meta.sovereignAuthorityTitle=((corpus.government_system or {}).sovereign_authority_title or n.meta.sovereignAuthorityTitle)
    n.meta.sovereignAuthorityPowers=copy((corpus.government_system or {}).sovereign_authority_powers or n.meta.sovereignAuthorityPowers or {})
    n.meta.sovereignAuthorityTenure=((corpus.government_system or {}).sovereign_authority_tenure or n.meta.sovereignAuthorityTenure)
    if n.meta.sovereignAuthorityActive==nil then
      n.meta.sovereignAuthorityActive=((corpus.government_system or {}).sovereign_authority_active~=false)
    end

    local applyRatification=(corpus.status=="ratified" and n.meta.corpusRatificationApplied~=true)
    local applyPermanence=(n.meta.sovereignPermanenceApplied~=true)
    local permanentRefs={
      ["NC-ART-061"]=true,["NC-ART-093"]=true,["NC-ART-094"]=true,
      ["NC-ART-095"]=true,["NC-ART-400"]=true
    }
    local maxN=tonumber(n.nextArticle or 1)-1
    local articleCount,articleErr=eachCorpusArticle(function(seed)
      local law=n.laws[seed.id]
      if not law then
        law=makeLaw(seed)
        n.laws[seed.id]=law
        changed=true
      end
      if (seed.number or 0)>maxN then maxN=seed.number end

      if applyRatification then
        law.title=seed.title
        law.text=seed.text
        law.status=seed.status or "active"
        law.version=seed.version or law.version
        law.effective_at=seed.effective_at
        law.repealed_at=seed.repealed_at
        law.history=copy(seed.history or law.history or {})
        law.updatedAt=common.now()
      end

      if applyPermanence and permanentRefs[seed.id] then
        law.title=seed.title
        law.text=seed.text
        law.status=seed.status or law.status or "active"
        law.version=seed.version or law.version
        law.effective_at=seed.effective_at or law.effective_at
        law.repealed_at=seed.repealed_at
        law.history=copy(seed.history or law.history or {})
        law.search_tags=copy(seed.search_tags or law.search_tags or {})
        law.updatedAt=common.now()
        law.updatedBy="NexoFr_"
      end
    end)

    if articleCount then
      n.nextArticle=math.max(tonumber(n.nextArticle) or 1,maxN+1)
    end

    for _,m in ipairs(corpus.ministries or {}) do
      if not n.ministries[m.code] then n.ministries[m.code]=makeMinistry(m);changed=true end
    end

    if applyRatification and articleCount then
      n.meta.status="ratified"
      n.meta.ratifiedAt=((corpus.ratification or {}).ratified_at or common.now())
      n.meta.ratifiedBy=((corpus.ratification or {}).promulgated_by or "NexoFr_")
      n.meta.corpusRatificationApplied=true
      n.meta.updatedAt=common.now()
      changed=true
    end

    if applyPermanence and articleCount then
      if n.meta.sovereignAuthorityActive==nil then n.meta.sovereignAuthorityActive=true end
      n.meta.sovereignAuthorityTenure=((corpus.government_system or {}).sovereign_authority_tenure or "perpetual_until_voluntary_relinquishment")
      n.meta.sovereignPermanenceApplied=true
      n.meta.updatedAt=common.now()
      changed=true
    end

    if not articleCount and articleErr then
      n.meta.corpusLoadError=articleErr
    else
      n.meta.corpusLoadError=nil
    end
  end

  for _,m in pairs(n.ministries) do
    m.history=m.history or {}
    m.failedElections=m.failedElections or 0
    m.vacantSince=m.vacantSince or common.now()
    m.vacantSinceMs=m.vacantSinceMs or common.nowMs()
  end
  return n,changed
end


local function notice(ctx,state,spec)
  if ctx and ctx.pushNotice then return ctx.pushNotice(state,spec) end
end

local function noticeAll(ctx,state,n,title,body,severity,objectType,objectId)
  return notice(ctx,state,{
    title=title,body=body,severity=severity or "info",
    objectType=objectType,objectId=objectId,targetStateId=n.meta.stateId
  })
end

local function noticeEligible(ctx,state,e,title,body,severity,objectType,objectId)
  if not ctx or not ctx.pushNotice then return end
  local wanted={}
  for _,id in ipairs(e.eligibleIdentities or {}) do wanted[id]=true end
  for _,cl in pairs(state.clients or {}) do
    local id=(cl.citizenId and state.national and state.national.citizens and state.national.citizens[cl.citizenId]) and cl.citizenId or identity(cl)
    if wanted[id] then
      ctx.pushNotice(state,{
        title=title,body=body,severity=severity or "info",
        objectType=objectType,objectId=objectId,targetClientId=cl.clientId
      })
    end
  end
end

local function listNationalNotices(ctx,state,actor,p)
  if not ctx or not ctx.listNotices then return {} end
  local rows=ctx.listNotices(state,actor,{unreadOnly=p and p.unreadOnly==true})
  local out={}
  for _,row in ipairs(rows or {}) do
    if tostring(row.objectType or ""):sub(1,3)=="nc_" then out[#out+1]=row end
  end
  return out
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
  for _,storedLaw in pairs(n.laws) do
    local law=lawView(n,storedLaw)
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

local function gazetteVisibilityAllowed(state,actor,entry)
  if not actor or not entry then return false end
  if actor.role=="admin" and (not actor.nationalRole or actor.nationalRole=="admin") then return true end
  local r=nationalRole(state,actor)
  local visibility=entry.visibility or "internal"
  if visibility=="public" or visibility=="internal" then return hasAccess(state,actor) end
  if visibility=="judicial" then return r=="judge" or r=="prosecutor" end
  if visibility=="restricted" then return r=="president" or r=="council" end
  return false
end

local function publishGazette(n,actor,kind,objectId,title,summary,sourceSeal,visibility)
  local id=nextId(n.gazetteCounters,"NC-GAZ")
  local row={
    id=id,kind=kind,objectId=objectId,title=title,summary=summary or "",
    sourceSeal=sourceSeal or "",visibility=visibility or "internal",
    publishedAt=common.now(),publishedBy=identity(actor)
  }
  row.seal=seal("NC-GAZ",{row.id,row.kind,row.objectId,row.title,row.summary,row.sourceSeal,row.visibility,row.publishedAt,row.publishedBy})
  n.gazette[id]=row
  return row
end

local function listGazette(n,p,state,actor)
  p=p or {}
  local q=common.trim(p.query)
  local kind=common.trim(p.kind)
  local visibility=common.trim(p.visibility)
  local out={}
  for _,row in pairs(n.gazette or {}) do
    local hit=(q=="" or common.contains(row.id,q) or common.contains(row.objectId,q) or
      common.contains(row.title,q) or common.contains(row.summary,q) or common.contains(row.kind,q))
    if hit and (kind=="" or row.kind==kind) and
       (visibility=="" or row.visibility==visibility) and
       gazetteVisibilityAllowed(state,actor,row) then
      out[#out+1]=copy(row)
    end
  end
  table.sort(out,function(a,b) return tostring(a.id)>tostring(b.id) end)
  return out
end

local function nextCitizenId(n)
  local id=string.format("NC-CIT-%04d",tonumber(n.nextCitizen) or 1)
  n.nextCitizen=(tonumber(n.nextCitizen) or 1)+1
  return id
end

local function findCitizenByIdentity(n,raw)
  local q=common.normalizeSearch(raw)
  if q=="" then return nil end
  for _,cit in pairs(n.citizens or {}) do
    if common.normalizeSearch(cit.identity or "")==q or common.normalizeSearch(cit.displayName or "")==q then return cit end
  end
  return nil
end

local function citizenForClient(n,cl)
  if not cl then return nil end
  if cl.citizenId and n.citizens[cl.citizenId] then return n.citizens[cl.citizenId] end
  return findCitizenByIdentity(n,identity(cl))
end

local function createCitizen(n,identityValue,status,createdBy,notes)
  identityValue=common.safeName(identityValue)
  if identityValue=="" then return nil,"Identite citoyenne obligatoire." end
  local existing=findCitizenByIdentity(n,identityValue)
  if existing then return existing,nil,false end
  local id=nextCitizenId(n)
  local valid={citizen=true,resident=true,suspended=true,deceased=true}
  local row={
    id=id,identity=identityValue,displayName=identityValue,
    status=valid[status] and status or "citizen",
    notes=common.trim(notes),createdAt=common.now(),createdBy=createdBy or "system",
    updatedAt=common.now(),history={}
  }
  row.seal=seal("NC-CIT",{row.id,row.identity,row.status,row.createdAt,row.createdBy})
  n.citizens[id]=row
  return row,nil,true
end

local function votingKey(n,cl)
  local cit=citizenForClient(n,cl)
  if cit and cit.status=="citizen" then return cit.id end
  return nil
end

local function isVotingCitizen(n,cl)
  return votingKey(n,cl)~=nil
end

local function migrateClientCitizens(n,state)
  for _,cl in pairs(state.clients or {}) do
    if cl.nationalRole and cl.nationalRole~="" and cl.nationalRole~="public" and not cl.citizenId then
      local citizen=select(1,createCitizen(n,identity(cl),"citizen","migration","Migration automatique des habilitations nationales"))
      if citizen then cl.citizenId=citizen.id end
    end
  end
end

local function uniqueEligibleIdentities(state,electorate)
  local n=state.national
  local seen,out={},{}
  for _,cl in pairs(state.clients or {}) do
    if isNationalMember(state,cl) and isVotingCitizen(n,cl) then
      local r=cl.nationalRole or "citizen"
      local allowed=false
      if electorate=="council" then
        allowed=(r=="president" or r=="council")
      elseif electorate=="citizen" then
        allowed=(r~="public")
      end
      if allowed then
        local key=votingKey(n,cl)
        if key and not seen[key] then seen[key]=true;out[#out+1]=key end
      end
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
  if not isNationalMember(state,target) or not isVotingCitizen(n,target) then return nil,"Le candidat doit etre un citoyen national enregistre et actif." end

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
  noticeAll(ctx,state,n,"Nomination ministerielle",
    ministry.holderIdentity.." devient titulaire de "..ministry.name.." ("..ministry.code..").",
    "success","nc_ministry",ministry.code)
  notice(ctx,state,{title="Vous etes nomme ministre",body=ministry.name.." / "..ministry.code,
    severity="success",objectType="nc_ministry",objectId=ministry.code,targetClientId=target.clientId})
  local gaz=publishGazette(n,actor,"ministry_appointment",ministry.code,
    "Nomination - "..ministry.name,
    ministry.holderIdentity.." est nomme titulaire par "..mode..
      (sourceId and (" / source "..sourceId) or "")..".",
    ministry.appointmentSeal,"internal")
  ministry.lastGazetteId=gaz.id
  mutate(ctx,state,actor,"NC_MINISTER_APPOINT",ministry.code,ministry.holderIdentity.." / "..mode.." / "..gaz.id)
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

local function technicalNationalAdmin(actor)
  return actor and (actor.nationalRoot==true or
    (actor.role=="admin" and (not actor.nationalRole or actor.nationalRole=="admin")))
end

local function canManageCitizens(state,actor)
  local r=nationalRole(state,actor)
  return technicalNationalAdmin(actor) or r=="president" or (r=="minister" and actor.ministryCode=="MIN-INT")
end

local function citizenView(cit,full)
  local out=copy(cit)
  if not full then
    out.notes=nil
    out.history=nil
  end
  return out
end

local function listCitizens(n,p,full)
  p=p or {}
  local q=common.trim(p.query)
  local status=common.trim(p.status)
  local out={}
  for _,cit in pairs(n.citizens or {}) do
    local hit=(q=="" or common.contains(cit.id,q) or common.contains(cit.identity,q) or common.contains(cit.displayName,q))
    if hit and (status=="" or cit.status==status) then out[#out+1]=citizenView(cit,full) end
  end
  table.sort(out,function(a,b) return tostring(a.id)<tostring(b.id) end)
  return out
end

local function nationalCaseInstitutionalRole(state,actor)
  local r=nationalRole(state,actor)
  return actor and (technicalNationalAdmin(actor) or r=="judge" or r=="prosecutor" or r=="police")
end

local function nationalCaseJudicialRole(state,actor)
  local r=nationalRole(state,actor)
  return actor and (technicalNationalAdmin(actor) or r=="judge")
end

local function canViewNationalCase(state,actor,case)
  if not actor or not case then return false end
  local r=nationalRole(state,actor)
  local visibility=case.visibility or "restricted"
  if technicalNationalAdmin(actor) or r=="judge" or r=="prosecutor" then return true end
  if r=="police" then return visibility~="sealed" end
  local who=identity(actor)
  if who~="" and (who==case.complainant or who==case.accused) then return visibility~="sealed" end
  return visibility=="public"
end

local function ensureNationalCaseShape(case)
  case.facts=case.facts or {}
  case.evidence=case.evidence or {}
  case.citedArticles=case.citedArticles or {}
  case.hearings=case.hearings or {}
  case.judgments=case.judgments or {}
  case.orders=case.orders or {}
  case.appeals=case.appeals or {}
  case.timeline=case.timeline or {}
  case.visibility=case.visibility or "restricted"
  case.status=case.status or "open"
  return case
end

local function addNationalCaseTimeline(case,kind,title,details,actor)
  ensureNationalCaseShape(case)
  case.timeline[#case.timeline+1]={
    at=common.now(),kind=kind,title=title,details=details or "",
    actor=actor and identity(actor) or "system"
  }
  while #case.timeline>500 do table.remove(case.timeline,1) end
end

local function listNationalCases(n,p,state,actor)
  p=p or {}
  local q=common.trim(p.query)
  local status=common.trim(p.status)
  local caseType=common.trim(p.caseType)
  local visibility=common.trim(p.visibility)
  local out={}
  for _,case in pairs(n.cases or {}) do
    ensureNationalCaseShape(case)
    local hit=(q=="" or common.contains(case.id,q) or common.contains(case.title,q) or
      common.contains(case.complainant,q) or common.contains(case.accused,q) or common.contains(case.summary,q))
    if hit and (status=="" or case.status==status) and
       (caseType=="" or case.caseType==caseType) and
       (visibility=="" or case.visibility==visibility) and
       canViewNationalCase(state,actor,case) then
      out[#out+1]={
        id=case.id,title=case.title,caseType=case.caseType,status=case.status,
        visibility=case.visibility,complainant=case.complainant,accused=case.accused,
        createdAt=case.createdAt,updatedAt=case.updatedAt
      }
    end
  end
  table.sort(out,function(a,b) return tostring(a.id)>tostring(b.id) end)
  return out
end

local function nationalCaseId(n)
  return nextId(n.caseCounters,"NC-CASE")
end

local function nationalLawSnapshot(n,refs)
  local out={}
  for _,raw in ipairs(refs or {}) do
    local law=getLaw(n,raw)
    if law then
      out[#out+1]={
        id=law.id,display_reference=law.display_reference,title=law.title,
        version=law.version,status=law.status,category_code=law.category_code
      }
    end
  end
  return out
end

local function notifyNationalCase(ctx,state,case,title,body,severity)
  if not ctx or not ctx.pushNotice then return end
  local wanted={}
  if case.complainant and case.complainant~="" then wanted[case.complainant]=true end
  if case.accused and case.accused~="" then wanted[case.accused]=true end
  local sent={}
  for _,cl in pairs(state.clients or {}) do
    local r=nationalRole(state,cl)
    local id=identity(cl)
    if wanted[id] or r=="judge" or r=="prosecutor" then
      if not sent[cl.clientId] then
        sent[cl.clientId]=true
        ctx.pushNotice(state,{
          title=title,body=body,severity=severity or "info",
          objectType="nc_case",objectId=case.id,targetClientId=cl.clientId
        })
      end
    end
  end
end


local function nationalSessionManager(state,actor)
  local r=nationalRole(state,actor)
  return technicalNationalAdmin(actor) or r=="president" or r=="council"
end

local function canViewNationalSession(state,actor,sess)
  if not actor or not sess then return false end
  if technicalNationalAdmin(actor) then return true end
  local visibility=sess.visibility or "internal"
  if visibility~="restricted" then return hasAccess(state,actor) end
  local r=nationalRole(state,actor)
  return r=="president" or r=="council" or r=="minister" or r=="judge" or r=="prosecutor"
end

local function listNationalSessions(n,p,state,actor)
  p=p or {}
  local q=common.trim(p.query)
  local status=common.trim(p.status)
  local sessionType=common.trim(p.sessionType)
  local out={}
  for _,sess in pairs(n.sessions or {}) do
    local hit=(q=="" or common.contains(sess.id,q) or common.contains(sess.title,q) or
      common.contains(sess.description,q) or common.contains(sess.location,q))
    if hit and (status=="" or sess.status==status) and
       (sessionType=="" or sess.sessionType==sessionType) and
       canViewNationalSession(state,actor,sess) then
      local row=copy(sess)
      row.attendanceCount=0
      for _ in pairs(sess.attendance or {}) do row.attendanceCount=row.attendanceCount+1 end
      out[#out+1]=row
    end
  end
  table.sort(out,function(a,b)
    if a.status~=b.status then
      local rank={open=4,scheduled=3,closed=2,cancelled=1}
      return (rank[a.status] or 0)>(rank[b.status] or 0)
    end
    return tostring(a.id)>tostring(b.id)
  end)
  return out
end

local function nationalSessionEligible(n,state,actor,sess)
  if technicalNationalAdmin(actor) then return true end
  if not isVotingCitizen(n,actor) then return false end
  local r=nationalRole(state,actor)
  if sess.sessionType=="council" then return r=="president" or r=="council" end
  if sess.sessionType=="cabinet" then return r=="president" or r=="minister" end
  if sess.sessionType=="emergency" then
    return r=="president" or r=="council" or r=="minister" or r=="judge" or r=="prosecutor" or r=="police"
  end
  if sess.sessionType=="committee" then return r~="public" and r~="citizen" end
  return r~="public"
end

local function agendaObjectTitle(n,state,actor,kind,ref)
  ref=common.trim(ref):upper()
  if kind=="law" then
    local x=getLaw(n,ref);return x and x.title or nil
  elseif kind=="bill" then
    local x=n.bills[ref];return x and x.title or nil
  elseif kind=="election" then
    local x=n.elections[ref];return x and x.title or nil
  elseif kind=="decree" then
    local x=n.decrees[ref];return x and x.title or nil
  elseif kind=="case" then
    local x=n.cases[ref]
    if x and canViewNationalCase(state,actor,x) then return x.title end
    return nil
  elseif kind=="ministry" then
    local x=n.ministries[ref];return x and x.name or nil
  elseif kind=="citizen" then
    local x=n.citizens[ref];return x and x.displayName or nil
  elseif kind=="custom" then
    return ref~="" and ref or nil
  end
  return nil
end

function N.handle(state,actor,action,p,ctx)
  p=p or {}
  local n=N.ensure(state)
  migrateClientCitizens(n,state)

  if actor and isSovereignAuthority(state,actor) then
    actor.nationalRoot=true
    actor.nationalIdentity=n.meta.sovereignAuthorityIdentity or "NexoFr_"
    actor.nationalRole=actor.nationalRole or "president"
    actor.stateId=n.meta.stateId
    if not actor.citizenId then
      local founder=select(1,createCitizen(n,actor.nationalIdentity,"citizen",actor.nationalIdentity,
        "Autorite souveraine nationale de North Coalition"))
      actor.citizenId=founder and founder.id or actor.citizenId
    end
    if not n.meta.presidentClientId then
      n.meta.presidentClientId=actor.clientId
      n.meta.presidentCitizenId=actor.citizenId
      n.meta.presidentIdentity=actor.nationalIdentity
    end
  elseif actor then
    actor.nationalRoot=false
  end

  if action=="NC_INFO" then
    local ok,err=requireAccess(state,actor)
    if not ok then return nil,err end
    return {
      country=n.meta.country,corpusId=n.meta.corpusId,corpusVersion=n.meta.corpusVersion,
      status=n.meta.status,stateId=n.meta.stateId,foundingMode=n.meta.foundingMode,
      foundingAccount=n.meta.foundingAccount,presidentIdentity=n.meta.presidentIdentity,
      presidentCitizenId=n.meta.presidentCitizenId,presidentClientId=n.meta.presidentClientId,
      councilMembers=copy(n.councilMembers or {}),defaultCouncilSeats=n.meta.defaultCouncilSeats,
      nationalRole=nationalRole(state,actor),
      nationalIdentity=identity(actor),citizenId=actor.citizenId,
      citizenStatus=(citizenForClient(n,actor) or {}).status,ministryCode=actor.ministryCode,
      fallbackNoVoteHours=n.meta.fallbackNoVoteHours,
      sovereignAuthority=actor and actor.nationalRoot==true or false,
      sovereignAuthorityIdentity=n.meta.sovereignAuthorityIdentity,
      sovereignAuthorityTitle=n.meta.sovereignAuthorityTitle,
      sovereignAuthorityPowers=copy(n.meta.sovereignAuthorityPowers or {}),
      sovereignAuthorityActive=n.meta.sovereignAuthorityActive~=false,
      sovereignAuthorityTenure=n.meta.sovereignAuthorityTenure,
      sovereignAuthorityRelinquishedAt=n.meta.sovereignAuthorityRelinquishedAt,
      sovereignAuthorityRelinquishedSeal=n.meta.sovereignAuthorityRelinquishedSeal,
      ratifiedAt=n.meta.ratifiedAt,ratifiedBy=n.meta.ratifiedBy
    }
  end

  if action=="NC_BOOTSTRAP" then
    if actor.role~="admin" then return nil,"Seul un terminal administrateur international peut initialiser l'intranet national." end
    if n.meta.bootstrapAt then return nil,"L'intranet national a deja ete initialise; le bootstrap fondateur ne peut pas etre rejoue." end
    actor.nationalRole="president"
    actor.nationalIdentity=n.meta.foundingAccount or "NexoFr_"
    actor.ministryCode=nil
    actor.stateId=n.meta.stateId
    local founder=select(1,createCitizen(n,actor.nationalIdentity,"citizen",actor.nationalIdentity,"Compte fondateur de North Coalition"))
    actor.citizenId=founder and founder.id or actor.citizenId
    n.meta.presidentClientId=actor.clientId
    n.meta.presidentCitizenId=actor.citizenId
    n.meta.presidentIdentity=actor.nationalIdentity
    n.meta.bootstrapAt=n.meta.bootstrapAt or common.now()
    n.meta.foundingMode=true
    noticeAll(ctx,state,n,"Intranet national initialise",
      "La Presidence de North Coalition est enregistree sous l'identite "..actor.nationalIdentity..".",
      "success","nc_government","PRESIDENCY")
    mutate(ctx,state,actor,"NC_BOOTSTRAP",actor.clientId,"President fondateur: "..actor.nationalIdentity)
    return {
      nationalRole=actor.nationalRole,nationalIdentity=actor.nationalIdentity,
      presidentClientId=n.meta.presidentClientId,foundingMode=n.meta.foundingMode
    }
  end

  if action=="NC_SOVEREIGN_RELINQUISH" then
    if not actor or actor.nationalRoot~=true or not isSovereignAuthority(state,actor) then
      return nil,"Seul NexoFr_ peut renoncer a la direction souveraine de North Coalition."
    end
    if n.meta.sovereignAuthorityActive==false then
      return nil,"L'autorite souveraine a deja fait l'objet d'une renonciation."
    end
    if common.trim(p.confirmation)~="JE RENONCE VOLONTAIREMENT A LA DIRECTION DE NORTH COALITION" then
      return nil,"Confirmation exacte requise pour cette renonciation volontaire."
    end
    local reason=common.trim(p.reason)
    local at=common.now()
    local relinquishSeal=seal("NC-SOV-RELINQUISH",{
      n.meta.sovereignAuthorityIdentity,at,reason,actor.clientId,actor.citizenId
    })
    n.meta.sovereignAuthorityActive=false
    n.meta.sovereignAuthorityRelinquishedAt=at
    n.meta.sovereignAuthorityRelinquishedBy=identity(actor)
    n.meta.sovereignAuthorityRelinquishedReason=reason
    n.meta.sovereignAuthorityRelinquishedSeal=relinquishSeal
    n.meta.presidentIdentity=nil
    n.meta.presidentClientId=nil
    n.meta.presidentCitizenId=nil
    n.meta.foundingMode=false
    for _,cl in pairs(state.clients or {}) do
      if common.normalizeSearch(identity(cl))==common.normalizeSearch(n.meta.sovereignAuthorityIdentity or "NexoFr_") then
        cl.nationalRoot=false
        if cl.nationalRole=="president" then cl.nationalRole="citizen" end
      end
    end
    local gaz=publishGazette(n,actor,"sovereign_relinquishment","SOVEREIGN-AUTHORITY",
      "Renonciation volontaire du dirigeant",
      "NexoFr_ a volontairement renonce a la direction souveraine de North Coalition. Une succession peut desormais etre organisee.",
      relinquishSeal,"public")
    noticeAll(ctx,state,n,"Renonciation souveraine enregistree",
      "La direction de North Coalition est desormais vacante a la suite de la renonciation volontaire de NexoFr_.",
      "warning","nc_government","SOVEREIGN-AUTHORITY")
    mutate(ctx,state,actor,"NC_SOVEREIGN_RELINQUISH","SOVEREIGN-AUTHORITY",
      relinquishSeal.." / "..(gaz and gaz.id or ""))
    actor.nationalRoot=false
    return {
      active=false,relinquishedAt=at,relinquishedBy=identity(actor),
      seal=relinquishSeal,gazetteId=gaz and gaz.id or nil
    }
  end

  local access,accessErr=requireAccess(state,actor)
  if not access then return nil,accessErr end

  local netHandled,netData,netErr=network.handle(n,actor,action,p,{
    mutate=function(netAction,objectId,details)
      mutate(ctx,state,actor,netAction,objectId,details)
    end,
    notify=function(row)
      if not ctx or not ctx.pushNotice then return end
      local sent={}
      for _,cl in pairs(state.clients or {}) do
        if cl.clientId and not sent[cl.clientId] and network.visible(cl,row) then
          sent[cl.clientId]=true
          ctx.pushNotice(state,{
            title="Bulletin interne North Coalition",
            body=(row.id or "").." / "..(row.title or ""),
            severity="info",objectType="nc_network_bulletin",objectId=row.id,
            targetClientId=cl.clientId
          })
        end
      end
    end
  })
  if netHandled then
    if netData~=nil then return netData end
    return nil,netErr
  end

  if action=="NC_PORTAL_SEARCH" then
    local q=common.trim(p.query)
    if q=="" then return {} end
    if #q>80 then q=q:sub(1,80) end

    local out={}
    local function add(kind,id,title,meta,rank)
      out[#out+1]={
        kind=kind,id=id,title=title or id,meta=meta or "",rank=rank or 0
      }
    end
    local function append(rows,limit,kindFn,idFn,titleFn,metaFn,rank)
      local count=0
      for _,row in ipairs(rows or {}) do
        add(kindFn(row),idFn(row),titleFn(row),metaFn(row),rank)
        count=count+1
        if count>=(limit or 10) then break end
      end
    end

    append(listLaws(n,{query=q}),15,
      function() return "law" end,
      function(x) return x.id end,
      function(x) return (x.display_reference or x.id).." - "..(x.title or "") end,
      function(x) return (x.category_code or "").." / "..(x.chapter or "").." / "..(x.status or "") end,100)

    append(listGazette(n,{query=q},state,actor),10,
      function() return "gazette" end,
      function(x) return x.id end,
      function(x) return x.title end,
      function(x) return (x.kind or "").." / "..(x.publishedAt or "") end,90)

    local ministries={}
    for _,m in ipairs(listMinistries(n)) do
      local scope=table.concat(m.scope or {}," ")
      if common.contains(m.code,q) or common.contains(m.name,q) or common.contains(scope,q) or
         common.contains(m.holderIdentity,q) then
        ministries[#ministries+1]=m
      end
    end
    append(ministries,10,
      function() return "ministry" end,
      function(x) return x.code end,
      function(x) return x.name end,
      function(x) return x.code.." / "..tostring(x.holderIdentity or "VACANT") end,85)

    append(listBills(n,{query=q}),10,
      function() return "bill" end,
      function(x) return x.id end,
      function(x) return x.title end,
      function(x) return (x.proposalType or "").." / "..(x.stage or "") end,80)

    append(listDecrees(n,{query=q}),10,
      function() return "decree" end,
      function(x) return x.id end,
      function(x) return x.title end,
      function(x) return (x.scope or "").." / "..(x.status or "") end,78)

    append(listNationalSessions(n,{query=q},state,actor),10,
      function() return "session" end,
      function(x) return x.id end,
      function(x) return x.title end,
      function(x) return (x.sessionType or "").." / "..(x.status or "") end,75)

    append(listNationalCases(n,{query=q},state,actor),10,
      function() return "case" end,
      function(x) return x.id end,
      function(x) return x.title end,
      function(x) return (x.caseType or "").." / "..(x.status or "").." / "..(x.visibility or "") end,70)

    append(listCitizens(n,{query=q},canManageCitizens(state,actor)),10,
      function() return "citizen" end,
      function(x) return x.id end,
      function(x) return x.displayName or x.identity end,
      function(x) return x.id.." / "..(x.status or "") end,65)

    local _,networkRows=network.handle(n,actor,"NC_NET_BULLETIN_LIST",{query=q},nil)
    append(networkRows,10,
      function() return "bulletin" end,
      function(x) return x.id end,
      function(x) return x.title end,
      function(x) return (x.audience or "").." / "..(x.status or "") end,88)

    table.sort(out,function(a,b)
      if (a.rank or 0)~=(b.rank or 0) then return (a.rank or 0)>(b.rank or 0) end
      return tostring(a.title)<tostring(b.title)
    end)
    while #out>60 do table.remove(out) end
    for _,row in ipairs(out) do row.rank=nil end
    return out
  end

  if action=="NC_VERIFY_SEAL" then
    local wanted=common.trim(p.seal):upper()
    if wanted=="" then return {valid=false,seal=wanted} end
    local function result(kind,objectId,title,issuedAt,issuedBy,confidential)
      return {
        valid=true,kind=kind,seal=wanted,objectId=objectId,title=title,
        issuedAt=issuedAt,issuedBy=issuedBy,confidential=confidential==true
      }
    end

    if tostring(n.meta.foundingSeal or ""):upper()==wanted then
      return result("founding","NORTH-COALITION","Cloture de la phase fondatrice",n.meta.foundingClosedAt,n.meta.foundingClosedBy,false)
    end

    for _,gaz in pairs(n.gazette or {}) do
      if tostring(gaz.seal or ""):upper()==wanted then
        if gazetteVisibilityAllowed(state,actor,gaz) then
          return result("gazette",gaz.id,gaz.title,gaz.publishedAt,gaz.publishedBy,false)
        end
        return result("gazette_confidential",gaz.id,"Publication officielle restreinte",nil,nil,true)
      end
    end

    for _,cit in pairs(n.citizens or {}) do
      if tostring(cit.seal or ""):upper()==wanted then
        return result("citizen",cit.id,cit.displayName or cit.identity,cit.createdAt,cit.createdBy,false)
      end
      for _,h in ipairs(cit.history or {}) do
        if tostring(h.seal or ""):upper()==wanted then
          return result("citizen_history",cit.id,(cit.displayName or cit.identity).." / modification registre civil",h.at,h.by,false)
        end
      end
    end

    for _,m in pairs(n.ministries or {}) do
      if tostring(m.appointmentSeal or ""):upper()==wanted then
        return result("ministry_appointment",m.code,m.name.." / "..tostring(m.holderIdentity or ""),m.appointedAt,m.holderIdentity,false)
      end
      for _,h in ipairs(m.history or {}) do
        if tostring(h.seal or ""):upper()==wanted then
          return result("ministry_history",m.code,m.name.." / "..tostring(h.event or ""),h.at,h.by or h.identity,false)
        end
      end
    end

    for _,e in pairs(n.generalElections or {}) do
      if tostring(e.seal or ""):upper()==wanted then return result("general_election",e.id,e.title,e.createdAt,e.createdBy,false) end
      if tostring(e.candidacySeal or ""):upper()==wanted then return result("general_election_candidacy",e.id,e.title,e.candidacyOpenedAt,e.candidacyOpenedBy,false) end
      if tostring(e.voteOpenSeal or ""):upper()==wanted then return result("general_election_vote_open",e.id,e.title,e.voteOpenedAt,e.voteOpenedBy,false) end
      if tostring(e.runoffOpenSeal or ""):upper()==wanted then return result("general_election_runoff_open",e.id,e.title,e.runoffOpenedAt,e.runoffOpenedBy,false) end
      if tostring(e.resultSeal or ""):upper()==wanted then return result("general_election_result",e.id,e.title,e.runoffClosedAt or e.voteClosedAt,e.closedBy or e.runoffOpenedBy,false) end
      if tostring(e.cancelSeal or ""):upper()==wanted then return result("general_election_cancel",e.id,e.title,e.cancelledAt,e.cancelledBy,false) end
    end

    for _,m in pairs(n.mandates or {}) do
      if tostring(m.seal or ""):upper()==wanted then return result("national_mandate",m.id,(m.identity or m.citizenId).." / "..tostring(m.office or ""),m.startedAt,m.identity,false) end
      if tostring(m.endSeal or ""):upper()==wanted then return result("national_mandate_end",m.id,(m.identity or m.citizenId).." / fin de mandat",m.endedAt,m.endedBy,false) end
    end

    for _,e in pairs(n.elections or {}) do
      if tostring(e.openSeal or ""):upper()==wanted then return result("election_open",e.id,e.title,e.openedAt,e.openedBy,false) end
      if tostring(e.resultSeal or ""):upper()==wanted then return result("election_result",e.id,e.title,e.closedAt,e.closedBy,false) end
      if tostring(e.appointmentSeal or ""):upper()==wanted then return result("election_appointment",e.id,e.title,e.closedAt,e.winnerIdentity,false) end
    end

    for _,b in pairs(n.bills or {}) do
      if tostring(b.openSeal or ""):upper()==wanted then return result("bill_vote_open",b.id,b.title,b.openedAt,b.openedBy,false) end
      if tostring(b.resultSeal or ""):upper()==wanted then return result("bill_result",b.id,b.title,b.closedAt,b.closedBy,false) end
      if tostring(b.enactmentSeal or ""):upper()==wanted then return result("law_enactment",b.id,b.title,b.enactedAt,b.enactedBy,false) end
    end

    for _,d in pairs(n.decrees or {}) do
      if tostring(d.seal or ""):upper()==wanted then return result("decree",d.id,d.title,d.publishedAt,d.publishedBy,false) end
      if tostring(d.repealSeal or ""):upper()==wanted then return result("decree_repeal",d.id,d.title,d.repealedAt,d.repealedBy,false) end
    end

    for _,sess in pairs(n.sessions or {}) do
      if canViewNationalSession(state,actor,sess) then
        if tostring(sess.convocationSeal or ""):upper()==wanted then return result("session_convocation",sess.id,sess.title,sess.createdAt,sess.createdBy,false) end
        if tostring(sess.openSeal or ""):upper()==wanted then return result("session_open",sess.id,sess.title,sess.openedAt,sess.openedBy,false) end
        if tostring(sess.closeSeal or ""):upper()==wanted then return result("session_close",sess.id,sess.title,sess.closedAt,sess.closedBy,false) end
        if tostring(sess.cancelSeal or ""):upper()==wanted then return result("session_cancel",sess.id,sess.title,sess.cancelledAt,sess.cancelledBy,false) end
      else
        for _,sealValue in ipairs({sess.convocationSeal,sess.openSeal,sess.closeSeal,sess.cancelSeal}) do
          if tostring(sealValue or ""):upper()==wanted then
            return result("session_confidential",sess.id,"Session nationale restreinte",nil,nil,true)
          end
        end
      end
    end

    for _,case in pairs(n.cases or {}) do
      ensureNationalCaseShape(case)
      local visible=canViewNationalCase(state,actor,case)
      local function caseResult(kind,title,at,by)
        if visible then return result(kind,case.id,title,at,by,false) end
        return result(kind,case.id,"Dossier judiciaire national confidentiel",nil,nil,true)
      end
      if tostring(case.seal or ""):upper()==wanted then return caseResult("case",case.title,case.createdAt,case.createdBy) end
      for _,x in ipairs(case.facts or {}) do if tostring(x.seal or ""):upper()==wanted then return caseResult("case_fact",(x.id or "").." / fait",x.at,x.by) end end
      for _,x in ipairs(case.evidence or {}) do if tostring(x.seal or ""):upper()==wanted then return caseResult("case_evidence",(x.id or "").." / "..(x.label or "preuve"),x.at,x.by) end end
      for _,x in ipairs(case.hearings or {}) do
        if tostring(x.seal or ""):upper()==wanted then return caseResult("hearing",x.id or "Audience",x.createdAt,x.createdBy) end
        if tostring(x.recordSeal or ""):upper()==wanted then return caseResult("hearing_record",(x.id or "Audience").." / PV",x.recordedAt,x.recordedBy) end
      end
      for _,x in ipairs(case.orders or {}) do
        if tostring(x.seal or ""):upper()==wanted then return caseResult("judicial_order",(x.id or "").." / "..(x.orderType or ""),x.issuedAt,x.issuedBy) end
        if tostring(x.statusSeal or ""):upper()==wanted then return caseResult("judicial_order_status",(x.id or "").." / statut",x.updatedAt,x.updatedBy) end
      end
      for _,x in ipairs(case.judgments or {}) do
        if tostring(x.seal or ""):upper()==wanted then return caseResult("judgment",(x.id or "").." / "..(x.verdict or ""),x.date,x.judge) end
      end
      for _,x in ipairs(case.appeals or {}) do
        if tostring(x.seal or ""):upper()==wanted then return caseResult("appeal",x.id or "Appel",x.filedAt,x.filedBy) end
        if tostring(x.decisionSeal or ""):upper()==wanted then return caseResult("appeal_decision",(x.id or "Appel").." / "..(x.result or ""),x.decidedAt,x.decidedBy) end
      end
    end

    local svc=services.verifySeal(n,wanted)
    if svc then
      return result(svc.kind,svc.objectId,svc.title,svc.issuedAt,svc.issuedBy,false)
    end

    local fin=finance.findSeal(n,wanted)
    if fin then
      return result(fin.kind,fin.objectId,fin.title,fin.issuedAt,fin.issuedBy,false)
    end

    local net=network.findSeal(n,wanted)
    if net then
      local row=n.network and n.network.bulletins and n.network.bulletins[net.objectId]
      if row and network.visible(actor,row) then
        return result(net.kind,net.objectId,net.title,net.issuedAt,net.issuedBy,false)
      end
      return result(net.kind.."_confidential",net.objectId,"Bulletin interne restreint",nil,nil,true)
    end

    return {valid=false,seal=wanted}
  end

  if action=="NC_NOTICE_LIST" then
    return listNationalNotices(ctx,state,actor,p)
  end

  if action=="NC_DASHBOARD" then
    local total,active,draft,repealed=0,0,0,0
    for _,law in pairs(n.laws) do
      total=total+1
      if law.status=="active" then active=active+1 elseif law.status=="repealed" then repealed=repealed+1 else draft=draft+1 end
    end
    local ministriesTotal,filled=0,0
    for _,m in pairs(n.ministries) do ministriesTotal=ministriesTotal+1;if m.holderClientId then filled=filled+1 end end
    local citizens,activeCitizens=0,0
    for _,cit in pairs(n.citizens or {}) do
      citizens=citizens+1
      if cit.status=="citizen" then activeCitizens=activeCitizens+1 end
    end
    local openElections=0
    for _,e in pairs(n.elections) do if e.stage=="open" then openElections=openElections+1 end end
    local nationalElections=0
    for _,e in pairs(n.generalElections or {}) do
      if e.stage=="candidacy" or e.stage=="voting" or e.stage=="runoff_ready" or e.stage=="runoff_voting" then nationalElections=nationalElections+1 end
    end
    local activeMandates=0
    for _,m in pairs(n.mandates or {}) do if m.status=="active" then activeMandates=activeMandates+1 end end
    local votingBills=0
    for _,b in pairs(n.bills) do if b.stage=="voting" then votingBills=votingBills+1 end end
    local publishedDecrees=0
    for _,d in pairs(n.decrees) do if d.status=="published" then publishedDecrees=publishedDecrees+1 end end
    local openCases=0
    for _,case in pairs(n.cases or {}) do
      if case.status~="closed" and case.status~="archived" then openCases=openCases+1 end
    end
    local openSessions,scheduledSessions=0,0
    for _,sess in pairs(n.sessions or {}) do
      if sess.status=="open" then openSessions=openSessions+1
      elseif sess.status=="scheduled" then scheduledSessions=scheduledSessions+1 end
    end
    local pendingRequests=0
    for _,req in pairs(n.requests or {}) do
      if req.status=="submitted" or req.status=="in_review" then pendingRequests=pendingRequests+1 end
    end
    local unreadNational=0
    for _,row in ipairs(listNationalNotices(ctx,state,actor,{unreadOnly=true})) do if not row.read then unreadNational=unreadNational+1 end end
    local finSummary=finance.summary(n)
    return {
      laws=total,activeLaws=active,draftLaws=draft,repealedLaws=repealed,
      categories=#(n.categories or {}),ministries=ministriesTotal,filledMinistries=filled,
      citizens=citizens,activeCitizens=activeCitizens,
      openElections=openElections,nationalElections=nationalElections,activeMandates=activeMandates,
      councilSeats=#(n.councilMembers or {}),votingBills=votingBills,publishedDecrees=publishedDecrees,
      openCases=openCases,openSessions=openSessions,scheduledSessions=scheduledSessions,
      pendingRequests=pendingRequests,unreadNotices=unreadNational,
      treasuryBalanceUB=finSummary.balanceUB,treasuryUnit=finSummary.unit,
      currentBudgetId=finSummary.currentBudgetId,pendingExpenses=finSummary.pendingExpenses,
      foundingMode=n.meta.foundingMode,presidentIdentity=n.meta.presidentIdentity,
      nationalRole=nationalRole(state,actor),nationalIdentity=identity(actor),ministryCode=actor.ministryCode,
      sovereignAuthority=actor and actor.nationalRoot==true or false,
      sovereignAuthorityIdentity=n.meta.sovereignAuthorityIdentity,
      sovereignAuthorityActive=n.meta.sovereignAuthorityActive~=false,
      sovereignAuthorityTenure=n.meta.sovereignAuthorityTenure,
      ratifiedAt=n.meta.ratifiedAt
    }
  end

  if action=="NC_CATEGORY_LIST" then return categoryRows(n) end
  if action=="NC_LAW_LIST" then return listLaws(n,p) end
  if action=="NC_LAW_GET" then
    local law=getLaw(n,p.ref or p.id)
    if not law then return nil,"Article national introuvable." end
    return lawView(n,law)
  end

  if action=="NC_CITIZEN_LIST" then
    return listCitizens(n,p,canManageCitizens(state,actor))
  end

  if action=="NC_CITIZEN_GET" then
    local id=common.trim(p.id):upper()
    local cit=n.citizens[id] or findCitizenByIdentity(n,p.id)
    if not cit then return nil,"Citoyen introuvable." end
    return citizenView(cit,canManageCitizens(state,actor) or cit.id==actor.citizenId)
  end

  if action=="NC_CITIZEN_CREATE" then
    if not canManageCitizens(state,actor) then return nil,"Registre civil reserve a la Presidence, l'administration racine ou au Ministere de l'Interieur." end
    local status=common.trim(p.status)
    local valid={citizen=true,resident=true,suspended=true,deceased=true}
    if not valid[status] then status="citizen" end
    local cit,err,created=createCitizen(n,p.identity,status,identity(actor),p.notes)
    if not cit then return nil,err end
    if not created then return nil,"Cette identite existe deja sous "..cit.id.."." end
    cit.displayName=common.trim(p.displayName)~="" and common.safeName(p.displayName) or cit.identity
    cit.updatedAt=common.now()
    noticeAll(ctx,state,n,"Nouvelle identite au registre civil",
      cit.id.." / "..cit.displayName.." / "..cit.status,
      "info","nc_citizen",cit.id)
    mutate(ctx,state,actor,"NC_CITIZEN_CREATE",cit.id,cit.displayName.." / "..cit.status)
    return copy(cit)
  end

  if action=="NC_CITIZEN_UPDATE" then
    if not canManageCitizens(state,actor) then return nil,"Modification du registre civil non autorisee." end
    local cit=n.citizens[common.trim(p.id):upper()]
    if not cit then return nil,"Citoyen introuvable." end
    local newIdentity=p.identity~=nil and common.safeName(p.identity) or cit.identity
    if newIdentity=="" then return nil,"Identite vide interdite." end
    local duplicate=findCitizenByIdentity(n,newIdentity)
    if duplicate and duplicate.id~=cit.id then return nil,"Cette identite appartient deja a "..duplicate.id.."." end

    local valid={citizen=true,resident=true,suspended=true,deceased=true}
    local newStatus=(p.status~=nil and valid[p.status]) and p.status or cit.status

    if newStatus~="citizen" and cit.status=="citizen" then
      for _,cl in pairs(state.clients or {}) do
        if cl.citizenId==cit.id then
          if cl.clientId==n.meta.presidentClientId then return nil,"Transferez la Presidence avant de retirer le statut citoyen du President." end
          if cl.ministryCode and cl.ministryCode~="" then return nil,"Retirez d'abord le portefeuille ministeriel lie a cette identite." end
        end
      end
    end

    local old={identity=cit.identity,displayName=cit.displayName,status=cit.status,notes=cit.notes}
    cit.identity=newIdentity
    if p.displayName~=nil then cit.displayName=common.trim(p.displayName)~="" and common.safeName(p.displayName) or newIdentity end
    if p.notes~=nil then cit.notes=common.trim(p.notes) end
    cit.status=newStatus
    cit.updatedAt=common.now();cit.updatedBy=identity(actor)
    cit.history=cit.history or {}
    local hist={
      at=cit.updatedAt,by=cit.updatedBy,old=old,
      new={identity=cit.identity,displayName=cit.displayName,status=cit.status,notes=cit.notes}
    }
    hist.seal=seal("NC-CIT-HIST",{cit.id,hist.at,hist.by,hist.old,hist.new,cit.seal})
    cit.history[#cit.history+1]=hist

    for _,cl in pairs(state.clients or {}) do
      if cl.citizenId==cit.id then
        cl.nationalIdentity=cit.identity
        if cit.status~="citizen" and cl.nationalRole and cl.nationalRole~="public" then cl.nationalRole="public" end
        if cl.clientId==n.meta.presidentClientId then n.meta.presidentIdentity=cit.identity end
      end
    end
    for _,m in pairs(n.ministries or {}) do
      if m.holderClientId then
        local cl=state.clients[m.holderClientId]
        if cl and cl.citizenId==cit.id then m.holderIdentity=cit.identity end
      end
    end

    noticeAll(ctx,state,n,"Registre civil mis a jour",
      cit.id.." / "..cit.displayName.." / "..cit.status,
      cit.status=="suspended" and "warning" or "info","nc_citizen",cit.id)
    mutate(ctx,state,actor,"NC_CITIZEN_UPDATE",cit.id,old.status.." -> "..cit.status.." / "..cit.identity)
    return copy(cit)
  end

  if action=="NC_CITIZEN_LINK_CLIENT" then
    if not canManageCitizens(state,actor) then return nil,"Rattachement de terminal non autorise." end
    local cit=n.citizens[common.trim(p.citizenId):upper()]
    if not cit then return nil,"Identite citoyenne introuvable." end
    local cl=state.clients[common.trim(p.clientId)]
    if not cl then return nil,"Terminal introuvable." end
    if cl.clientId==n.meta.presidentClientId and cit.id~=cl.citizenId then return nil,"Le terminal presidentiel ne peut pas etre rattache a une autre identite sans transfert de Presidence." end
    if (cl.nationalRole=="minister" or cl.ministryCode) and cit.status~="citizen" then return nil,"Un titulaire de fonction doit etre rattache a un citoyen actif." end
    cl.citizenId=cit.id
    cl.nationalIdentity=cit.identity
    cl.stateId=n.meta.stateId
    if not cl.nationalRole then cl.nationalRole=(cit.status=="citizen") and "citizen" or "public" end
    if cit.status~="citizen" and cl.nationalRole~="public" then return nil,"Cette identite n'est pas un citoyen actif." end
    mutate(ctx,state,actor,"NC_CITIZEN_LINK_CLIENT",cit.id,cl.clientId.." / "..cl.label)
    return {citizen=copy(cit),client=copy(cl)}
  end

  if action=="NC_GAZETTE_LIST" then
    return listGazette(n,p,state,actor)
  end

  if action=="NC_GAZETTE_GET" then
    local row=n.gazette[common.trim(p.id):upper()]
    if not row then return nil,"Publication du Journal officiel introuvable." end
    if not gazetteVisibilityAllowed(state,actor,row) then return nil,"Acces refuse a cette publication." end
    return copy(row)
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
    if not (isPresident(state,actor) or canManageCitizens(state,actor)) then return nil,"Acces au registre des terminaux refuse." end
    local out={}
    for _,cl in pairs(state.clients or {}) do
      out[#out+1]={
        clientId=cl.clientId,computerId=cl.computerId,label=cl.label,role=cl.role,
        stateId=cl.stateId,nationalRole=nationalRole(state,cl),storedNationalRole=cl.nationalRole,
        nationalIdentity=identity(cl),citizenId=cl.citizenId,ministryCode=cl.ministryCode
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
    local valid={citizen=true,council=true,judge=true,prosecutor=true,police=true,civil_servant=true}
    if actor.role=="admin" then valid.president=true;valid.public=true end
    if wanted~="" and not valid[wanted] then
      if wanted=="minister" then return nil,"Un ministre doit etre installe par le registre ministeriel, pas par un changement manuel de role." end
      return nil,"Role national invalide."
    end
    if target.ministryCode and target.ministryCode~="" and wanted~="minister" then
      return nil,"Ce terminal detient un ministere. Retirez d'abord le titulaire via le registre gouvernemental."
    end
    if target.clientId==n.meta.presidentClientId and wanted~="president" then
      return nil,"Le terminal presidentiel ne peut pas etre degrade directement. Transferez d'abord la Presidence depuis un terminal administrateur."
    end
    target.nationalRole=(wanted~="" and wanted or nil)
    target.nationalIdentity=common.trim(p.identity)~="" and common.safeName(p.identity) or (target.nationalIdentity or target.label)
    if target.nationalRole then
      target.stateId=n.meta.stateId
      if target.nationalRole~="public" then
        local citizen,er=createCitizen(n,target.nationalIdentity,"citizen",identity(actor),"Enregistrement automatique lors de l'attribution d'une fonction nationale")
        if not citizen then return nil,er end
        if citizen.status~="citizen" then return nil,"Cette identite n'a pas le statut de citoyen actif." end
        target.citizenId=citizen.id
      end
    end
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
    noticeAll(ctx,state,n,"Fin de la phase fondatrice",
      "Les regles ordinaires de nomination, delais et scrutins sont maintenant applicables.",
      "warning","nc_government","FOUNDING")
    local gaz=publishGazette(n,actor,"founding","NORTH-COALITION",
      "Cloture de la phase fondatrice",
      "Passage au regime ordinaire de nomination, de scrutin et de fonctionnement institutionnel.",
      n.meta.foundingSeal,"public")
    n.meta.foundingGazetteId=gaz.id
    mutate(ctx,state,actor,"NC_FOUNDING_CLOSE","NORTH-COALITION",n.meta.foundingSeal.." / "..gaz.id)
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
    noticeAll(ctx,state,n,"Portefeuille ministeriel vacant",
      m.name.." : fin de fonction de "..tostring(oldIdentity)..". Motif: "..reason,
      "warning","nc_ministry",m.code)
    notice(ctx,state,{title="Fin de fonction ministerielle",body=m.name.." / "..reason,
      severity="warning",objectType="nc_ministry",objectId=m.code,targetClientId=oldId})
    local gaz=publishGazette(n,actor,"ministry_end",m.code,
      "Fin de fonction - "..m.name,
      tostring(oldIdentity).." quitte ses fonctions. Motif: "..reason,
      row.seal,"internal")
    row.gazetteId=gaz.id
    mutate(ctx,state,actor,"NC_MINISTER_REMOVE",m.code,oldIdentity.." / "..reason.." / "..gaz.id)
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
    noticeAll(ctx,state,n,"Procedure ministerielle creee",
      e.title.." / "..ministry.name.." / corps electoral: "..electorate,
      "info","nc_election",id)
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
    if not isNationalMember(state,target) or not isVotingCitizen(n,target) then return nil,"Le candidat doit etre un citoyen national enregistre et actif." end
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
    noticeEligible(ctx,state,e,"Vote ministeriel ouvert",
      e.title.." / "..e.ministryCode.." : votre identite appartient au corps electoral.",
      "warning","nc_election",e.id)
    mutate(ctx,state,actor,"NC_ELECTION_OPEN",e.id,e.openSeal)
    local out=copy(e);out.tally=electionTally(e);return out
  end

  if action=="NC_ELECTION_VOTE" then
    local e=n.elections[common.trim(p.id):upper()]
    if not e then return nil,"Scrutin introuvable." end
    if e.stage~="open" then return nil,"Scrutin ferme." end
    local who=votingKey(n,actor)
    if not who or not isEligible(who,e.eligibleIdentities) then return nil,"Vous ne faites pas partie du corps electoral de ce scrutin." end
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
    noticeAll(ctx,state,n,"Resultat du scrutin "..e.id,
      e.result=="elected" and ("Candidat elu: "..tostring(e.winnerIdentity or e.winnerClientId)) or ("Scrutin non concluant: "..tostring(e.result)),
      e.result=="elected" and "success" or "warning","nc_election",e.id)
    local gaz=publishGazette(n,actor,"election_result",e.id,
      "Resultat du scrutin ministeriel "..e.id,
      e.result=="elected" and ("Elu: "..tostring(e.winnerIdentity or e.winnerClientId).." / "..e.ministryCode)
        or ("Scrutin non concluant: "..tostring(e.result).." / "..e.ministryCode),
      e.resultSeal,"internal")
    e.gazetteId=gaz.id
    if e.stage=="elected" then
      local target=state.clients[e.winnerClientId]
      if not target then return nil,"Candidat elu introuvable au moment de la nomination." end
      nationalAudit(state,actor,"NC_ELECTION_CLOSE",e.id,e.result.." / "..e.resultSeal.." / "..gaz.id)
      local appointed,err=appointMinister(state,n,ctx,actor,ministry,target,"elected",e.id,"Election reguliere")
      if not appointed then return nil,err end
      e.appointmentSeal=appointed.appointmentSeal
      -- appointMinister already persisted, but the election fields above are part of the same state table.
      return {election=copy(e),ministry=appointed,tally=tally}
    end
    mutate(ctx,state,actor,"NC_ELECTION_CLOSE",e.id,e.result.." / "..e.resultSeal.." / "..gaz.id)
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
    noticeAll(ctx,state,n,"Nouveau projet de loi",
      b.id.." / "..b.title.." / "..b.proposalType,
      "info","nc_bill",b.id)
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
    noticeEligible(ctx,state,b,"Vote legislatif ouvert",
      b.id.." / "..b.title.." : votre identite appartient au corps electoral.",
      "warning","nc_bill",b.id)
    mutate(ctx,state,actor,"NC_BILL_OPEN",b.id,b.openSeal)
    local out=copy(b);out.tally=billTally(b);return out
  end

  if action=="NC_BILL_VOTE" then
    local b=n.bills[common.trim(p.id):upper()]
    if not b then return nil,"Projet introuvable." end
    if b.stage~="voting" then return nil,"Vote ferme." end
    local who=votingKey(n,actor)
    if not who or not isEligible(who,b.eligibleIdentities) then return nil,"Vous ne faites pas partie du corps electoral." end
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
    noticeAll(ctx,state,n,"Resultat legislatif "..b.id,
      b.title.." : "..string.upper(tostring(b.result or "inconnu")),
      b.result=="adopted" and "success" or "warning","nc_bill",b.id)
    mutate(ctx,state,actor,"NC_BILL_CLOSE",b.id,b.result.." / "..b.resultSeal)
    local out=copy(b);out.tally=tally;return out
  end

  if action=="NC_BILL_ENACT" then
    if not isPresident(state,actor) then return nil,"La promulgation est reservee a la Presidence." end
    local b=n.bills[common.trim(p.id):upper()]
    if not b then return nil,"Projet introuvable." end
    if b.stage~="adopted" then
      if actor.nationalRoot==true and
        (b.stage=="draft" or b.stage=="debate" or b.stage=="no_quorum" or b.stage=="rejected") then
        b.stage="adopted"
        b.result="sovereign_adoption"
        b.closedAt=common.now()
        b.closedBy=identity(actor)
        b.resultSeal=seal("NC-BILL-SOVEREIGN",{b.id,b.proposalType,b.closedAt,b.closedBy,b.proposedTitle,b.proposedText,b.targetRef,b.targetRefs})
        noticeAll(ctx,state,n,"Adoption souveraine "..b.id,
          b.title.." adopte directement par "..b.closedBy..".",
          "success","nc_bill",b.id)
        mutate(ctx,state,actor,"NC_BILL_SOVEREIGN_ADOPT",b.id,b.resultSeal)
      else
        return nil,"Le projet doit etre adopte avant promulgation."
      end
    end
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
    noticeAll(ctx,state,n,"Promulgation nationale",
      b.id.." promulgue par "..b.enactedBy.." / articles: "..table.concat(enacted,", "),
      "success","nc_bill",b.id)
    local gaz=publishGazette(n,actor,"law_enactment",b.id,
      "Promulgation - "..b.title,
      "Articles concernes: "..table.concat(enacted,", ")..".",
      b.enactmentSeal,"public")
    b.gazetteId=gaz.id
    mutate(ctx,state,actor,"NC_BILL_ENACT",b.id,table.concat(enacted,",").." / "..b.enactmentSeal.." / "..gaz.id)
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
    noticeAll(ctx,state,n,"Decret publie",
      d.id.." / "..d.title..(d.ministryCode~="" and (" / "..d.ministryCode) or ""),
      "info","nc_decree",d.id)
    local gaz=publishGazette(n,actor,"decree",d.id,
      "Decret - "..d.title,
      (d.scope=="ministry" and ("Acte du "..d.ministryCode..".") or "Acte de portee nationale.")..
        (d.legalBasis~="" and (" Base legale: "..d.legalBasis..".") or ""),
      d.seal,"public")
    d.gazetteId=gaz.id
    mutate(ctx,state,actor,"NC_DECREE_PUBLISH",d.id,d.seal.." / "..gaz.id)
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
    noticeAll(ctx,state,n,"Decret abroge",
      d.id.." / "..d.title.." / "..reason,
      "warning","nc_decree",d.id)
    local gaz=publishGazette(n,actor,"decree_repeal",d.id,
      "Abrogation - "..d.title,
      "Motif: "..reason,
      d.repealSeal,"public")
    d.repealGazetteId=gaz.id
    mutate(ctx,state,actor,"NC_DECREE_REPEAL",d.id,reason.." / "..d.repealSeal.." / "..gaz.id)
    return copy(d)
  end

  if action=="NC_SESSION_LIST" then
    return listNationalSessions(n,p,state,actor)
  end

  if action=="NC_SESSION_GET" then
    local sess=n.sessions[common.trim(p.id):upper()]
    if not sess then return nil,"Session nationale introuvable." end
    if not canViewNationalSession(state,actor,sess) then return nil,"Acces refuse a cette session." end
    return copy(sess)
  end

  if action=="NC_SESSION_CREATE" then
    if not nationalSessionManager(state,actor) then return nil,"Creation de session reservee a la Presidence ou au Conseil." end
    local title=common.trim(p.title)
    if title=="" then return nil,"Titre de session obligatoire." end
    local validTypes={council=true,cabinet=true,emergency=true,committee=true,public_hearing=true}
    local sessionType=validTypes[p.sessionType] and p.sessionType or "council"
    local visibility=(p.visibility=="public" or p.visibility=="restricted") and p.visibility or "internal"
    local id=nextId(n.sessionCounters,"NC-SESSION")
    local sess={
      id=id,title=title,sessionType=sessionType,status="scheduled",visibility=visibility,
      scheduledFor=common.trim(p.scheduledFor),location=common.trim(p.location),
      description=common.trim(p.description),agenda={},attendance={},
      createdAt=common.now(),createdBy=identity(actor),updatedAt=common.now()
    }
    sess.convocationSeal=seal("NC-SESSION",{sess.id,sess.title,sess.sessionType,sess.scheduledFor,sess.location,sess.description,sess.visibility,sess.createdAt,sess.createdBy})
    n.sessions[id]=sess
    noticeAll(ctx,state,n,"Session nationale convoquee",
      id.." / "..title.." / "..(sess.scheduledFor~="" and sess.scheduledFor or "horaire a confirmer"),
      sessionType=="emergency" and "warning" or "info","nc_session",id)
    mutate(ctx,state,actor,"NC_SESSION_CREATE",id,title.." / "..sessionType)
    return copy(sess)
  end

  if action=="NC_SESSION_ADD_AGENDA" then
    if not nationalSessionManager(state,actor) then return nil,"Ordre du jour reserve a la Presidence ou au Conseil." end
    local sess=n.sessions[common.trim(p.id):upper()]
    if not sess then return nil,"Session introuvable." end
    if sess.status~="scheduled" then return nil,"L'ordre du jour est verrouille apres ouverture." end
    local valid={law=true,bill=true,election=true,decree=true,case=true,ministry=true,citizen=true,custom=true}
    local kind=valid[p.kind] and p.kind or nil
    if not kind then return nil,"Type de point invalide." end
    local ref=common.trim(p.ref)
    local title=agendaObjectTitle(n,state,actor,kind,ref)
    if not title then return nil,"Objet d'ordre du jour introuvable ou inaccessible." end
    local row={
      id=string.format("ITEM-%03d",#sess.agenda+1),kind=kind,ref=ref,
      title=common.trim(p.title)~="" and common.trim(p.title) or title,
      notes=common.trim(p.notes),status="pending",addedAt=common.now(),addedBy=identity(actor)
    }
    sess.agenda[#sess.agenda+1]=row
    sess.updatedAt=common.now()
    mutate(ctx,state,actor,"NC_SESSION_ADD_AGENDA",sess.id,row.id.." / "..kind.." / "..ref)
    return copy(sess)
  end

  if action=="NC_SESSION_REMOVE_AGENDA" then
    if not nationalSessionManager(state,actor) then return nil,"Modification de l'ordre du jour non autorisee." end
    local sess=n.sessions[common.trim(p.id):upper()]
    if not sess then return nil,"Session introuvable." end
    if sess.status~="scheduled" then return nil,"Ordre du jour verrouille." end
    local removed=nil
    for i=#sess.agenda,1,-1 do
      if sess.agenda[i].id==p.itemId then removed=table.remove(sess.agenda,i) break end
    end
    if not removed then return nil,"Point introuvable." end
    sess.updatedAt=common.now()
    mutate(ctx,state,actor,"NC_SESSION_REMOVE_AGENDA",sess.id,removed.id.." / "..removed.title)
    return copy(sess)
  end

  if action=="NC_SESSION_OPEN" then
    if not nationalSessionManager(state,actor) then return nil,"Ouverture reservee a la Presidence ou au Conseil." end
    local sess=n.sessions[common.trim(p.id):upper()]
    if not sess then return nil,"Session introuvable." end
    if sess.status~="scheduled" then return nil,"Session non ouvrable." end
    sess.status="open";sess.openedAt=common.now();sess.openedBy=identity(actor)
    sess.openSeal=seal("NC-SESSION-OPEN",{sess.id,sess.convocationSeal,sess.openedAt,sess.openedBy,sess.agenda})
    noticeAll(ctx,state,n,"Session nationale ouverte",sess.id.." / "..sess.title,"warning","nc_session",sess.id)
    mutate(ctx,state,actor,"NC_SESSION_OPEN",sess.id,sess.openSeal)
    return copy(sess)
  end

  if action=="NC_SESSION_CHECKIN" then
    local sess=n.sessions[common.trim(p.id):upper()]
    if not sess then return nil,"Session introuvable." end
    if sess.status~="open" then return nil,"La session n'est pas ouverte." end
    if not nationalSessionEligible(n,state,actor,sess) then return nil,"Vous ne faites pas partie des participants autorises." end
    local key=votingKey(n,actor)
    if not key then return nil,"Identite citoyenne active requise." end
    sess.attendance[key]={
      citizenId=key,identity=identity(actor),role=nationalRole(state,actor),
      ministryCode=actor.ministryCode,checkedInAt=common.now(),clientId=actor.clientId
    }
    sess.updatedAt=common.now()
    mutate(ctx,state,actor,"NC_SESSION_CHECKIN",sess.id,key.." / "..identity(actor))
    return copy(sess)
  end

  if action=="NC_SESSION_SET_ITEM_STATUS" then
    if not nationalSessionManager(state,actor) then return nil,"Gestion de seance non autorisee." end
    local sess=n.sessions[common.trim(p.id):upper()]
    if not sess then return nil,"Session introuvable." end
    if sess.status~="open" then return nil,"La session doit etre ouverte." end
    local item=nil
    for _,x in ipairs(sess.agenda or {}) do if x.id==p.itemId then item=x break end end
    if not item then return nil,"Point d'ordre du jour introuvable." end
    local valid={pending=true,discussing=true,discussed=true,voted=true,postponed=true,withdrawn=true}
    if not valid[p.status] then return nil,"Statut de point invalide." end
    local old=item.status
    item.status=p.status
    if p.notes~=nil then item.sessionNotes=common.trim(p.notes) end
    item.updatedAt=common.now();item.updatedBy=identity(actor)
    sess.updatedAt=common.now()
    mutate(ctx,state,actor,"NC_SESSION_SET_ITEM_STATUS",sess.id,item.id.." / "..old.." -> "..item.status)
    return copy(sess)
  end

  if action=="NC_SESSION_CLOSE" then
    if not nationalSessionManager(state,actor) then return nil,"Cloture reservee a la Presidence ou au Conseil." end
    local sess=n.sessions[common.trim(p.id):upper()]
    if not sess then return nil,"Session introuvable." end
    if sess.status~="open" then return nil,"Session non ouverte." end
    local minutes=common.trim(p.minutes)
    local conclusions=common.trim(p.conclusions)
    if minutes=="" then return nil,"Proces-verbal obligatoire." end
    sess.status="closed";sess.minutes=minutes;sess.conclusions=conclusions
    sess.closedAt=common.now();sess.closedBy=identity(actor)
    sess.closeSeal=seal("NC-SESSION-CLOSE",{sess.id,sess.openSeal,sess.attendance,sess.agenda,sess.minutes,sess.conclusions,sess.closedAt,sess.closedBy})
    sess.updatedAt=common.now()
    noticeAll(ctx,state,n,"Session nationale cloturee",sess.id.." / "..sess.title,"info","nc_session",sess.id)
    local gazVisibility=sess.visibility=="public" and "public" or (sess.visibility=="restricted" and "restricted" or "internal")
    local gaz=publishGazette(n,actor,"session_minutes",sess.id,
      "Proces-verbal - "..sess.title,
      common.trim(sess.conclusions)~="" and sess.conclusions or "Session cloturee sans conclusion additionnelle.",
      sess.closeSeal,gazVisibility)
    sess.gazetteId=gaz.id
    mutate(ctx,state,actor,"NC_SESSION_CLOSE",sess.id,sess.closeSeal.." / "..gaz.id)
    return copy(sess)
  end

  if action=="NC_SESSION_CANCEL" then
    if not nationalSessionManager(state,actor) then return nil,"Annulation non autorisee." end
    local sess=n.sessions[common.trim(p.id):upper()]
    if not sess then return nil,"Session introuvable." end
    if sess.status=="closed" or sess.status=="cancelled" then return nil,"Session deja terminee." end
    local reason=common.trim(p.reason)
    if reason=="" then return nil,"Motif d'annulation obligatoire." end
    sess.status="cancelled";sess.cancelReason=reason
    sess.cancelledAt=common.now();sess.cancelledBy=identity(actor)
    sess.cancelSeal=seal("NC-SESSION-CANCEL",{sess.id,reason,sess.cancelledAt,sess.cancelledBy,sess.convocationSeal})
    sess.updatedAt=common.now()
    noticeAll(ctx,state,n,"Session nationale annulee",sess.id.." / "..reason,"warning","nc_session",sess.id)
    mutate(ctx,state,actor,"NC_SESSION_CANCEL",sess.id,reason.." / "..sess.cancelSeal)
    return copy(sess)
  end

  if action=="NC_CASE_LIST" then
    return listNationalCases(n,p,state,actor)
  end

  if action=="NC_CASE_GET" then
    local case=n.cases[common.trim(p.id):upper()]
    if not case then return nil,"Dossier national introuvable." end
    ensureNationalCaseShape(case)
    if not canViewNationalCase(state,actor,case) then return nil,"Acces refuse a ce dossier national." end
    return copy(case)
  end

  if action=="NC_CASE_CREATE" then
    if not nationalCaseInstitutionalRole(state,actor) then return nil,"Creation de dossier reservee a la justice, au parquet ou a la police." end
    local title=common.trim(p.title)
    local summary=common.trim(p.summary)
    if title=="" or summary=="" then return nil,"Titre et resume obligatoires." end
    local validTypes={criminal=true,civil=true,administrative=true,constitutional=true}
    local caseType=validTypes[p.caseType] and p.caseType or "criminal"
    local visibility=(p.visibility=="public" or p.visibility=="sealed") and p.visibility or "restricted"
    local id=nationalCaseId(n)
    local case={
      id=id,title=title,caseType=caseType,status="open",visibility=visibility,
      complainant=common.trim(p.complainant),accused=common.trim(p.accused),
      summary=summary,facts={},evidence={},citedArticles={},hearings={},judgments={},orders={},appeals={},timeline={},
      createdAt=common.now(),createdBy=identity(actor),updatedAt=common.now()
    }
    case.seal=seal("NC-CASE",{case.id,case.title,case.caseType,case.visibility,case.complainant,case.accused,case.summary,case.createdAt,case.createdBy})
    addNationalCaseTimeline(case,"created","Dossier ouvert",case.title,actor)
    n.cases[id]=case
    notifyNationalCase(ctx,state,case,"Dossier national ouvert",id.." / "..title,"info")
    mutate(ctx,state,actor,"NC_CASE_CREATE",id,title.." / "..caseType)
    return copy(case)
  end

  if action=="NC_CASE_ADD_FACT" then
    local case=n.cases[common.trim(p.id):upper()]
    if not case then return nil,"Dossier introuvable." end
    ensureNationalCaseShape(case)
    if not canViewNationalCase(state,actor,case) or not nationalCaseInstitutionalRole(state,actor) then return nil,"Ajout de fait non autorise." end
    local text=common.trim(p.text)
    if text=="" then return nil,"Texte du fait obligatoire." end
    local row={id=string.format("FACT-%03d",#case.facts+1),text=text,at=common.now(),by=identity(actor)}
    row.seal=seal("NC-FACT",{case.id,row.id,row.text,row.at,row.by})
    case.facts[#case.facts+1]=row
    case.updatedAt=common.now()
    addNationalCaseTimeline(case,"fact","Fait ajoute",row.id.." / "..text,actor)
    mutate(ctx,state,actor,"NC_CASE_ADD_FACT",case.id,row.id)
    return copy(case)
  end

  if action=="NC_CASE_ADD_EVIDENCE" then
    local case=n.cases[common.trim(p.id):upper()]
    if not case then return nil,"Dossier introuvable." end
    ensureNationalCaseShape(case)
    if not canViewNationalCase(state,actor,case) or not nationalCaseInstitutionalRole(state,actor) then return nil,"Ajout de preuve non autorise." end
    local label=common.trim(p.label)
    local description=common.trim(p.description)
    if label=="" or description=="" then return nil,"Nom et description de la preuve obligatoires." end
    local row={
      id=string.format("EVID-%03d",#case.evidence+1),label=label,description=description,
      source=common.trim(p.source),at=common.now(),by=identity(actor)
    }
    row.seal=seal("NC-EVID",{case.id,row.id,row.label,row.description,row.source,row.at,row.by})
    case.evidence[#case.evidence+1]=row
    case.updatedAt=common.now()
    addNationalCaseTimeline(case,"evidence","Preuve ajoutee",row.id.." / "..label,actor)
    mutate(ctx,state,actor,"NC_CASE_ADD_EVIDENCE",case.id,row.id)
    return copy(case)
  end

  if action=="NC_CASE_ADD_ARTICLE" then
    local case=n.cases[common.trim(p.id):upper()]
    if not case then return nil,"Dossier introuvable." end
    ensureNationalCaseShape(case)
    if not canViewNationalCase(state,actor,case) or not nationalCaseInstitutionalRole(state,actor) then return nil,"Citation d'article non autorisee." end
    local law=getLaw(n,p.ref)
    if not law then return nil,"Article national introuvable." end
    for _,ref in ipairs(case.citedArticles) do if ref==law.id then return copy(case) end end
    case.citedArticles[#case.citedArticles+1]=law.id
    table.sort(case.citedArticles)
    case.updatedAt=common.now()
    addNationalCaseTimeline(case,"citation","Article cite",(law.display_reference or law.id).." / "..law.title,actor)
    mutate(ctx,state,actor,"NC_CASE_ADD_ARTICLE",case.id,law.id)
    return copy(case)
  end

  if action=="NC_CASE_REMOVE_ARTICLE" then
    local case=n.cases[common.trim(p.id):upper()]
    if not case then return nil,"Dossier introuvable." end
    ensureNationalCaseShape(case)
    if not canViewNationalCase(state,actor,case) or not nationalCaseInstitutionalRole(state,actor) then return nil,"Retrait de citation non autorise." end
    local ref=normalizeRef(p.ref)
    for i=#case.citedArticles,1,-1 do if case.citedArticles[i]==ref then table.remove(case.citedArticles,i) end end
    case.updatedAt=common.now()
    addNationalCaseTimeline(case,"citation_remove","Article retire",ref,actor)
    mutate(ctx,state,actor,"NC_CASE_REMOVE_ARTICLE",case.id,ref)
    return copy(case)
  end

  if action=="NC_CASE_SET_VISIBILITY" then
    local case=n.cases[common.trim(p.id):upper()]
    if not case then return nil,"Dossier introuvable." end
    if not nationalCaseJudicialRole(state,actor) then return nil,"Visibilite reservee aux juges." end
    local allowed={public=true,restricted=true,sealed=true}
    if not allowed[p.visibility] then return nil,"Niveau de visibilite invalide." end
    local old=case.visibility or "restricted"
    case.visibility=p.visibility
    case.updatedAt=common.now()
    addNationalCaseTimeline(case,"visibility","Visibilite modifiee",old.." -> "..p.visibility,actor)
    mutate(ctx,state,actor,"NC_CASE_SET_VISIBILITY",case.id,old.." -> "..p.visibility)
    return copy(case)
  end

  if action=="NC_CASE_SET_STATUS" then
    local case=n.cases[common.trim(p.id):upper()]
    if not case then return nil,"Dossier introuvable." end
    ensureNationalCaseShape(case)
    local r=nationalRole(state,actor)
    local allowedRole=(technicalNationalAdmin(actor) or r=="judge" or r=="prosecutor" or (r=="police" and p.status=="investigation"))
    if not allowedRole then return nil,"Changement de statut non autorise." end
    local transitions={
      open={investigation=true,hearing=true,closed=true},
      investigation={hearing=true,closed=true},
      hearing={judged=true,closed=true},
      judged={appeal=true,closed=true},
      appeal={judged=true,closed=true},
      closed={archived=true},
      archived={}
    }
    if case.status==p.status then return copy(case) end
    if not (transitions[case.status] and transitions[case.status][p.status]) then
      return nil,"Transition interdite: "..tostring(case.status).." -> "..tostring(p.status)
    end
    local old=case.status
    case.status=p.status
    case.updatedAt=common.now()
    addNationalCaseTimeline(case,"status","Statut modifie",old.." -> "..p.status..(common.trim(p.reason)~="" and (" / "..common.trim(p.reason)) or ""),actor)
    notifyNationalCase(ctx,state,case,"Mise a jour dossier "..case.id,old.." -> "..p.status,"info")
    mutate(ctx,state,actor,"NC_CASE_SET_STATUS",case.id,old.." -> "..p.status)
    return copy(case)
  end

  if action=="NC_CASE_ADD_HEARING" then
    local case=n.cases[common.trim(p.id):upper()]
    if not case then return nil,"Dossier introuvable." end
    ensureNationalCaseShape(case)
    if not nationalCaseJudicialRole(state,actor) then return nil,"Audience reservee aux juges." end
    local subject=common.trim(p.subject)
    if subject=="" then return nil,"Objet de l'audience obligatoire." end
    local row={
      id=string.format("HEARING-%03d",#case.hearings+1),subject=subject,
      scheduledFor=common.trim(p.scheduledFor),location=common.trim(p.location),
      status="scheduled",createdAt=common.now(),createdBy=identity(actor)
    }
    row.seal=seal("NC-HEAR",{case.id,row.id,row.subject,row.scheduledFor,row.location,row.createdAt,row.createdBy})
    case.hearings[#case.hearings+1]=row
    if case.status=="open" or case.status=="investigation" then case.status="hearing" end
    case.updatedAt=common.now()
    addNationalCaseTimeline(case,"hearing","Audience planifiee",row.id.." / "..subject.." / "..row.scheduledFor,actor)
    notifyNationalCase(ctx,state,case,"Audience nationale planifiee",case.id.." / "..subject.." / "..row.scheduledFor,"warning")
    mutate(ctx,state,actor,"NC_CASE_ADD_HEARING",case.id,row.id)
    return copy(case)
  end

  if action=="NC_CASE_RECORD_HEARING" then
    local case=n.cases[common.trim(p.id):upper()]
    if not case then return nil,"Dossier introuvable." end
    ensureNationalCaseShape(case)
    if not nationalCaseJudicialRole(state,actor) then return nil,"Proces-verbal reserve aux juges." end
    local hearing=nil
    for _,h in ipairs(case.hearings) do if h.id==p.hearingId then hearing=h break end end
    if not hearing then return nil,"Audience introuvable." end
    local minutes=common.trim(p.minutes)
    if minutes=="" then return nil,"Proces-verbal vide." end
    hearing.minutes=minutes
    hearing.status=p.status=="cancelled" and "cancelled" or "completed"
    hearing.recordedAt=common.now();hearing.recordedBy=identity(actor)
    hearing.recordSeal=seal("NC-HEAR-PV",{case.id,hearing.id,hearing.minutes,hearing.status,hearing.recordedAt,hearing.recordedBy,hearing.seal})
    case.updatedAt=common.now()
    addNationalCaseTimeline(case,"hearing_record","Proces-verbal d'audience",hearing.id.." / "..hearing.status,actor)
    mutate(ctx,state,actor,"NC_CASE_RECORD_HEARING",case.id,hearing.id)
    return copy(case)
  end

  if action=="NC_CASE_ADD_ORDER" then
    local case=n.cases[common.trim(p.id):upper()]
    if not case then return nil,"Dossier introuvable." end
    ensureNationalCaseShape(case)
    if not nationalCaseJudicialRole(state,actor) then return nil,"Ordonnance reservee aux juges." end
    local valid={search=true,seizure=true,arrest=true,release=true,protection=true,injunction=true,other=true}
    local typ=valid[p.orderType] and p.orderType or "other"
    local subject=common.trim(p.subject)
    local grounds=common.trim(p.grounds)
    if subject=="" or grounds=="" then return nil,"Objet et motifs de l'ordonnance obligatoires." end
    local row={
      id=string.format("ORDER-%03d",#case.orders+1),orderType=typ,subject=subject,grounds=grounds,
      status="active",issuedAt=common.now(),issuedBy=identity(actor),expiresAt=common.trim(p.expiresAt)
    }
    row.seal=seal("NC-ORDER",{case.id,row.id,row.orderType,row.subject,row.grounds,row.expiresAt,row.issuedAt,row.issuedBy})
    case.orders[#case.orders+1]=row
    case.updatedAt=common.now()
    addNationalCaseTimeline(case,"order","Ordonnance emise",row.id.." / "..typ.." / "..subject,actor)
    notifyNationalCase(ctx,state,case,"Ordonnance judiciaire",case.id.." / "..row.id.." / "..typ,"warning")
    mutate(ctx,state,actor,"NC_CASE_ADD_ORDER",case.id,row.id)
    return copy(case)
  end

  if action=="NC_CASE_SET_ORDER_STATUS" then
    local case=n.cases[common.trim(p.id):upper()]
    if not case then return nil,"Dossier introuvable." end
    ensureNationalCaseShape(case)
    if not nationalCaseJudicialRole(state,actor) then return nil,"Modification d'ordonnance reservee aux juges." end
    local order=nil
    for _,o in ipairs(case.orders) do if o.id==p.orderId then order=o break end end
    if not order then return nil,"Ordonnance introuvable." end
    local allowed={active=true,executed=true,revoked=true,expired=true}
    if not allowed[p.status] then return nil,"Statut d'ordonnance invalide." end
    local old=order.status
    order.status=p.status;order.updatedAt=common.now();order.updatedBy=identity(actor)
    order.statusSeal=seal("NC-ORDER-STAT",{case.id,order.id,old,order.status,order.updatedAt,order.updatedBy,order.seal})
    case.updatedAt=common.now()
    addNationalCaseTimeline(case,"order_status","Ordonnance mise a jour",order.id.." / "..old.." -> "..order.status,actor)
    mutate(ctx,state,actor,"NC_CASE_SET_ORDER_STATUS",case.id,order.id.." "..old.." -> "..order.status)
    return copy(case)
  end

  if action=="NC_CASE_ADD_JUDGMENT" then
    local case=n.cases[common.trim(p.id):upper()]
    if not case then return nil,"Dossier introuvable." end
    ensureNationalCaseShape(case)
    if not nationalCaseJudicialRole(state,actor) then return nil,"Jugement reserve aux juges." end
    local verdict=common.trim(p.verdict)
    local reasoning=common.trim(p.reasoning)
    if verdict=="" or reasoning=="" then return nil,"Decision et motivation obligatoires." end
    local row={
      id=string.format("JUDG-%03d",#case.judgments+1),verdict=verdict,reasoning=reasoning,
      sanctions=common.trim(p.sanctions),judge=identity(actor),date=common.now(),
      final=p.final~=false,citedArticleVersions=nationalLawSnapshot(n,case.citedArticles)
    }
    row.seal=seal("NC-JUDG",{case.id,row.id,row.verdict,row.reasoning,row.sanctions,row.judge,row.date,row.final,row.citedArticleVersions})
    case.judgments[#case.judgments+1]=row
    if row.final then case.status="judged" end
    case.updatedAt=common.now()
    addNationalCaseTimeline(case,"judgment","Jugement enregistre",row.id.." / "..verdict,actor)
    notifyNationalCase(ctx,state,case,"Jugement national rendu",case.id.." / "..verdict,row.final and "warning" or "info")
    if row.final then
      local visibility=case.visibility=="public" and "public" or "judicial"
      local gaz=publishGazette(n,actor,"judgment",case.id,
        case.visibility=="public" and ("Jugement - "..case.title) or ("Decision judiciaire - "..case.id),
        case.visibility=="public" and verdict or "Decision rendue; contenu reserve au circuit judiciaire.",
        row.seal,visibility)
      row.gazetteId=gaz.id
    end
    mutate(ctx,state,actor,"NC_CASE_ADD_JUDGMENT",case.id,row.id.." / "..row.seal..(row.gazetteId and (" / "..row.gazetteId) or ""))
    return copy(case)
  end

  if action=="NC_CASE_FILE_APPEAL" then
    local case=n.cases[common.trim(p.id):upper()]
    if not case then return nil,"Dossier introuvable." end
    ensureNationalCaseShape(case)
    local who=identity(actor)
    local institution=(technicalNationalAdmin(actor) or nationalRole(state,actor)=="prosecutor" or nationalRole(state,actor)=="judge")
    local party=(who~="" and (who==case.complainant or who==case.accused))
    if not institution and not party then return nil,"Vous n'etes pas habilite a former appel dans ce dossier." end
    if case.status~="judged" and case.status~="closed" then return nil,"L'appel exige une decision rendue." end
    local grounds=common.trim(p.grounds)
    if grounds=="" then return nil,"Motifs d'appel obligatoires." end
    local row={
      id=string.format("APPEAL-%03d",#case.appeals+1),appellant=who,grounds=grounds,
      status="pending",filedAt=common.now(),filedBy=who
    }
    row.seal=seal("NC-APPEAL",{case.id,row.id,row.appellant,row.grounds,row.filedAt})
    case.appeals[#case.appeals+1]=row
    case.status="appeal";case.updatedAt=common.now()
    addNationalCaseTimeline(case,"appeal","Appel depose",row.id.." / "..who,actor)
    notifyNationalCase(ctx,state,case,"Appel depose",case.id.." / "..row.id,"warning")
    mutate(ctx,state,actor,"NC_CASE_FILE_APPEAL",case.id,row.id)
    return copy(case)
  end

  if action=="NC_CASE_DECIDE_APPEAL" then
    local case=n.cases[common.trim(p.id):upper()]
    if not case then return nil,"Dossier introuvable." end
    ensureNationalCaseShape(case)
    if not nationalCaseJudicialRole(state,actor) then return nil,"Decision d'appel reservee aux juges." end
    local appeal=nil
    for _,a in ipairs(case.appeals) do if a.id==p.appealId then appeal=a break end end
    if not appeal then return nil,"Appel introuvable." end
    if appeal.status~="pending" then return nil,"Cet appel est deja tranche." end
    local valid={upheld=true,reversed=true,modified=true,remanded=true,dismissed=true}
    if not valid[p.result] then return nil,"Resultat d'appel invalide." end
    local reasoning=common.trim(p.reasoning)
    if reasoning=="" then return nil,"Motivation d'appel obligatoire." end
    appeal.status="decided";appeal.result=p.result;appeal.reasoning=reasoning
    appeal.decidedAt=common.now();appeal.decidedBy=identity(actor)
    appeal.decisionSeal=seal("NC-APPEAL-DEC",{case.id,appeal.id,appeal.result,appeal.reasoning,appeal.decidedAt,appeal.decidedBy,appeal.seal})
    case.status=(p.result=="remanded") and "hearing" or "judged"
    case.updatedAt=common.now()
    addNationalCaseTimeline(case,"appeal_decision","Appel tranche",appeal.id.." / "..appeal.result,actor)
    notifyNationalCase(ctx,state,case,"Decision d'appel",case.id.." / "..appeal.result,"info")
    local visibility=case.visibility=="public" and "public" or "judicial"
    local gaz=publishGazette(n,actor,"appeal_decision",case.id,
      case.visibility=="public" and ("Decision d'appel - "..case.title) or ("Decision d'appel - "..case.id),
      case.visibility=="public" and appeal.result or "Decision d'appel rendue; contenu reserve au circuit judiciaire.",
      appeal.decisionSeal,visibility)
    appeal.gazetteId=gaz.id
    mutate(ctx,state,actor,"NC_CASE_DECIDE_APPEAL",case.id,appeal.id.." / "..appeal.result.." / "..gaz.id)
    return copy(case)
  end

  do
    local handled,data,err=democracy.handle(state,actor,action,p,{
      mutate=function(a,obj,details) return mutate(ctx,state,actor,a,obj,details) end,
      notice=function(spec) return notice(ctx,state,spec) end,
      gazette=function(kind,objectId,title,summary,sourceSeal,visibility)
        return publishGazette(n,actor,kind,objectId,title,summary,sourceSeal,visibility)
      end
    })
    if handled then return data,err end
  end

  do
    local handled,data,err=finance.handle(state,actor,action,p,{
      getLaw=getLaw,
      mutate=function(a,obj,details) return mutate(ctx,state,actor,a,obj,details) end,
      notice=function(spec) return notice(ctx,state,spec) end,
      gazette=function(kind,objectId,title,summary,sourceSeal,visibility)
        return publishGazette(n,actor,kind,objectId,title,summary,sourceSeal,visibility)
      end
    })
    if handled then return data,err end
  end

  do
    local handled,data,err=services.handle(state,actor,action,p,{
      getLaw=getLaw,
      mutate=function(a,obj,details) return mutate(ctx,state,actor,a,obj,details) end,
      notice=function(spec) return notice(ctx,state,spec) end,
      gazette=function(kind,objectId,title,summary,sourceSeal,visibility)
        return publishGazette(n,actor,kind,objectId,title,summary,sourceSeal,visibility)
      end
    })
    if handled then return data,err end
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
