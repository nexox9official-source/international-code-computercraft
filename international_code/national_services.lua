local common=dofile("/international_code/common.lua")

local S={}

local function copy(v)
  return common.deepcopy(v)
end

local function trim(v)
  return common.trim(v)
end

local function yearNow()
  return os.date and os.date("%Y") or "0000"
end

local function nextYearId(counter,prefix)
  local y=yearNow()
  local n=(counter[y] or 0)+1
  counter[y]=n
  return string.format("%s-%s-%04d",prefix,y,n)
end

local function nextSequential(n,field,prefix)
  local value=tonumber(n[field] or 1) or 1
  n[field]=value+1
  return string.format("%s-%04d",prefix,value)
end

local function seal(prefix,payload)
  local raw=textutils.serialize(payload,{compact=true}).."|"..tostring(common.nowMs()).."|"..common.randomToken(8)
  return prefix.."-"..common.simpleChecksum(raw):upper()
end

local function role(actor)
  return actor and actor.nationalRole or nil
end

local function technicalAdmin(actor)
  return actor and actor.role=="admin" and (not actor.nationalRole or actor.nationalRole=="admin")
end

local function identity(actor)
  return trim(actor and (actor.nationalIdentity or actor.label or actor.clientId) or "")
end

local function ensure(n)
  n.organizations=n.organizations or {}
  n.nextOrganization=tonumber(n.nextOrganization or 1) or 1
  n.licenses=n.licenses or {}
  n.licenseCounters=n.licenseCounters or {}
  n.fines=n.fines or {}
  n.fineCounters=n.fineCounters or {}
end

local function citizen(n,id)
  return n.citizens and n.citizens[trim(id):upper()] or nil
end

local function org(n,id)
  return n.organizations and n.organizations[trim(id):upper()] or nil
end

local function law(n,ctx,ref)
  if ctx and ctx.getLaw then return ctx.getLaw(n,ref) end
  local q=trim(ref):upper()
  return n.laws and n.laws[q] or nil
end

local function isSelfCitizen(actor,citizenId)
  return actor and actor.citizenId and actor.citizenId==citizenId
end

local function canManageOrganizations(actor)
  local r=role(actor)
  return technicalAdmin(actor) or r=="president" or (r=="minister" and actor.ministryCode=="MIN-ECO")
end

local function canManageAnyLicense(actor)
  local r=role(actor)
  return technicalAdmin(actor) or r=="president" or r=="minister"
end

local licenseAuthorities={
  business="MIN-ECO",
  bank="MIN-ECO",
  commerce="MIN-ECO",
  driving="MIN-INF",
  vehicle="MIN-INF",
  construction="MIN-INF",
  transport="MIN-INF",
  security="MIN-INT",
  weapons="MIN-INT",
  border="MIN-INT",
  medical="MIN-SAN",
  health="MIN-SAN",
  cyber="MIN-DIG",
  communications="MIN-DIG",
  hazardous="MIN-ENV",
  environment="MIN-ENV",
  labor="MIN-TRA",
  employment="MIN-TRA",
  defense="MIN-DEF",
  reconstruction="MIN-REC",
  foreign="MIN-EXT",
  generic=nil
}

local function licenseAuthority(kind)
  return licenseAuthorities[trim(kind):lower()]
end

local function canManageLicense(actor,kind)
  if technicalAdmin(actor) or role(actor)=="president" then return true end
  if role(actor)~="minister" then return false end
  local needed=licenseAuthority(kind)
  return needed and actor.ministryCode==needed or false
end

local function canIssueFine(actor)
  local r=role(actor)
  return technicalAdmin(actor) or r=="police" or r=="prosecutor" or r=="judge"
end

local function canResolveFine(actor)
  local r=role(actor)
  return technicalAdmin(actor) or r=="prosecutor" or r=="judge"
end

local function canMarkPaid(actor)
  local r=role(actor)
  return technicalAdmin(actor) or r=="prosecutor" or r=="judge" or
    (r=="minister" and actor.ministryCode=="MIN-ECO")
end

local function canViewCitizenRecord(actor,citizenId)
  local r=role(actor)
  return technicalAdmin(actor) or isSelfCitizen(actor,citizenId) or r=="judge" or r=="prosecutor" or r=="police"
end

