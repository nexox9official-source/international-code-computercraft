local common=dofile("/international_code/common.lua")

local F={}

local function copy(v) return common.deepcopy(v) end
local function trim(v) return common.trim(v) end
local function role(actor) return actor and actor.nationalRole or nil end
local function identity(actor) return trim(actor and (actor.nationalIdentity or actor.label or actor.clientId) or "") end
local function technicalAdmin(actor)
  return actor and (actor.nationalRoot==true or
    (actor.role=="admin" and (not actor.nationalRole or actor.nationalRole=="admin")))
end
local function yearNow() return os.date and os.date("%Y") or "0000" end
local function seal(prefix,payload)
  local raw=textutils.serialize(payload,{compact=true}).."|"..tostring(common.nowMs()).."|"..common.randomToken(8)
  return prefix.."-"..common.simpleChecksum(raw):upper()
end
local function nextYearId(counter,prefix)
  local y=yearNow()
  local n=(counter[y] or 0)+1
  counter[y]=n
  return string.format("%s-%s-%04d",prefix,y,n)
end

function F.ensure(n)
  n.budgets=n.budgets or {}
  n.budgetCounters=n.budgetCounters or {}
  n.revenues=n.revenues or {}
  n.revenueCounters=n.revenueCounters or {}
  n.expenses=n.expenses or {}
  n.expenseCounters=n.expenseCounters or {}
  n.contracts=n.contracts or {}
  n.contractCounters=n.contractCounters or {}
  n.financeSettings=n.financeSettings or {
    unit="UB",
    highValueThreshold=2500,
    quorumRatio=0.5
  }
  n.financeSettings.unit=n.financeSettings.unit or "UB"
  n.financeSettings.highValueThreshold=tonumber(n.financeSettings.highValueThreshold) or 2500
  n.financeSettings.quorumRatio=tonumber(n.financeSettings.quorumRatio) or 0.5
end

local function activeCitizen(n,actor)
  if not actor or not actor.citizenId then return false end
  local c=n.citizens and n.citizens[actor.citizenId]
  return c and c.status=="citizen"
end

local function canManageFinance(actor)
  local r=role(actor)
  return technicalAdmin(actor) or r=="president" or (r=="minister" and actor.ministryCode=="MIN-ECO")
end

local function canCloseVote(actor)
  local r=role(actor)
  return technicalAdmin(actor) or r=="president" or r=="council"
end

local function canRequestExpense(actor,ministryCode)
  local r=role(actor)
  if technicalAdmin(actor) or r=="president" then return true end
  return r=="minister" and actor.ministryCode==ministryCode
end

local function canManageMinistryContract(actor,ministryCode)
  return canRequestExpense(actor,ministryCode) or canManageFinance(actor)
end

