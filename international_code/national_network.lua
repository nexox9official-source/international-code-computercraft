local common=dofile("/international_code/common.lua")

local N={}

local function copy(v)
  return common.deepcopy(v)
end

local function trim(v)
  return common.trim(v)
end

local function identity(actor)
  return trim(actor and (actor.nationalIdentity or actor.label or actor.clientId) or "")
end

local function role(actor)
  if not actor then return nil end
  if actor.role=="admin" and (not actor.nationalRole or actor.nationalRole=="admin") then return "admin" end
  return actor.nationalRole
end

local function seal(prefix,payload)
  local raw=textutils.serialize(payload,{compact=true}).."|"..tostring(common.nowMs()).."|"..common.randomToken(8)
  return prefix.."-"..common.simpleChecksum(raw):upper()
end

local function yearNow()
  return os.date and os.date("%Y") or "0000"
end

local function nextId(n)
  local y=yearNow()
  n.network.bulletinCounters[y]=(n.network.bulletinCounters[y] or 0)+1
  return string.format("NC-NET-%s-%04d",y,n.network.bulletinCounters[y])
end

function N.ensure(n)
  n.network=n.network or {}
  n.network.bulletins=n.network.bulletins or {}
  n.network.bulletinCounters=n.network.bulletinCounters or {}
  return n.network
end

local function canPublish(actor)
  local r=role(actor)
  return r=="admin" or r=="president" or r=="council" or r=="minister"
end

local function canManage(actor,row)
  if not actor or not row then return false end
  local r=role(actor)
  if r=="admin" or r=="president" then return true end
  if row.createdByClientId and actor.clientId==row.createdByClientId then return true end
  if r=="minister" and row.ministryCode~="" and actor.ministryCode==row.ministryCode then return true end
  return false
end

local function visible(actor,row)
  if not actor or not row then return false end
  local r=role(actor)
  if r=="admin" or r=="president" then return true end
  if row.status=="draft" then return canManage(actor,row) end
  if row.status~="published" and row.status~="archived" then return false end

  local a=row.audience or "citizens"
  if a=="citizens" then return r~=nil end
  if a=="institutions" then
    return r=="council" or r=="minister" or r=="judge" or r=="prosecutor" or
      r=="police" or r=="civil_servant"
  end
  if a=="ministry" then
    return r=="minister" and row.ministryCode~="" and actor.ministryCode==row.ministryCode
  end
  if a=="judicial" then return r=="judge" or r=="prosecutor" end
  if a=="security" then return r=="judge" or r=="prosecutor" or r=="police" end
  return false
end

function N.visible(actor,row)
  return visible(actor,row)
end

local function publicView(row)
  local out=copy(row)
  out.history=nil
  return out
end