local function notifyCitizen(ctx,state,n,citizenId,title,body,severity,objectType,objectId)
  if not ctx or not ctx.notice then return end
  for _,cl in pairs(state.clients or {}) do
    if cl.citizenId==citizenId then
      ctx.notice({
        title=title,body=body,severity=severity or "info",
        objectType=objectType,objectId=objectId,targetClientId=cl.clientId
      })
    end
  end
end

local function listOrganizations(n,p)
  p=p or {}
  local q=trim(p.query)
  local status=trim(p.status)
  local kind=trim(p.kind)
  local out={}
  for _,o in pairs(n.organizations or {}) do
    local hit=q=="" or common.contains(o.id,q) or common.contains(o.name,q) or
      common.contains(o.activity,q) or common.contains(o.registeredAddress,q)
    if hit and (status=="" or o.status==status) and (kind=="" or o.kind==kind) then
      out[#out+1]=copy(o)
    end
  end
  table.sort(out,function(a,b) return tostring(a.id)<tostring(b.id) end)
  return out
end

local function listLicenses(n,p,actor)
  p=p or {}
  local q=trim(p.query)
  local status=trim(p.status)
  local kind=trim(p.kind)
  local holder=trim(p.holderId):upper()
  local out={}
  for _,l in pairs(n.licenses or {}) do
    local visible=true
    if not canManageAnyLicense(actor) and not technicalAdmin(actor) then
      visible=(l.holderType=="citizen" and isSelfCitizen(actor,l.holderId))
    end
    local hit=q=="" or common.contains(l.id,q) or common.contains(l.kind,q) or
      common.contains(l.title,q) or common.contains(l.holderId,q) or common.contains(l.notes,q)
    if visible and hit and (status=="" or l.status==status) and
       (kind=="" or l.kind==kind) and (holder=="" or l.holderId==holder) then
      out[#out+1]=copy(l)
    end
  end
  table.sort(out,function(a,b) return tostring(a.id)>tostring(b.id) end)
  return out
end

local function listFines(n,p,actor)
  p=p or {}
  local q=trim(p.query)
  local status=trim(p.status)
  local target=trim(p.citizenId):upper()
  local out={}
  for _,fine in pairs(n.fines or {}) do
    local visible=canIssueFine(actor) or canResolveFine(actor) or isSelfCitizen(actor,fine.citizenId)
    local hit=q=="" or common.contains(fine.id,q) or common.contains(fine.reason,q) or
      common.contains(fine.citizenId,q) or common.contains(fine.articleRef,q)
    if visible and hit and (status=="" or fine.status==status) and
       (target=="" or fine.citizenId==target) then
      out[#out+1]=copy(fine)
    end
  end
  table.sort(out,function(a,b) return tostring(a.id)>tostring(b.id) end)
  return out
end

local function organizationPublicView(o)
  return {
    id=o.id,name=o.name,kind=o.kind,status=o.status,activity=o.activity,
    registeredAddress=o.registeredAddress,createdAt=o.createdAt,
    registrationSeal=o.registrationSeal
  }
end

local function buildRecord(n,citizenId)
  local cit=citizen(n,citizenId)
  if not cit then return nil,"Citoyen introuvable." end
  local record={
    citizen=copy(cit),licenses={},fines={},organizations={},judgments={}
  }
  record.citizen.notes=nil
  record.citizen.history=nil

  for _,l in pairs(n.licenses or {}) do
    if l.holderType=="citizen" and l.holderId==citizenId then record.licenses[#record.licenses+1]=copy(l) end
  end
  for _,fine in pairs(n.fines or {}) do
    if fine.citizenId==citizenId then record.fines[#record.fines+1]=copy(fine) end
  end
  for _,o in pairs(n.organizations or {}) do
    for _,owner in ipairs(o.owners or {}) do
      if owner.citizenId==citizenId then record.organizations[#record.organizations+1]=organizationPublicView(o) break end
    end
  end

  local identityNorm=common.normalizeSearch(cit.identity or "")
  for _,case in pairs(n.cases or {}) do
    if common.normalizeSearch(case.accused or "")==identityNorm then
      for _,j in ipairs(case.judgments or {}) do
        if j.final then
          record.judgments[#record.judgments+1]={
            caseId=case.id,caseTitle=case.title,judgmentId=j.id,
            verdict=j.verdict,sanctions=j.sanctions,date=j.date,seal=j.seal
          }
        end
      end
    end
  end

  table.sort(record.licenses,function(a,b) return tostring(a.id)>tostring(b.id) end)
  table.sort(record.fines,function(a,b) return tostring(a.id)>tostring(b.id) end)
  table.sort(record.organizations,function(a,b) return tostring(a.id)<tostring(b.id) end)
  table.sort(record.judgments,function(a,b) return tostring(a.date)>tostring(b.date) end)
  return record
end

function S.ensure(n)
  ensure(n)
end

function S.verifySeal(n,wanted)
  wanted=trim(wanted):upper()
  if wanted=="" then return nil end
  for _,o in pairs(n.organizations or {}) do
    if tostring(o.registrationSeal or ""):upper()==wanted then
      return {kind="organization",objectId=o.id,title=o.name,issuedAt=o.createdAt,issuedBy=o.createdBy}
    end
    for _,h in ipairs(o.history or {}) do
      if tostring(h.seal or ""):upper()==wanted then
        return {kind="organization_history",objectId=o.id,title=o.name.." / modification",issuedAt=h.at,issuedBy=h.by}
      end
    end
  end
  for _,l in pairs(n.licenses or {}) do
    if tostring(l.seal or ""):upper()==wanted then
      return {kind="license",objectId=l.id,title=l.title,issuedAt=l.issuedAt,issuedBy=l.issuedBy}
    end
    for _,h in ipairs(l.history or {}) do
      if tostring(h.seal or ""):upper()==wanted then
        return {kind="license_history",objectId=l.id,title=l.title.." / "..tostring(h.event),issuedAt=h.at,issuedBy=h.by}
      end
    end
  end
  for _,f in pairs(n.fines or {}) do
    if tostring(f.seal or ""):upper()==wanted then
      return {kind="fine",objectId=f.id,title="Amende / "..f.citizenId,issuedAt=f.issuedAt,issuedBy=f.issuedBy}
    end
    for _,h in ipairs(f.history or {}) do
      if tostring(h.seal or ""):upper()==wanted then
        return {kind="fine_history",objectId=f.id,title="Amende / "..tostring(h.event),issuedAt=h.at,issuedBy=h.by}
      end
    end
  end
  return nil
end

function S.handle(state,actor,action,p,ctx)
  local n=state.national
  ensure(n)
  p=p or {}

  if action=="NC_ORG_LIST" then return true,listOrganizations(n,p) end
  if action=="NC_ORG_GET" then
    local o=org(n,p.id)
    if not o then return true,nil,"Organisation introuvable." end
    return true,copy(o)
  end
  if action=="NC_ORG_CREATE" then
    if not canManageOrganizations(actor) then return true,nil,"Registre des organisations reserve a la Presidence ou au MIN-ECO." end
    local name=trim(p.name)
    local activity=trim(p.activity)
    if name=="" or activity=="" then return true,nil,"Nom et activite obligatoires." end
    local validKinds={company=true,association=true,public_body=true,media=true,bank=true,cooperative=true}
    local kind=validKinds[p.kind] and p.kind or "company"
    local id=nextSequential(n,"nextOrganization","NC-ORG")
    local owners={}
    for _,citId in ipairs(type(p.ownerCitizenIds)=="table" and p.ownerCitizenIds or {}) do
      local cit=citizen(n,citId)
      if cit and cit.status=="citizen" then owners[#owners+1]={citizenId=cit.id,identity=cit.identity} end
    end
    local o={
      id=id,name=name,kind=kind,status="active",activity=activity,
      registeredAddress=trim(p.registeredAddress),owners=owners,
      createdAt=common.now(),createdBy=identity(actor),history={}
    }
    o.registrationSeal=seal("NC-ORG",{o.id,o.name,o.kind,o.activity,o.registeredAddress,o.owners,o.createdAt,o.createdBy})
    n.organizations[id]=o
    if ctx and ctx.gazette then ctx.gazette("organization",o.id,"Immatriculation de "..o.name,o.kind.." / "..o.activity,o.registrationSeal,"public") end
    if ctx and ctx.mutate then ctx.mutate("NC_ORG_CREATE",o.id,o.name.." / "..o.kind) end
    return true,copy(o)
  end
  if action=="NC_ORG_UPDATE" then
    if not canManageOrganizations(actor) then return true,nil,"Modification du registre des organisations non autorisee." end
    local o=org(n,p.id)
    if not o then return true,nil,"Organisation introuvable." end
    local validStatus={active=true,suspended=true,dissolved=true}
    local old=copy(o)
    if p.name~=nil and trim(p.name)~="" then o.name=trim(p.name) end
    if p.activity~=nil then o.activity=trim(p.activity) end
    if p.registeredAddress~=nil then o.registeredAddress=trim(p.registeredAddress) end
    if p.status~=nil and validStatus[p.status] then o.status=p.status end
    o.updatedAt=common.now();o.updatedBy=identity(actor)
    local h={event="updated",at=o.updatedAt,by=o.updatedBy,oldStatus=old.status,newStatus=o.status}
    h.seal=seal("NC-ORG-HIST",{o.id,h.event,h.at,h.by,old.name,o.name,old.status,o.status,old.activity,o.activity})
    o.history[#o.history+1]=h
    if ctx and ctx.gazette and old.status~=o.status then
      ctx.gazette("organization_status",o.id,"Statut de "..o.name,old.status.." -> "..o.status,h.seal,"public")
    end
    if ctx and ctx.mutate then ctx.mutate("NC_ORG_UPDATE",o.id,old.status.." -> "..o.status) end
    return true,copy(o)
  end

  if action=="NC_LICENSE_LIST" then return true,listLicenses(n,p,actor) end
  if action=="NC_LICENSE_GET" then
    local l=n.licenses[trim(p.id):upper()]
    if not l then return true,nil,"Licence introuvable." end
    local visible=canManageAnyLicense(actor) or (l.holderType=="citizen" and isSelfCitizen(actor,l.holderId))
    if not visible then return true,nil,"Acces refuse a cette licence." end
    return true,copy(l)
  end
  if action=="NC_LICENSE_ISSUE" then
    local kind=trim(p.kind):lower()
    if kind=="" then return true,nil,"Type de licence obligatoire." end
    if not canManageLicense(actor,kind) then
      return true,nil,"Cette licence doit etre delivree par "..tostring(licenseAuthority(kind) or "la Presidence").."."
    end
    local holderType=(p.holderType=="organization") and "organization" or "citizen"
    local holderId=trim(p.holderId):upper()
    local holderName=nil
    if holderType=="citizen" then
      local cit=citizen(n,holderId)
      if not cit or cit.status~="citizen" then return true,nil,"Citoyen actif introuvable." end
      holderName=cit.displayName or cit.identity
    else
      local o=org(n,holderId)
      if not o or o.status~="active" then return true,nil,"Organisation active introuvable." end
      holderName=o.name
    end
    local title=trim(p.title)
    if title=="" then title="Licence "..kind end
    local legalBasis=trim(p.legalBasis)
    if legalBasis~="" and not law(n,ctx,legalBasis) then return true,nil,"Base legale nationale introuvable." end
    local id=nextYearId(n.licenseCounters,"NC-LIC")
    local l={
      id=id,kind=kind,title=title,status="active",
      holderType=holderType,holderId=holderId,holderName=holderName,
      authority=licenseAuthority(kind) or (actor.ministryCode or "PRESIDENCE"),
      legalBasis=legalBasis,conditions=trim(p.conditions),notes=trim(p.notes),
      issuedAt=common.now(),issuedBy=identity(actor),expiresAt=trim(p.expiresAt),history={}
    }
    l.seal=seal("NC-LIC",{l.id,l.kind,l.title,l.holderType,l.holderId,l.authority,l.legalBasis,l.conditions,l.issuedAt,l.issuedBy,l.expiresAt})
    n.licenses[id]=l
    if holderType=="citizen" then notifyCitizen(ctx,state,n,holderId,"Licence nationale delivree",id.." / "..title,"success","nc_license",id) end
    if ctx and ctx.mutate then ctx.mutate("NC_LICENSE_ISSUE",id,holderId.." / "..kind) end
    return true,copy(l)
  end
  if action=="NC_LICENSE_SET_STATUS" then
    local l=n.licenses[trim(p.id):upper()]
    if not l then return true,nil,"Licence introuvable." end
    if not canManageLicense(actor,l.kind) then return true,nil,"Modification de licence non autorisee." end
    local valid={active=true,suspended=true,revoked=true,expired=true}
    if not valid[p.status] then return true,nil,"Statut de licence invalide." end
    if l.status==p.status then return true,copy(l) end
    local old=l.status
    l.status=p.status;l.updatedAt=common.now();l.updatedBy=identity(actor)
    local h={event="status",old=old,new=l.status,reason=trim(p.reason),at=l.updatedAt,by=l.updatedBy}
    h.seal=seal("NC-LIC-HIST",{l.id,h.event,h.old,h.new,h.reason,h.at,h.by,l.seal})
    l.history[#l.history+1]=h
    if l.holderType=="citizen" then notifyCitizen(ctx,state,n,l.holderId,"Statut d'une licence modifie",l.id.." : "..old.." -> "..l.status,"warning","nc_license",l.id) end
    if ctx and ctx.mutate then ctx.mutate("NC_LICENSE_SET_STATUS",l.id,old.." -> "..l.status) end
    return true,copy(l)
  end

  if action=="NC_FINE_LIST" then return true,listFines(n,p,actor) end
  if action=="NC_FINE_GET" then
    local fine=n.fines[trim(p.id):upper()]
    if not fine then return true,nil,"Amende introuvable." end
    if not (canIssueFine(actor) or canResolveFine(actor) or isSelfCitizen(actor,fine.citizenId)) then return true,nil,"Acces refuse a cette amende." end
    return true,copy(fine)
  end
  if action=="NC_FINE_ISSUE" then
    if not canIssueFine(actor) then return true,nil,"Emission d'amende reservee a la police, au parquet ou a la justice." end
    local cit=citizen(n,p.citizenId)
    if not cit then return true,nil,"Citoyen introuvable." end
    local linkedLaw=law(n,ctx,p.articleRef)
    if not linkedLaw then return true,nil,"Article national introuvable." end
    local units=tonumber(p.penaltyUnits)
    if not units or units<=0 then return true,nil,"Nombre d'unites de penalite invalide." end
    local reason=trim(p.reason)
    if reason=="" then reason=linkedLaw.title end
    local id=nextYearId(n.fineCounters,"NC-FINE")
    local fine={
      id=id,citizenId=cit.id,citizenIdentity=cit.identity,status="issued",
      articleRef=linkedLaw.id,articleDisplay=linkedLaw.display_reference,
      articleVersion=linkedLaw.version,reason=reason,penaltyUnits=units,
      amountText=trim(p.amountText),issuedAt=common.now(),issuedBy=identity(actor),
      contestReason=nil,history={}
    }
    fine.seal=seal("NC-FINE",{fine.id,fine.citizenId,fine.articleRef,fine.articleVersion,fine.reason,fine.penaltyUnits,fine.amountText,fine.issuedAt,fine.issuedBy})
    n.fines[id]=fine
    notifyCitizen(ctx,state,n,cit.id,"Amende nationale emise",id.." / "..reason.." / "..tostring(units).." UP","warning","nc_fine",id)
    if ctx and ctx.mutate then ctx.mutate("NC_FINE_ISSUE",id,cit.id.." / "..linkedLaw.id.." / "..tostring(units).." UP") end
    return true,copy(fine)
  end
  if action=="NC_FINE_CONTEST" then
    local fine=n.fines[trim(p.id):upper()]
    if not fine then return true,nil,"Amende introuvable." end
    if not isSelfCitizen(actor,fine.citizenId) then return true,nil,"Seul le citoyen concerne peut contester cette amende depuis son terminal." end
    if fine.status~="issued" then return true,nil,"Cette amende n'est plus contestable dans son etat actuel." end
    local reason=trim(p.reason)
    if reason=="" then return true,nil,"Motif de contestation obligatoire." end
    fine.status="contested";fine.contestReason=reason;fine.contestedAt=common.now();fine.contestedBy=identity(actor)
    local h={event="contested",at=fine.contestedAt,by=fine.contestedBy,reason=reason}
    h.seal=seal("NC-FINE-HIST",{fine.id,h.event,h.at,h.by,h.reason,fine.seal})
    fine.history[#fine.history+1]=h
    if ctx and ctx.mutate then ctx.mutate("NC_FINE_CONTEST",fine.id,reason) end
    return true,copy(fine)
  end
  if action=="NC_FINE_RESOLVE" then
    local fine=n.fines[trim(p.id):upper()]
    if not fine then return true,nil,"Amende introuvable." end
    if not canResolveFine(actor) then return true,nil,"Decision sur contestation reservee au parquet ou a la justice." end
    if fine.status~="contested" then return true,nil,"Aucune contestation active." end
    local decision=(p.decision=="upheld" or p.decision=="void") and p.decision or nil
    if not decision then return true,nil,"Decision invalide." end
    local reasoning=trim(p.reasoning)
    if reasoning=="" then return true,nil,"Motivation obligatoire." end
    local old=fine.status
    fine.status=(decision=="void") and "void" or "issued"
    fine.contestDecision=decision;fine.contestDecisionReason=reasoning
    fine.decidedAt=common.now();fine.decidedBy=identity(actor)
    local h={event="contest_decision",old=old,new=fine.status,decision=decision,reason=reasoning,at=fine.decidedAt,by=fine.decidedBy}
    h.seal=seal("NC-FINE-HIST",{fine.id,h.event,h.old,h.new,h.decision,h.reason,h.at,h.by,fine.seal})
    fine.history[#fine.history+1]=h
    notifyCitizen(ctx,state,n,fine.citizenId,"Decision sur contestation",fine.id.." / "..decision,"info","nc_fine",fine.id)
    if ctx and ctx.mutate then ctx.mutate("NC_FINE_RESOLVE",fine.id,decision.." / "..reasoning) end
    return true,copy(fine)
  end
  if action=="NC_FINE_MARK_PAID" then
    local fine=n.fines[trim(p.id):upper()]
    if not fine then return true,nil,"Amende introuvable." end
    if not canMarkPaid(actor) then return true,nil,"Validation du paiement non autorisee." end
    if fine.status~="issued" then return true,nil,"Cette amende ne peut pas etre marquee payee." end
    fine.status="paid";fine.paidAt=common.now();fine.paidBy=identity(actor);fine.paymentRef=trim(p.paymentRef)
    local h={event="paid",at=fine.paidAt,by=fine.paidBy,paymentRef=fine.paymentRef}
    h.seal=seal("NC-FINE-HIST",{fine.id,h.event,h.at,h.by,h.paymentRef,fine.seal})
    fine.history[#fine.history+1]=h
    notifyCitizen(ctx,state,n,fine.citizenId,"Amende acquittee",fine.id.." / paiement enregistre","success","nc_fine",fine.id)
    if ctx and ctx.mutate then ctx.mutate("NC_FINE_MARK_PAID",fine.id,fine.paymentRef) end
    return true,copy(fine)
  end
  if action=="NC_FINE_VOID" then
    local fine=n.fines[trim(p.id):upper()]
    if not fine then return true,nil,"Amende introuvable." end
    if not canResolveFine(actor) then return true,nil,"Annulation reservee au parquet ou a la justice." end
    if fine.status=="paid" or fine.status=="void" then return true,nil,"Amende deja finalisee." end
    local reason=trim(p.reason)
    if reason=="" then return true,nil,"Motif d'annulation obligatoire." end
    local old=fine.status
    fine.status="void";fine.voidReason=reason;fine.voidedAt=common.now();fine.voidedBy=identity(actor)
    local h={event="void",old=old,new="void",reason=reason,at=fine.voidedAt,by=fine.voidedBy}
    h.seal=seal("NC-FINE-HIST",{fine.id,h.event,h.old,h.new,h.reason,h.at,h.by,fine.seal})
    fine.history[#fine.history+1]=h
    notifyCitizen(ctx,state,n,fine.citizenId,"Amende annulee",fine.id.." / "..reason,"success","nc_fine",fine.id)
    if ctx and ctx.mutate then ctx.mutate("NC_FINE_VOID",fine.id,reason) end
    return true,copy(fine)
  end

  if action=="NC_RECORD_GET" then
    local citizenId=trim(p.citizenId):upper()
    if not canViewCitizenRecord(actor,citizenId) then return true,nil,"Acces refuse a ce dossier individuel." end
    local record,err=buildRecord(n,citizenId)
    if not record then return true,nil,err end
    return true,record
  end

  return false,nil,nil
end

return S