local function eligibleCouncil(n,state)
  local out,seen={},{}
  for _,cl in pairs(state.clients or {}) do
    local r=role(cl)
    local c=cl.citizenId and n.citizens and n.citizens[cl.citizenId] or nil
    if c and c.status=="citizen" and (r=="president" or r=="council") and not seen[c.id] then
      seen[c.id]=true
      out[#out+1]=c.id
    end
  end
  table.sort(out)
  return out
end

local function isEligible(citizenId,list)
  if not citizenId then return false end
  for _,x in ipairs(list or {}) do if x==citizenId then return true end end
  return false
end

local function tallyBudget(b)
  local yes,no,abstain=0,0,0
  for _,v in pairs(b.votes or {}) do
    if v.choice=="yes" then yes=yes+1 elseif v.choice=="no" then no=no+1 else abstain=abstain+1 end
  end
  local eligible=#(b.eligibleCitizens or {})
  local participation=yes+no+abstain
  local required=eligible>0 and math.max(1,math.ceil(eligible*0.5)) or 0
  local quorum=eligible>0 and participation>=required
  return {
    yes=yes,no=no,abstain=abstain,eligible=eligible,participation=participation,
    quorumRequired=required,quorumMet=quorum,adopted=quorum and yes>no
  }
end

local function budgetTotal(b)
  local total=tonumber(b.reserveUB or 0) or 0
  for _,v in pairs(b.allocations or {}) do total=total+(tonumber(v) or 0) end
  return total
end

local function budgetSpent(n,budgetId,ministryCode)
  local total=0
  for _,e in pairs(n.expenses or {}) do
    if e.budgetId==budgetId and e.ministryCode==ministryCode and e.status=="paid" then
      total=total+(tonumber(e.amountUB) or 0)
    end
  end
  return total
end

local function budgetCommitted(n,budgetId,ministryCode)
  local total=0
  for _,e in pairs(n.expenses or {}) do
    if e.budgetId==budgetId and e.ministryCode==ministryCode and
       (e.status=="finance_approved" or e.status=="president_approved" or e.status=="paid") then
      total=total+(tonumber(e.amountUB) or 0)
    end
  end
  return total
end

local function treasuryBalance(n)
  local rev=0
  for _,r in pairs(n.revenues or {}) do
    if r.status=="recorded" then rev=rev+(tonumber(r.amountUB) or 0) end
  end
  local spent=0
  for _,e in pairs(n.expenses or {}) do
    if e.status=="paid" then spent=spent+(tonumber(e.amountUB) or 0) end
  end
  return rev-spent,rev,spent
end

local function currentBudget(n)
  local best=nil
  for _,b in pairs(n.budgets or {}) do
    if b.status=="enacted" and (not best or tostring(b.fiscalYear)>tostring(best.fiscalYear) or
       (tostring(b.fiscalYear)==tostring(best.fiscalYear) and tostring(b.id)>tostring(best.id))) then
      best=b
    end
  end
  return best
end

local function budgetView(n,b)
  local out=copy(b)
  out.totalUB=budgetTotal(b)
  out.tally=tallyBudget(b)
  out.execution={}
  for code,allocated in pairs(b.allocations or {}) do
    local spent=budgetSpent(n,b.id,code)
    local committed=budgetCommitted(n,b.id,code)
    out.execution[code]={
      allocatedUB=tonumber(allocated) or 0,spentUB=spent,committedUB=committed,
      availableUB=(tonumber(allocated) or 0)-committed
    }
  end
  return out
end

local function listBudgets(n,p)
  p=p or {}
  local status=trim(p.status)
  local fiscal=trim(p.fiscalYear)
  local out={}
  for _,b in pairs(n.budgets or {}) do
    if (status=="" or b.status==status) and (fiscal=="" or tostring(b.fiscalYear)==fiscal) then
      out[#out+1]=budgetView(n,b)
    end
  end
  table.sort(out,function(a,b) return tostring(a.id)>tostring(b.id) end)
  return out
end

local function listRevenues(n,p)
  p=p or {}
  local q=trim(p.query)
  local kind=trim(p.kind)
  local out={}
  for _,r in pairs(n.revenues or {}) do
    local hit=q=="" or common.contains(r.id,q) or common.contains(r.title,q) or common.contains(r.source,q) or common.contains(r.legalBasis,q)
    if hit and (kind=="" or r.kind==kind) then out[#out+1]=copy(r) end
  end
  table.sort(out,function(a,b) return tostring(a.id)>tostring(b.id) end)
  return out
end

local function expenseVisible(actor,e)
  if technicalAdmin(actor) or role(actor)=="president" or (role(actor)=="minister" and actor.ministryCode=="MIN-ECO") then return true end
  if role(actor)=="minister" and actor.ministryCode==e.ministryCode then return true end
  return false
end

local function listExpenses(n,p,actor)
  p=p or {}
  local q=trim(p.query)
  local status=trim(p.status)
  local ministry=trim(p.ministryCode):upper()
  local out={}
  for _,e in pairs(n.expenses or {}) do
    local hit=q=="" or common.contains(e.id,q) or common.contains(e.title,q) or common.contains(e.purpose,q) or common.contains(e.vendorName,q)
    if hit and (status=="" or e.status==status) and (ministry=="" or e.ministryCode==ministry) and expenseVisible(actor,e) then
      out[#out+1]=copy(e)
    end
  end
  table.sort(out,function(a,b) return tostring(a.id)>tostring(b.id) end)
  return out
end

local function contractVisible(actor,c)
  if technicalAdmin(actor) or role(actor)=="president" or (role(actor)=="minister" and actor.ministryCode=="MIN-ECO") then return true end
  return role(actor)=="minister" and actor.ministryCode==c.ministryCode
end

local function listContracts(n,p,actor)
  p=p or {}
  local q=trim(p.query)
  local status=trim(p.status)
  local ministry=trim(p.ministryCode):upper()
  local out={}
  for _,c in pairs(n.contracts or {}) do
    local hit=q=="" or common.contains(c.id,q) or common.contains(c.title,q) or common.contains(c.vendorName,q) or common.contains(c.purpose,q)
    if hit and (status=="" or c.status==status) and (ministry=="" or c.ministryCode==ministry) and contractVisible(actor,c) then
      out[#out+1]=copy(c)
    end
  end
  table.sort(out,function(a,b) return tostring(a.id)>tostring(b.id) end)
  return out
end

local function notifyFinance(ctx,state,n,title,body,severity,objectType,objectId,targetMinistry)
  if not ctx or not ctx.notice then return end
  if targetMinistry then
    for _,cl in pairs(state.clients or {}) do
      if cl.nationalRole=="minister" and cl.ministryCode==targetMinistry then
        ctx.notice({title=title,body=body,severity=severity or "info",objectType=objectType,objectId=objectId,targetClientId=cl.clientId})
      end
    end
  end
  ctx.notice({title=title,body=body,severity=severity or "info",objectType=objectType,objectId=objectId,targetStateId=n.meta and n.meta.stateId})
end

local function ministryExists(n,code)
  return n.ministries and n.ministries[code]~=nil
end

local function organization(n,id)
  return n.organizations and n.organizations[trim(id):upper()] or nil
end

function F.summary(n)
  F.ensure(n)
  local balance,revenue,spent=treasuryBalance(n)
  local b=currentBudget(n)
  local pending=0
  for _,e in pairs(n.expenses or {}) do
    if e.status~="paid" and e.status~="rejected" and e.status~="cancelled" then pending=pending+1 end
  end
  return {
    unit=n.financeSettings.unit,balanceUB=balance,revenueUB=revenue,spentUB=spent,
    currentBudgetId=b and b.id or nil,currentFiscalYear=b and b.fiscalYear or nil,
    pendingExpenses=pending,highValueThreshold=n.financeSettings.highValueThreshold
  }
end

function F.findSeal(n,wanted)
  F.ensure(n)
  wanted=trim(wanted):upper()
  for _,b in pairs(n.budgets) do
    for _,field in ipairs({"seal","voteSeal","enactmentSeal","closeSeal"}) do
      if tostring(b[field] or ""):upper()==wanted then return {kind="budget",objectId=b.id,title=b.title,issuedAt=b.enactedAt or b.closedAt or b.createdAt,issuedBy=b.enactedBy or b.createdBy} end
    end
  end
  for _,r in pairs(n.revenues) do
    if tostring(r.seal or ""):upper()==wanted then return {kind="revenue",objectId=r.id,title=r.title,issuedAt=r.recordedAt,issuedBy=r.recordedBy} end
  end
  for _,e in pairs(n.expenses) do
    for _,field in ipairs({"requestSeal","financeSeal","presidentSeal","paymentSeal","decisionSeal"}) do
      if tostring(e[field] or ""):upper()==wanted then return {kind="expense",objectId=e.id,title=e.title,issuedAt=e.paidAt or e.updatedAt or e.createdAt,issuedBy=e.paidBy or e.requestedBy} end
    end
  end
  for _,c in pairs(n.contracts) do
    for _,field in ipairs({"draftSeal","awardSeal","closeSeal"}) do
      if tostring(c[field] or ""):upper()==wanted then return {kind="contract",objectId=c.id,title=c.title,issuedAt=c.awardedAt or c.createdAt,issuedBy=c.awardedBy or c.createdBy} end
    end
  end
  return nil
end

function F.handle(state,actor,action,p,ctx)
  local n=state.national
  F.ensure(n)
  p=p or {}

  if action=="NC_TREASURY_DASHBOARD" then return true,F.summary(n) end

  if action=="NC_BUDGET_LIST" then return true,listBudgets(n,p) end
  if action=="NC_BUDGET_GET" then
    local b=n.budgets[trim(p.id):upper()]
    if not b then return true,nil,"Budget introuvable." end
    return true,budgetView(n,b)
  end

  if action=="NC_BUDGET_CREATE" then
    if not canManageFinance(actor) then return true,nil,"Creation budgetaire reservee a la Presidence ou au MIN-ECO." end
    local fiscal=trim(p.fiscalYear)
    local title=trim(p.title)
    if fiscal=="" or title=="" then return true,nil,"Exercice et titre obligatoires." end
    local id=nextYearId(n.budgetCounters,"NC-BUD")
    local b={
      id=id,fiscalYear=fiscal,title=title,status="draft",allocations={},
      reserveUB=math.max(0,tonumber(p.reserveUB) or 0),expectedRevenueUB=math.max(0,tonumber(p.expectedRevenueUB) or 0),
      notes=trim(p.notes),eligibleCitizens={},votes={},
      createdAt=common.now(),createdBy=identity(actor),updatedAt=common.now()
    }
    b.seal=seal("NC-BUD",{b.id,b.fiscalYear,b.title,b.reserveUB,b.expectedRevenueUB,b.createdAt,b.createdBy})
    n.budgets[id]=b
    ctx.mutate("NC_BUDGET_CREATE",id,title.." / exercice "..fiscal)
    return true,budgetView(n,b)
  end

  if action=="NC_BUDGET_SET_ALLOCATION" then
    if not canManageFinance(actor) then return true,nil,"Modification budgetaire non autorisee." end
    local b=n.budgets[trim(p.id):upper()]
    if not b then return true,nil,"Budget introuvable." end
    if b.status~="draft" then return true,nil,"Les credits sont verrouilles apres ouverture du vote." end
    local code=trim(p.ministryCode):upper()
    if not ministryExists(n,code) then return true,nil,"Ministere introuvable." end
    local amount=tonumber(p.amountUB)
    if not amount or amount<0 then return true,nil,"Montant invalide." end
    b.allocations[code]=amount
    b.updatedAt=common.now();b.updatedBy=identity(actor)
    ctx.mutate("NC_BUDGET_SET_ALLOCATION",b.id,code.." = "..amount.." "..n.financeSettings.unit)
    return true,budgetView(n,b)
  end

  if action=="NC_BUDGET_OPEN_VOTE" then
    if not canManageFinance(actor) then return true,nil,"Ouverture du budget reservee a la Presidence ou au MIN-ECO." end
    local b=n.budgets[trim(p.id):upper()]
    if not b then return true,nil,"Budget introuvable." end
    if b.status~="draft" then return true,nil,"Budget non ouvrable au vote." end
    b.eligibleCitizens=eligibleCouncil(n,state)
    if #b.eligibleCitizens==0 then return true,nil,"Aucun membre du Conseil eligible." end
    b.votes={};b.status="voting";b.openedAt=common.now();b.openedBy=identity(actor)
    b.voteOpenSeal=seal("NC-BUD-VOTE",{b.id,b.allocations,b.reserveUB,b.expectedRevenueUB,b.eligibleCitizens,b.openedAt,b.openedBy})
    notifyFinance(ctx,state,n,"Vote budgetaire ouvert",b.id.." / "..b.title,"warning","nc_budget",b.id)
    ctx.mutate("NC_BUDGET_OPEN_VOTE",b.id,b.voteOpenSeal)
    return true,budgetView(n,b)
  end

  if action=="NC_BUDGET_VOTE" then
    local b=n.budgets[trim(p.id):upper()]
    if not b then return true,nil,"Budget introuvable." end
    if b.status~="voting" then return true,nil,"Vote budgetaire ferme." end
    if not activeCitizen(n,actor) or not isEligible(actor.citizenId,b.eligibleCitizens) then return true,nil,"Vous ne faites pas partie du corps electoral budgetaire." end
    local choice=trim(p.choice):lower()
    if choice~="yes" and choice~="no" and choice~="abstain" then return true,nil,"Vote invalide." end
    b.votes[actor.citizenId]={choice=choice,at=common.now(),identity=identity(actor),clientId=actor.clientId}
    ctx.mutate("NC_BUDGET_VOTE",b.id,actor.citizenId.." = "..choice)
    return true,budgetView(n,b)
  end

  if action=="NC_BUDGET_CLOSE_VOTE" then
    if not canCloseVote(actor) then return true,nil,"Cloture reservee a la Presidence ou au Conseil." end
    local b=n.budgets[trim(p.id):upper()]
    if not b then return true,nil,"Budget introuvable." end
    if b.status~="voting" then return true,nil,"Budget non soumis au vote." end
    local t=tallyBudget(b)
    b.closedVoteAt=common.now();b.closedVoteBy=identity(actor);b.tallyAtClose=t
    if not t.quorumMet then b.status="no_quorum";b.result="no_quorum"
    elseif t.adopted then b.status="adopted";b.result="adopted"
    else b.status="rejected";b.result="rejected" end
    b.voteSeal=seal("NC-BUD-RESULT",{b.id,b.result,b.votes,b.eligibleCitizens,b.closedVoteAt,b.closedVoteBy})
    notifyFinance(ctx,state,n,"Resultat budgetaire",b.id.." / "..string.upper(b.result),"info","nc_budget",b.id)
    ctx.mutate("NC_BUDGET_CLOSE_VOTE",b.id,b.result.." / "..b.voteSeal)
    return true,budgetView(n,b)
  end

  if action=="NC_BUDGET_ENACT" then
    if not (technicalAdmin(actor) or role(actor)=="president") then return true,nil,"Promulgation budgetaire reservee a la Presidence." end
    local b=n.budgets[trim(p.id):upper()]
    if not b then return true,nil,"Budget introuvable." end
    if b.status~="adopted" then return true,nil,"Le budget doit etre adopte avant promulgation." end
    for _,x in pairs(n.budgets) do
      if x.id~=b.id and x.status=="enacted" and tostring(x.fiscalYear)==tostring(b.fiscalYear) then
        x.status="superseded";x.supersededAt=common.now();x.supersededBy=b.id
      end
    end
    b.status="enacted";b.enactedAt=common.now();b.enactedBy=identity(actor)
    b.enactmentSeal=seal("NC-BUD-ENACT",{b.id,b.voteSeal,b.allocations,b.reserveUB,b.expectedRevenueUB,b.enactedAt,b.enactedBy})
    if ctx.gazette then
      local gaz=ctx.gazette("budget_enactment",b.id,"Budget national "..b.fiscalYear,
        b.title.." / credits autorises: "..budgetTotal(b).." "..n.financeSettings.unit,
        b.enactmentSeal,"public")
      b.gazetteId=gaz and gaz.id or nil
    end
    notifyFinance(ctx,state,n,"Budget national promulgue",b.id.." / exercice "..b.fiscalYear,"success","nc_budget",b.id)
    ctx.mutate("NC_BUDGET_ENACT",b.id,b.enactmentSeal)
    return true,budgetView(n,b)
  end

  if action=="NC_REVENUE_LIST" then return true,listRevenues(n,p) end
  if action=="NC_REVENUE_RECORD" then
    if not canManageFinance(actor) then return true,nil,"Recette reservee a la Presidence ou au MIN-ECO." end
    local valid={opening_balance=true,tax=true,customs=true,fine=true,fee=true,dividend=true,grant=true,other=true}
    local kind=valid[p.kind] and p.kind or "other"
    local title=trim(p.title)
    local amount=tonumber(p.amountUB)
    if title=="" or not amount or amount<=0 then return true,nil,"Titre et montant positif obligatoires." end
    local legalBasis=trim(p.legalBasis)
    if (kind=="tax" or kind=="customs" or kind=="fine") and legalBasis=="" then return true,nil,"Base legale obligatoire pour cette recette." end
    if legalBasis~="" and ctx.getLaw and not ctx.getLaw(n,legalBasis) then return true,nil,"Base legale nationale introuvable." end
    local id=nextYearId(n.revenueCounters,"NC-REV")
    local row={
      id=id,kind=kind,title=title,amountUB=amount,source=trim(p.source),legalBasis=legalBasis,
      status="recorded",recordedAt=common.now(),recordedBy=identity(actor),notes=trim(p.notes)
    }
    row.seal=seal("NC-REV",{row.id,row.kind,row.title,row.amountUB,row.source,row.legalBasis,row.recordedAt,row.recordedBy})
    n.revenues[id]=row
    ctx.mutate("NC_REVENUE_RECORD",id,title.." / +"..amount.." "..n.financeSettings.unit)
    return true,copy(row)
  end

  if action=="NC_EXPENSE_LIST" then return true,listExpenses(n,p,actor) end
  if action=="NC_EXPENSE_GET" then
    local e=n.expenses[trim(p.id):upper()]
    if not e then return true,nil,"Depense introuvable." end
    if not expenseVisible(actor,e) then return true,nil,"Acces refuse a cette depense." end
    return true,copy(e)
  end

  if action=="NC_EXPENSE_REQUEST" then
    local code=trim(p.ministryCode):upper()
    if not ministryExists(n,code) then return true,nil,"Ministere introuvable." end
    if not canRequestExpense(actor,code) then return true,nil,"Vous ne pouvez pas engager ce ministere." end
    local b=n.budgets[trim(p.budgetId):upper()]
    if not b or b.status~="enacted" then return true,nil,"Budget promulgue introuvable." end
    local amount=tonumber(p.amountUB)
    local title=trim(p.title)
    local purpose=trim(p.purpose)
    if not amount or amount<=0 or title=="" or purpose=="" then return true,nil,"Titre, objet et montant positif obligatoires." end
    local allocation=tonumber((b.allocations or {})[code]) or 0
    local available=allocation-budgetCommitted(n,b.id,code)
    if amount>available then return true,nil,"Credits insuffisants: disponible "..available.." "..n.financeSettings.unit.."." end
    local legalBasis=trim(p.legalBasis)
    if legalBasis~="" and ctx.getLaw and not ctx.getLaw(n,legalBasis) then return true,nil,"Base legale introuvable." end
    local vendorType=trim(p.vendorType)
    local vendorId=trim(p.vendorId):upper()
    local vendorName=""
    if vendorType=="organization" and vendorId~="" then
      local o=organization(n,vendorId)
      if not o or o.status~="active" then return true,nil,"Organisation prestataire invalide." end
      vendorName=o.name
    else
      vendorType="other";vendorId="";vendorName=trim(p.vendorName)
    end
    local id=nextYearId(n.expenseCounters,"NC-EXP")
    local high=amount>=n.financeSettings.highValueThreshold
    local e={
      id=id,budgetId=b.id,ministryCode=code,title=title,purpose=purpose,amountUB=amount,
      legalBasis=legalBasis,vendorType=vendorType,vendorId=vendorId,vendorName=vendorName,
      status="requested",requiresPresident=high,requestedAt=common.now(),requestedBy=identity(actor),
      requesterCitizenId=actor.citizenId,history={}
    }
    e.requestSeal=seal("NC-EXP-REQ",{e.id,e.budgetId,e.ministryCode,e.title,e.purpose,e.amountUB,e.vendorId,e.legalBasis,e.requestedAt,e.requestedBy})
    n.expenses[id]=e
    notifyFinance(ctx,state,n,"Demande de depense",id.." / "..code.." / "..amount.." "..n.financeSettings.unit,
      high and "warning" or "info","nc_expense",id,"MIN-ECO")
    ctx.mutate("NC_EXPENSE_REQUEST",id,code.." / "..amount.." "..n.financeSettings.unit)
    return true,copy(e)
  end

  if action=="NC_EXPENSE_FINANCE_DECIDE" then
    if not canManageFinance(actor) then return true,nil,"Validation financiere reservee a la Presidence ou au MIN-ECO." end
    local e=n.expenses[trim(p.id):upper()]
    if not e then return true,nil,"Depense introuvable." end
    if e.status~="requested" then return true,nil,"Depense non soumise a validation financiere." end
    local approve=p.approve==true
    local reason=trim(p.reason)
    if not approve and reason=="" then return true,nil,"Motif de rejet obligatoire." end
    if approve then
      local b=n.budgets[e.budgetId]
      if not b or b.status~="enacted" then return true,nil,"Budget non actif." end
      local available=(tonumber((b.allocations or {})[e.ministryCode]) or 0)-budgetCommitted(n,b.id,e.ministryCode)
      if e.amountUB>available then return true,nil,"Credits devenus insuffisants." end
      e.status=e.requiresPresident and "finance_approved" or "president_approved"
      e.financeApprovedAt=common.now();e.financeApprovedBy=identity(actor)
      e.financeSeal=seal("NC-EXP-FIN",{e.id,e.status,e.financeApprovedAt,e.financeApprovedBy,e.requestSeal})
    else
      e.status="rejected";e.rejectedAt=common.now();e.rejectedBy=identity(actor);e.rejectionReason=reason
      e.decisionSeal=seal("NC-EXP-REJECT",{e.id,reason,e.rejectedAt,e.rejectedBy,e.requestSeal})
    end
    e.updatedAt=common.now()
    notifyFinance(ctx,state,n,approve and "Depense validee par les Finances" or "Depense rejetee",
      e.id.." / "..(approve and e.status or reason),approve and "info" or "warning","nc_expense",e.id,e.ministryCode)
    ctx.mutate("NC_EXPENSE_FINANCE_DECIDE",e.id,e.status)
    return true,copy(e)
  end

  if action=="NC_EXPENSE_PRESIDENT_DECIDE" then
    if not (technicalAdmin(actor) or role(actor)=="president") then return true,nil,"Validation reservee a la Presidence." end
    local e=n.expenses[trim(p.id):upper()]
    if not e then return true,nil,"Depense introuvable." end
    if not e.requiresPresident or e.status~="finance_approved" then return true,nil,"Cette depense n'attend pas la validation presidentielle." end
    local approve=p.approve==true
    local reason=trim(p.reason)
    if not approve and reason=="" then return true,nil,"Motif de rejet obligatoire." end
    if approve then
      e.status="president_approved";e.presidentApprovedAt=common.now();e.presidentApprovedBy=identity(actor)
      e.presidentSeal=seal("NC-EXP-PRES",{e.id,e.financeSeal,e.presidentApprovedAt,e.presidentApprovedBy})
    else
      e.status="rejected";e.rejectedAt=common.now();e.rejectedBy=identity(actor);e.rejectionReason=reason
      e.decisionSeal=seal("NC-EXP-REJECT",{e.id,reason,e.rejectedAt,e.rejectedBy,e.financeSeal})
    end
    e.updatedAt=common.now()
    notifyFinance(ctx,state,n,approve and "Depense autorisee par la Presidence" or "Depense refusee par la Presidence",
      e.id.." / "..(approve and e.status or reason),approve and "success" or "warning","nc_expense",e.id,e.ministryCode)
    ctx.mutate("NC_EXPENSE_PRESIDENT_DECIDE",e.id,e.status)
    return true,copy(e)
  end

  if action=="NC_EXPENSE_PAY" then
    if not canManageFinance(actor) then return true,nil,"Paiement reserve au MIN-ECO ou a la Presidence." end
    local e=n.expenses[trim(p.id):upper()]
    if not e then return true,nil,"Depense introuvable." end
    if e.status~="president_approved" then return true,nil,"Depense non autorisee au paiement." end
    local balance=treasuryBalance(n)
    if e.amountUB>balance then return true,nil,"Tresorerie insuffisante: solde "..balance.." "..n.financeSettings.unit.."." end
    e.status="paid";e.paidAt=common.now();e.paidBy=identity(actor);e.paymentReference=trim(p.paymentReference)
    e.paymentSeal=seal("NC-EXP-PAID",{e.id,e.amountUB,e.vendorId,e.vendorName,e.paidAt,e.paidBy,e.financeSeal,e.presidentSeal})
    e.updatedAt=common.now()
    notifyFinance(ctx,state,n,"Depense executee",e.id.." / "..e.amountUB.." "..n.financeSettings.unit,"success","nc_expense",e.id,e.ministryCode)
    ctx.mutate("NC_EXPENSE_PAY",e.id,e.amountUB.." "..n.financeSettings.unit.." / "..e.paymentSeal)
    return true,copy(e)
  end

  if action=="NC_CONTRACT_LIST" then return true,listContracts(n,p,actor) end
  if action=="NC_CONTRACT_GET" then
    local c=n.contracts[trim(p.id):upper()]
    if not c then return true,nil,"Marche public introuvable." end
    if not contractVisible(actor,c) then return true,nil,"Acces refuse a ce marche." end
    return true,copy(c)
  end

  if action=="NC_CONTRACT_CREATE" then
    local code=trim(p.ministryCode):upper()
    if not ministryExists(n,code) or not canManageMinistryContract(actor,code) then return true,nil,"Creation de marche non autorisee pour ce ministere." end
    local vendor=organization(n,p.vendorOrgId)
    if not vendor or vendor.status~="active" then return true,nil,"Organisation prestataire active requise." end
    local expense=n.expenses[trim(p.expenseId):upper()]
    if not expense or expense.ministryCode~=code then return true,nil,"Demande de depense associee invalide." end
    if expense.vendorId~="" and expense.vendorId~=vendor.id then return true,nil,"Prestataire incompatible avec la demande de depense." end
    if expense.status=="rejected" or expense.status=="cancelled" then return true,nil,"Depense rejetee ou annulee." end
    local method=trim(p.procurementMethod)
    local valid={open_tender=true,restricted_tender=true,direct=true,emergency=true}
    if not valid[method] then method="open_tender" end
    if (method=="direct" or method=="emergency") and trim(p.justification)=="" then return true,nil,"Justification obligatoire pour une procedure non ouverte." end
    local title=trim(p.title)
    local purpose=trim(p.purpose)
    if title=="" or purpose=="" then return true,nil,"Titre et objet obligatoires." end
    local id=nextYearId(n.contractCounters,"NC-CONTRACT")
    local row={
      id=id,title=title,ministryCode=code,vendorOrgId=vendor.id,vendorName=vendor.name,
      expenseId=expense.id,amountUB=expense.amountUB,purpose=purpose,procurementMethod=method,
      justification=trim(p.justification),status="draft",createdAt=common.now(),createdBy=identity(actor)
    }
    row.draftSeal=seal("NC-CONTRACT-DRAFT",{row.id,row.title,row.ministryCode,row.vendorOrgId,row.expenseId,row.amountUB,row.procurementMethod,row.justification,row.createdAt,row.createdBy})
    n.contracts[id]=row
    ctx.mutate("NC_CONTRACT_CREATE",id,vendor.id.." / "..row.amountUB.." "..n.financeSettings.unit)
    return true,copy(row)
  end

  if action=="NC_CONTRACT_AWARD" then
    if not canManageFinance(actor) then return true,nil,"Attribution reservee au MIN-ECO ou a la Presidence." end
    local c=n.contracts[trim(p.id):upper()]
    if not c then return true,nil,"Marche introuvable." end
    if c.status~="draft" then return true,nil,"Marche non attribuable." end
    local e=n.expenses[c.expenseId]
    if not e or (e.status~="finance_approved" and e.status~="president_approved") then return true,nil,"La depense doit d'abord etre autorisee." end
    c.status="awarded";c.awardedAt=common.now();c.awardedBy=identity(actor)
    c.awardSeal=seal("NC-CONTRACT-AWARD",{c.id,c.draftSeal,c.vendorOrgId,c.amountUB,c.awardedAt,c.awardedBy})
    e.vendorType="organization";e.vendorId=c.vendorOrgId;e.vendorName=c.vendorName;e.contractId=c.id
    if ctx.gazette then
      local gaz=ctx.gazette("public_contract",c.id,"Marche public - "..c.title,
        c.ministryCode.." / "..c.vendorName.." / "..c.amountUB.." "..n.financeSettings.unit,
        c.awardSeal,"public")
      c.gazetteId=gaz and gaz.id or nil
    end
    notifyFinance(ctx,state,n,"Marche public attribue",c.id.." / "..c.vendorName,"info","nc_contract",c.id,c.ministryCode)
    ctx.mutate("NC_CONTRACT_AWARD",c.id,c.awardSeal)
    return true,copy(c)
  end

  if action=="NC_CONTRACT_SET_STATUS" then
    local c=n.contracts[trim(p.id):upper()]
    if not c then return true,nil,"Marche introuvable." end
    if not canManageMinistryContract(actor,c.ministryCode) then return true,nil,"Gestion du marche non autorisee." end
    local transitions={
      awarded={active=true,terminated=true},
      active={completed=true,terminated=true},
      completed={},terminated={}
    }
    if not (transitions[c.status] and transitions[c.status][p.status]) then return true,nil,"Transition de marche interdite." end
    local old=c.status;c.status=p.status;c.updatedAt=common.now();c.updatedBy=identity(actor);c.statusReason=trim(p.reason)
    c.closeSeal=seal("NC-CONTRACT-STAT",{c.id,old,c.status,c.statusReason,c.updatedAt,c.updatedBy,c.awardSeal})
    ctx.mutate("NC_CONTRACT_SET_STATUS",c.id,old.." -> "..c.status)
    return true,copy(c)
  end

  return false,nil,nil
end

return F