local function list(n,actor,p)
  p=p or {}
  local q=trim(p.query)
  local audience=trim(p.audience)
  local status=trim(p.status)
  local out={}
  for _,row in pairs(n.network.bulletins or {}) do
    local hit=q=="" or common.contains(row.id,q) or common.contains(row.title,q) or
      common.contains(row.summary,q) or common.contains(row.body,q) or
      common.contains(row.ministryCode,q) or common.contains(row.authorIdentity,q)
    if hit and (audience=="" or row.audience==audience) and
      (status=="" or row.status==status) and visible(actor,row) then
      out[#out+1]=publicView(row)
    end
  end
  table.sort(out,function(a,b)
    local ar=(a.status=="published" and 3 or a.status=="draft" and 2 or 1)
    local br=(b.status=="published" and 3 or b.status=="draft" and 2 or 1)
    if ar~=br then return ar>br end
    return tostring(a.id)>tostring(b.id)
  end)
  return out
end

local function validateAudience(actor,audience,ministryCode)
  local valid={citizens=true,institutions=true,ministry=true,judicial=true,security=true}
  if not valid[audience] then return nil,"Audience invalide." end
  local r=role(actor)
  if audience=="ministry" then
    if ministryCode=="" then return nil,"Un ministere destinataire est obligatoire." end
    if r=="minister" and actor.ministryCode~=ministryCode then
      return nil,"Un ministre ne peut publier que pour son propre ministere."
    end
  end
  if (audience=="judicial" or audience=="security") and
    not (r=="admin" or r=="president" or r=="council") then
    return nil,"Cette audience restreinte exige une autorite nationale superieure."
  end
  return true
end

function N.handle(n,actor,action,p,ctx)
  N.ensure(n)
  p=p or {}

  if action=="NC_NET_BULLETIN_LIST" then
    return true,list(n,actor,p),nil
  end

  if action=="NC_NET_BULLETIN_GET" then
    local row=n.network.bulletins[trim(p.id):upper()]
    if not row then return true,nil,"Bulletin introuvable." end
    if not visible(actor,row) then return true,nil,"Acces refuse a ce bulletin." end
    return true,copy(row),nil
  end

  if action=="NC_NET_BULLETIN_CREATE" then
    if not canPublish(actor) then return true,nil,"Publication reservee aux autorites institutionnelles." end
    local title=trim(p.title)
    local body=trim(p.body)
    local summary=trim(p.summary)
    if title=="" or body=="" then return true,nil,"Titre et contenu obligatoires." end
    local audience=trim(p.audience)
    local ministryCode=trim(p.ministryCode):upper()
    local ok,err=validateAudience(actor,audience,ministryCode)
    if not ok then return true,nil,err end

    local id=nextId(n)
    local row={
      id=id,title=title,summary=summary,body=body,
      audience=audience,ministryCode=ministryCode,
      status="draft",createdAt=common.now(),createdByClientId=actor.clientId,
      authorIdentity=identity(actor),authorRole=role(actor),history={}
    }
    row.draftSeal=seal("NC-NET-DRAFT",{row.id,row.title,row.summary,row.body,row.audience,row.ministryCode,row.createdAt,row.authorIdentity})
    row.history[#row.history+1]={at=row.createdAt,event="created",by=row.authorIdentity,seal=row.draftSeal}
    n.network.bulletins[id]=row
    if ctx and ctx.mutate then ctx.mutate("NC_NET_BULLETIN_CREATE",id,audience.." / "..ministryCode) end
    return true,copy(row),nil
  end

  if action=="NC_NET_BULLETIN_EDIT" then
    local row=n.network.bulletins[trim(p.id):upper()]
    if not row then return true,nil,"Bulletin introuvable." end
    if row.status~="draft" then return true,nil,"Seul un brouillon peut etre modifie." end
    if not canManage(actor,row) then return true,nil,"Modification non autorisee." end

    local title=p.title~=nil and trim(p.title) or row.title
    local summary=p.summary~=nil and trim(p.summary) or row.summary
    local body=p.body~=nil and trim(p.body) or row.body
    local audience=p.audience~=nil and trim(p.audience) or row.audience
    local ministryCode=p.ministryCode~=nil and trim(p.ministryCode):upper() or row.ministryCode
    if title=="" or body=="" then return true,nil,"Titre et contenu obligatoires." end
    local ok,err=validateAudience(actor,audience,ministryCode)
    if not ok then return true,nil,err end

    row.title=title;row.summary=summary;row.body=body
    row.audience=audience;row.ministryCode=ministryCode
    row.updatedAt=common.now();row.updatedBy=identity(actor)
    local s=seal("NC-NET-EDIT",{row.id,row.title,row.summary,row.body,row.audience,row.ministryCode,row.updatedAt,row.updatedBy,row.draftSeal})
    row.history[#row.history+1]={at=row.updatedAt,event="edited",by=row.updatedBy,seal=s}
    if ctx and ctx.mutate then ctx.mutate("NC_NET_BULLETIN_EDIT",row.id,audience.." / "..ministryCode) end
    return true,copy(row),nil
  end

  if action=="NC_NET_BULLETIN_PUBLISH" then
    local row=n.network.bulletins[trim(p.id):upper()]
    if not row then return true,nil,"Bulletin introuvable." end
    if row.status~="draft" then return true,nil,"Ce bulletin n'est plus un brouillon." end
    if not canManage(actor,row) then return true,nil,"Publication non autorisee." end
    row.status="published";row.publishedAt=common.now();row.publishedBy=identity(actor)
    row.publishSeal=seal("NC-NET-PUB",{row.id,row.title,row.summary,row.body,row.audience,row.ministryCode,row.publishedAt,row.publishedBy,row.draftSeal})
    row.history[#row.history+1]={at=row.publishedAt,event="published",by=row.publishedBy,seal=row.publishSeal}
    if ctx and ctx.notify then ctx.notify(row) end
    if ctx and ctx.mutate then ctx.mutate("NC_NET_BULLETIN_PUBLISH",row.id,row.audience.." / "..row.ministryCode) end
    return true,copy(row),nil
  end

  if action=="NC_NET_BULLETIN_ARCHIVE" then
    local row=n.network.bulletins[trim(p.id):upper()]
    if not row then return true,nil,"Bulletin introuvable." end
    if row.status~="published" then return true,nil,"Seul un bulletin publie peut etre archive." end
    if not canManage(actor,row) then return true,nil,"Archivage non autorise." end
    row.status="archived";row.archivedAt=common.now();row.archivedBy=identity(actor)
    row.archiveSeal=seal("NC-NET-ARCH",{row.id,row.publishSeal,row.archivedAt,row.archivedBy})
    row.history[#row.history+1]={at=row.archivedAt,event="archived",by=row.archivedBy,seal=row.archiveSeal}
    if ctx and ctx.mutate then ctx.mutate("NC_NET_BULLETIN_ARCHIVE",row.id,row.audience.." / "..row.ministryCode) end
    return true,copy(row),nil
  end

  return false,nil,nil
end

function N.findSeal(n,wanted)
  N.ensure(n)
  wanted=trim(wanted):upper()
  for _,row in pairs(n.network.bulletins or {}) do
    if tostring(row.draftSeal or ""):upper()==wanted then
      return {kind="network_bulletin_draft",objectId=row.id,title=row.title,issuedAt=row.createdAt,issuedBy=row.authorIdentity}
    end
    if tostring(row.publishSeal or ""):upper()==wanted then
      return {kind="network_bulletin",objectId=row.id,title=row.title,issuedAt=row.publishedAt,issuedBy=row.publishedBy}
    end
    if tostring(row.archiveSeal or ""):upper()==wanted then
      return {kind="network_bulletin_archive",objectId=row.id,title=row.title,issuedAt=row.archivedAt,issuedBy=row.archivedBy}
    end
    for _,h in ipairs(row.history or {}) do
      if tostring(h.seal or ""):upper()==wanted then
        return {kind="network_bulletin_history",objectId=row.id,title=row.title,issuedAt=h.at,issuedBy=h.by}
      end
    end
  end
  return nil
end

return N
