local common=dofile("/international_code/common.lua")

local D={}

local function copy(v) return common.deepcopy(v) end
local function now() return common.now() end
local function nowMs() return common.nowMs() end
local function trim(v) return common.trim(v) end

local function seal(prefix,payload)
  local raw=textutils.serialize(payload,{compact=true}).."|"..tostring(nowMs()).."|"..common.randomToken(8)
  return prefix.."-"..common.simpleChecksum(raw):upper()
end

local function yearNow()
  return os.date and os.date("%Y") or "0000"
end

local function nextId(counterTable,prefix)
  local y=yearNow()
  local v=(counterTable[y] or 0)+1
  counterTable[y]=v
  return string.format("%s-%s-%04d",prefix,y,v)
end

local function identity(actor)
  return trim(actor and (actor.nationalIdentity or actor.label or actor.clientId) or "")
end

local function technicalAdmin(actor)
  return actor and actor.role=="admin" and (not actor.nationalRole or actor.nationalRole=="admin")
end

local function role(actor)
  if not actor then return nil end
  if technicalAdmin(actor) then return "admin" end
  return actor.nationalRole
end

local function manager(actor)
  local r=role(actor)
  return r=="admin" or r=="president" or r=="council"
end

local function ensure(n)
  n.generalElections=n.generalElections or {}
  n.generalElectionCounters=n.generalElectionCounters or {}
  n.mandates=n.mandates or {}
  n.mandateCounters=n.mandateCounters or {}
  n.councilMembers=n.councilMembers or {}
  n.meta=n.meta or {}
  n.meta.defaultCouncilSeats=tonumber(n.meta.defaultCouncilSeats) or 5
end

function D.ensure(n)
  ensure(n)
end

local function activeCitizen(n,citizenId)
  local c=n.citizens and n.citizens[citizenId]
  return c and c.status=="citizen" and c or nil
end

local function clientHasIncompatibleOffice(state,citizenId,office)
  for _,cl in pairs(state.clients or {}) do
    if cl.citizenId==citizenId then
      local r=cl.nationalRole
      if cl.ministryCode and cl.ministryCode~="" then return true,"portefeuille ministeriel actif" end
      if r=="judge" or r=="prosecutor" or r=="police" or r=="civil_servant" or r=="minister" then
        return true,"fonction incompatible: "..tostring(r)
      end
      if office=="council" and r=="president" then return true,"Presidence en exercice" end
    end
  end
  return false,nil
end

local function citizenName(n,citizenId)
  local c=n.citizens and n.citizens[citizenId]
  return c and (c.displayName or c.identity or citizenId) or citizenId
end

local function allActiveCitizens(n)
  local out={}
  for id,c in pairs(n.citizens or {}) do
    if c.status=="citizen" then out[#out+1]=id end
  end
  table.sort(out)
  return out
end

local function candidateAllowed(n,state,citizenId,office)
  local c=activeCitizen(n,citizenId)
  if not c then return nil,"Le candidat doit etre un citoyen actif." end
  local incompatible,reason=clientHasIncompatibleOffice(state,citizenId,office)
  if incompatible then return nil,"Candidature incompatible: "..reason.."." end
  return c
end

local function electionView(n,e)
  local out=copy(e)
  out.candidateNames={}
  for _,id in ipairs(e.candidates or {}) do out.candidateNames[id]=citizenName(n,id) end
  out.runoffCandidateNames={}
  for _,id in ipairs(e.runoffCandidates or {}) do out.runoffCandidateNames[id]=citizenName(n,id) end
  out.winnerNames={}
  for _,id in ipairs(e.winners or {}) do out.winnerNames[id]=citizenName(n,id) end
  return out
end

local function countVotes(e,useRunoff)
  local votes=useRunoff and (e.runoffVotes or {}) or (e.votes or {})
  local counts={}
  local abstain=0
  local participation=0
  for _,v in pairs(votes) do
    participation=participation+1
    if v.choice=="abstain" then abstain=abstain+1
    else counts[v.choice]=(counts[v.choice] or 0)+1 end
  end
  local eligible=#(e.eligibleCitizens or {})
  local quorumRequired=eligible>0 and math.max(1,math.ceil(eligible*0.5)) or 0
  return counts,abstain,participation,eligible,quorumRequired,eligible>0 and participation>=quorumRequired
end

local function sortedCounts(counts)
  local out={}
  for citizenId,n in pairs(counts or {}) do out[#out+1]={citizenId=citizenId,votes=n} end
  table.sort(out,function(a,b)
    if a.votes~=b.votes then return a.votes>b.votes end
    return tostring(a.citizenId)<tostring(b.citizenId)
  end)
  return out
end

local function tally(e,useRunoff)
  local counts,abstain,participation,eligible,quorumRequired,quorumMet=countVotes(e,useRunoff)
  return {
    counts=counts,ranking=sortedCounts(counts),abstain=abstain,
    participation=participation,eligible=eligible,quorumRequired=quorumRequired,quorumMet=quorumMet
  }
end

local function notify(ctx,state,spec)
  if ctx and ctx.notice then return ctx.notice(spec) end
end

local function notifyCitizen(ctx,state,citizenId,title,body,severity,objectId)
  for _,cl in pairs(state.clients or {}) do
    if cl.citizenId==citizenId then
      notify(ctx,state,{
        title=title,body=body,severity=severity or "info",
        objectType="nc_general_election",objectId=objectId,targetClientId=cl.clientId
      })
    end
  end
end

local function notifyElectorate(ctx,state,e,title,body,severity)
  local wanted={}
  for _,id in ipairs(e.eligibleCitizens or {}) do wanted[id]=true end
  for _,cl in pairs(state.clients or {}) do
    if cl.citizenId and wanted[cl.citizenId] then
      notify(ctx,state,{
        title=title,body=body,severity=severity or "info",
        objectType="nc_general_election",objectId=e.id,targetClientId=cl.clientId
      })
    end
  end
end

local function mutate(ctx,action,obj,details)
  if ctx and ctx.mutate then return ctx.mutate(action,obj,details) end
end

local function gazette(ctx,kind,objectId,title,summary,sourceSeal,visibility)
  if ctx and ctx.gazette then return ctx.gazette(kind,objectId,title,summary,sourceSeal,visibility) end
end

local function endMandates(n,office,by,reason)
  for _,m in pairs(n.mandates or {}) do
    if m.office==office and m.status=="active" then
      m.status="ended"
      m.endedAt=now()
      m.endedBy=by
      m.endReason=reason or "Renouvellement electoral"
      m.endSeal=seal("NC-MANDATE-END",{m.id,m.office,m.citizenId,m.startedAt,m.endedAt,m.endedBy,m.endReason,m.seal})
    end
  end
end

local function createMandate(n,office,citizenId,electionId,termLabel,seat)
  local id=nextId(n.mandateCounters,"NC-MANDATE")
  local m={
    id=id,office=office,citizenId=citizenId,identity=citizenName(n,citizenId),
    electionId=electionId,seat=seat,status="active",termLabel=trim(termLabel),
    startedAt=now()
  }
  m.seal=seal("NC-MANDATE",{m.id,m.office,m.citizenId,m.identity,m.electionId,m.seat,m.termLabel,m.startedAt})
  n.mandates[id]=m
  return m
end

local function linkedClients(state,citizenId)
  local out={}
  for _,cl in pairs(state.clients or {}) do if cl.citizenId==citizenId then out[#out+1]=cl end end
  table.sort(out,function(a,b) return (a.computerId or 0)<(b.computerId or 0) end)
  return out
end

local function installPresident(n,state,e,citizenId,ctx,actor)
  local previous=n.meta.presidentCitizenId
  if not previous and n.meta.presidentClientId and state.clients[n.meta.presidentClientId] then
    previous=state.clients[n.meta.presidentClientId].citizenId
  end

  endMandates(n,"president",identity(actor),"Election "..e.id)
  if previous and previous~=citizenId then
    for _,cl in ipairs(linkedClients(state,previous)) do
      if cl.nationalRole=="president" then cl.nationalRole="citizen" end
    end
  end

  local clients=linkedClients(state,citizenId)
  if #clients==0 then return nil,"Le President elu ne possede aucun terminal national rattache." end
  for _,cl in ipairs(clients) do
    cl.nationalRole="president"
    cl.ministryCode=nil
  end

  local citizen=n.citizens[citizenId]
  n.meta.presidentCitizenId=citizenId
  n.meta.presidentIdentity=citizen.displayName or citizen.identity
  n.meta.presidentClientId=clients[1].clientId
  n.meta.foundingMode=false
  n.meta.foundingClosedAt=n.meta.foundingClosedAt or now()
  n.meta.foundingClosedBy=n.meta.foundingClosedBy or ("Election "..e.id)

  local m=createMandate(n,"president",citizenId,e.id,e.termLabel,1)
  local pub=gazette(ctx,"presidential_mandate",m.id,
    "Investiture du President de la Coalition",
    m.identity.." entre en fonction a la suite du scrutin "..e.id..".",
    m.seal,"internal")
  m.gazetteId=pub and pub.id or nil
  return m
end

local function installCouncil(n,state,e,winners,ctx,actor)
  endMandates(n,"council",identity(actor),"Election "..e.id)
  local old={}
  for _,id in ipairs(n.councilMembers or {}) do old[id]=true end
  local win={}
  for _,id in ipairs(winners or {}) do win[id]=true end

  for id in pairs(old) do
    if not win[id] then
      for _,cl in ipairs(linkedClients(state,id)) do
        if cl.nationalRole=="council" then cl.nationalRole="citizen" end
      end
    end
  end

  n.councilMembers={}
  local mandates={}
  for seat,citizenId in ipairs(winners or {}) do
    local clients=linkedClients(state,citizenId)
    if #clients==0 then return nil,"Le membre elu "..citizenName(n,citizenId).." ne possede aucun terminal national rattache." end
    for _,cl in ipairs(clients) do
      if cl.nationalRole=="citizen" or cl.nationalRole=="council" or not cl.nationalRole then cl.nationalRole="council" end
    end
    n.councilMembers[#n.councilMembers+1]=citizenId
    local m=createMandate(n,"council",citizenId,e.id,e.termLabel,seat)
    mandates[#mandates+1]=m
  end
  table.sort(n.councilMembers)

  local names={}
  for _,id in ipairs(n.councilMembers) do names[#names+1]=citizenName(n,id) end
  local sourceSeals={}
  for _,m in ipairs(mandates) do sourceSeals[#sourceSeals+1]=m.seal end
  local pub=gazette(ctx,"council_mandates",e.id,
    "Renouvellement du Conseil de la Coalition",
    "Membres elus: "..table.concat(names,", ")..".",
    seal("NC-COUNCIL",{e.id,n.councilMembers,sourceSeals,now()}),"internal")
  if pub then for _,m in ipairs(mandates) do m.gazetteId=pub.id end end
  return mandates
end

local function listElections(n,p)
  p=p or {}
  local q=trim(p.query)
  local stage=trim(p.stage)
  local office=trim(p.office)
  local out={}
  for _,e in pairs(n.generalElections or {}) do
    local hit=q=="" or common.contains(e.id,q) or common.contains(e.title,q) or common.contains(e.description,q)
    if hit and (stage=="" or e.stage==stage) and (office=="" or e.office==office) then out[#out+1]=electionView(n,e) end
  end
  table.sort(out,function(a,b) return tostring(a.id)>tostring(b.id) end)
  return out
end

local function listMandates(n,p)
  p=p or {}
  local office=trim(p.office)
  local status=trim(p.status)
  local citizenId=trim(p.citizenId):upper()
  local out={}
  for _,m in pairs(n.mandates or {}) do
    if (office=="" or m.office==office) and (status=="" or m.status==status) and
       (citizenId=="" or m.citizenId==citizenId) then out[#out+1]=copy(m) end
  end
  table.sort(out,function(a,b) return tostring(a.id)>tostring(b.id) end)
  return out
end

local function topCandidates(e,useRunoff)
  local t=tally(e,useRunoff)
  return t,t.ranking
end

local function closePresidential(n,state,e,ctx,actor,useRunoff)
  local t,ranking=topCandidates(e,useRunoff)
  if not t.quorumMet then
    e.stage="failed";e.result="no_quorum";return t
  end
  if #ranking==0 then e.stage="failed";e.result="no_valid_vote";return t end

  if useRunoff then
    if #ranking>1 and ranking[1].votes==ranking[2].votes then
      e.stage="failed";e.result="runoff_tie";return t
    end
    e.winners={ranking[1].citizenId};e.result="elected";e.stage="concluded"
    return t
  end

  local valid=0
  for _,row in ipairs(ranking) do valid=valid+row.votes end
  if ranking[1].votes*2>valid then
    e.winners={ranking[1].citizenId};e.result="elected";e.stage="concluded"
  else
    e.stage="runoff_ready";e.result="runoff_required";e.runoffCandidates={}
    for i=1,math.min(2,#ranking) do e.runoffCandidates[#e.runoffCandidates+1]=ranking[i].citizenId end
    if #e.runoffCandidates<2 then e.stage="failed";e.result="no_majority" end
  end
  return t
end

local function closeCouncil(n,state,e,ctx,actor,useRunoff)
  local t,ranking=topCandidates(e,useRunoff)
  if not t.quorumMet then e.stage="failed";e.result="no_quorum";return t end
  local seats=tonumber(e.seats) or 1

  if useRunoff then
    local fixed=copy(e.fixedWinners or {})
    local remaining=tonumber(e.remainingSeats) or math.max(0,seats-#fixed)
    if remaining<=0 then
      e.winners=fixed;e.stage="concluded";e.result="elected";return t
    end
    if #ranking<remaining then e.stage="failed";e.result="insufficient_runoff_candidates";return t end
    local cutoff=ranking[remaining].votes
    if remaining<#ranking and ranking[remaining+1].votes==cutoff then e.stage="failed";e.result="runoff_tie";return t end
    for i=1,remaining do fixed[#fixed+1]=ranking[i].citizenId end
    e.winners=fixed;e.stage="concluded";e.result="elected";return t
  end

  if #ranking<seats then e.stage="failed";e.result="insufficient_candidates";return t end
  local cutoff=ranking[seats].votes
  local fixed,tied={},{}
  for _,row in ipairs(ranking) do
    if row.votes>cutoff then fixed[#fixed+1]=row.citizenId
    elseif row.votes==cutoff then tied[#tied+1]=row.citizenId end
  end
  local remaining=seats-#fixed
  if #tied>remaining then
    e.stage="runoff_ready";e.result="runoff_required";e.fixedWinners=fixed;e.runoffCandidates=tied;e.remainingSeats=remaining
  else
    for _,id in ipairs(tied) do fixed[#fixed+1]=id end
    e.winners=fixed;e.stage="concluded";e.result="elected"
  end
  return t
end

function D.handle(state,actor,action,p,ctx)
  p=p or {}
  local n=state.national
  ensure(n)

  if action=="NC_GE_LIST" then return true,listElections(n,p),nil end
  if action=="NC_GE_GET" then
    local e=n.generalElections[trim(p.id):upper()]
    if not e then return true,nil,"Election nationale introuvable." end
    return true,electionView(n,e),nil
  end
  if action=="NC_MANDATE_LIST" then return true,listMandates(n,p),nil end

  if action=="NC_GE_CREATE" then
    if not manager(actor) then return true,nil,"Creation d'election reservee a la Presidence, au Conseil ou a l'administration technique." end
    local office=p.office=="council" and "council" or "president"
    local seats=office=="council" and math.max(1,math.min(15,tonumber(p.seats) or n.meta.defaultCouncilSeats or 5)) or 1
    local id=nextId(n.generalElectionCounters,"NC-GE")
    local e={
      id=id,office=office,seats=seats,title=trim(p.title)~="" and trim(p.title) or
        (office=="president" and "Election presidentielle" or "Election du Conseil"),
      description=trim(p.description),termLabel=trim(p.termLabel),stage="draft",
      candidates={},eligibleCitizens={},votes={},runoffVotes={},runoffCandidates={},fixedWinners={},winners={},
      createdAt=now(),createdBy=identity(actor)
    }
    e.seal=seal("NC-GE",{e.id,e.office,e.seats,e.title,e.termLabel,e.createdAt,e.createdBy})
    n.generalElections[id]=e
    mutate(ctx,"NC_GE_CREATE",id,e.title.." / "..office)
    return true,electionView(n,e),nil
  end

  if action=="NC_GE_OPEN_CANDIDACY" then
    if not manager(actor) then return true,nil,"Ouverture des candidatures non autorisee." end
    local e=n.generalElections[trim(p.id):upper()]
    if not e then return true,nil,"Election introuvable." end
    if e.stage~="draft" then return true,nil,"Election non ouvrable aux candidatures." end
    e.stage="candidacy";e.candidacyOpenedAt=now();e.candidacyOpenedBy=identity(actor)
    e.candidacySeal=seal("NC-GE-CAND",{e.id,e.seal,e.candidacyOpenedAt,e.candidacyOpenedBy})
    notify(ctx,state,{title="Candidatures nationales ouvertes",body=e.id.." / "..e.title,severity="info",objectType="nc_general_election",objectId=e.id,targetStateId=n.meta.stateId})
    mutate(ctx,"NC_GE_OPEN_CANDIDACY",e.id,e.candidacySeal)
    return true,electionView(n,e),nil
  end

  if action=="NC_GE_REGISTER_CANDIDATE" then
    local e=n.generalElections[trim(p.id):upper()]
    if not e then return true,nil,"Election introuvable." end
    if e.stage~="candidacy" then return true,nil,"Les candidatures ne sont pas ouvertes." end
    local citizenId=trim(p.citizenId):upper()
    if citizenId=="" then citizenId=actor.citizenId or "" end
    if citizenId=="" then return true,nil,"Identite citoyenne requise." end
    if citizenId~=actor.citizenId and not manager(actor) then return true,nil,"Vous ne pouvez enregistrer que votre propre candidature." end
    local cit,err=candidateAllowed(n,state,citizenId,e.office)
    if not cit then return true,nil,err end
    for _,id in ipairs(e.candidates) do if id==citizenId then return true,electionView(n,e),nil end end
    e.candidates[#e.candidates+1]=citizenId
    table.sort(e.candidates)
    e.updatedAt=now()
    mutate(ctx,"NC_GE_REGISTER_CANDIDATE",e.id,citizenId.." / "..citizenName(n,citizenId))
    return true,electionView(n,e),nil
  end

  if action=="NC_GE_WITHDRAW_CANDIDATE" then
    local e=n.generalElections[trim(p.id):upper()]
    if not e then return true,nil,"Election introuvable." end
    if e.stage~="candidacy" then return true,nil,"Retrait de candidature impossible a ce stade." end
    local citizenId=trim(p.citizenId):upper()
    if citizenId=="" then citizenId=actor.citizenId or "" end
    if citizenId~=actor.citizenId and not manager(actor) then return true,nil,"Retrait non autorise." end
    for i=#e.candidates,1,-1 do if e.candidates[i]==citizenId then table.remove(e.candidates,i) end end
    mutate(ctx,"NC_GE_WITHDRAW_CANDIDATE",e.id,citizenId)
    return true,electionView(n,e),nil
  end

  if action=="NC_GE_OPEN_VOTE" then
    if not manager(actor) then return true,nil,"Ouverture du vote non autorisee." end
    local e=n.generalElections[trim(p.id):upper()]
    if not e then return true,nil,"Election introuvable." end
    if e.stage~="candidacy" then return true,nil,"Election hors phase de candidature." end
    local minCandidates=e.office=="president" and 2 or e.seats
    if #e.candidates<minCandidates then return true,nil,"Nombre de candidats insuffisant." end
    e.eligibleCitizens=allActiveCitizens(n)
    if #e.eligibleCitizens==0 then return true,nil,"Aucun citoyen electeur." end
    e.votes={};e.stage="voting";e.voteOpenedAt=now();e.voteOpenedBy=identity(actor)
    e.voteOpenSeal=seal("NC-GE-VOTE",{e.id,e.candidates,e.eligibleCitizens,e.voteOpenedAt,e.voteOpenedBy})
    notifyElectorate(ctx,state,e,"Vote national ouvert",e.id.." / "..e.title,"warning")
    mutate(ctx,"NC_GE_OPEN_VOTE",e.id,e.voteOpenSeal)
    return true,electionView(n,e),nil
  end

  if action=="NC_GE_VOTE" then
    local e=n.generalElections[trim(p.id):upper()]
    if not e then return true,nil,"Election introuvable." end
    if e.stage~="voting" and e.stage~="runoff_voting" then return true,nil,"Le vote n'est pas ouvert." end
    local citizenId=actor.citizenId
    if not activeCitizen(n,citizenId) then return true,nil,"Citoyen actif requis." end
    local eligible=false
    for _,id in ipairs(e.eligibleCitizens or {}) do if id==citizenId then eligible=true break end end
    if not eligible then return true,nil,"Vous ne faites pas partie du corps electoral fige." end

    local choice=trim(p.choice):upper()
    local candidateSet={}
    local candidates=e.stage=="runoff_voting" and (e.runoffCandidates or {}) or (e.candidates or {})
    for _,id in ipairs(candidates) do candidateSet[id]=true end
    if choice~="ABSTAIN" and not candidateSet[choice] then return true,nil,"Choix de candidat invalide." end
    if choice=="ABSTAIN" then choice="abstain" end

    local target=e.stage=="runoff_voting" and e.runoffVotes or e.votes
    target[citizenId]={choice=choice,at=now(),clientId=actor.clientId}
    mutate(ctx,"NC_GE_VOTE",e.id,citizenId.." -> "..choice)
    return true,electionView(n,e),nil
  end

  if action=="NC_GE_CLOSE_VOTE" then
    if not manager(actor) then return true,nil,"Cloture du vote non autorisee." end
    local e=n.generalElections[trim(p.id):upper()]
    if not e then return true,nil,"Election introuvable." end
    local useRunoff=e.stage=="runoff_voting"
    if e.stage~="voting" and not useRunoff then return true,nil,"Aucun vote ouvert." end

    local t
    if e.office=="president" then t=closePresidential(n,state,e,ctx,actor,useRunoff)
    else t=closeCouncil(n,state,e,ctx,actor,useRunoff) end
    if useRunoff then e.runoffClosedAt=now() else e.voteClosedAt=now() end
    e.tally=t
    e.resultSeal=seal("NC-GE-RESULT",{e.id,e.office,e.seats,e.votes,e.runoffVotes,e.result,e.winners,e.fixedWinners,e.voteClosedAt,e.runoffClosedAt})

    if e.stage=="concluded" and e.result=="elected" then
      if e.office=="president" then
        local mandate,err=installPresident(n,state,e,e.winners[1],ctx,actor)
        if not mandate then return true,nil,err end
        e.mandateIds={mandate.id}
      else
        local mandates,err=installCouncil(n,state,e,e.winners,ctx,actor)
        if not mandates then return true,nil,err end
        e.mandateIds={}
        for _,m in ipairs(mandates) do e.mandateIds[#e.mandateIds+1]=m.id end
      end
      local names={}
      for _,id in ipairs(e.winners) do names[#names+1]=citizenName(n,id) end
      notify(ctx,state,{title="Resultat election nationale",body=e.id.." / Elu(s): "..table.concat(names,", "),severity="success",objectType="nc_general_election",objectId=e.id,targetStateId=n.meta.stateId})
      local pub=gazette(ctx,"general_election",e.id,"Resultat - "..e.title,
        "Elu(s): "..table.concat(names,", ")..".",e.resultSeal,"internal")
      e.gazetteId=pub and pub.id or nil
    elseif e.stage=="runoff_ready" then
      notifyElectorate(ctx,state,e,"Second tour requis",e.id.." / "..e.title,"warning")
    else
      notify(ctx,state,{title="Election nationale non conclue",body=e.id.." / "..tostring(e.result),severity="warning",objectType="nc_general_election",objectId=e.id,targetStateId=n.meta.stateId})
    end

    mutate(ctx,"NC_GE_CLOSE_VOTE",e.id,tostring(e.result).." / "..e.resultSeal)
    return true,electionView(n,e),nil
  end

  if action=="NC_GE_OPEN_RUNOFF" then
    if not manager(actor) then return true,nil,"Ouverture du second tour non autorisee." end
    local e=n.generalElections[trim(p.id):upper()]
    if not e then return true,nil,"Election introuvable." end
    if e.stage~="runoff_ready" then return true,nil,"Aucun second tour requis." end
    if #(e.runoffCandidates or {})<2 then return true,nil,"Second tour impossible: candidats insuffisants." end
    e.runoffVotes={};e.stage="runoff_voting";e.runoffOpenedAt=now();e.runoffOpenedBy=identity(actor)
    e.runoffOpenSeal=seal("NC-GE-RUNOFF",{e.id,e.runoffCandidates,e.fixedWinners,e.remainingSeats,e.eligibleCitizens,e.runoffOpenedAt})
    notifyElectorate(ctx,state,e,"Second tour ouvert",e.id.." / "..e.title,"warning")
    mutate(ctx,"NC_GE_OPEN_RUNOFF",e.id,e.runoffOpenSeal)
    return true,electionView(n,e),nil
  end

  if action=="NC_GE_CANCEL" then
    if not manager(actor) then return true,nil,"Annulation non autorisee." end
    local e=n.generalElections[trim(p.id):upper()]
    if not e then return true,nil,"Election introuvable." end
    if e.stage=="concluded" then return true,nil,"Une election conclue ne peut pas etre annulee." end
    local reason=trim(p.reason)
    if reason=="" then return true,nil,"Motif d'annulation obligatoire." end
    e.stage="cancelled";e.cancelReason=reason;e.cancelledAt=now();e.cancelledBy=identity(actor)
    e.cancelSeal=seal("NC-GE-CANCEL",{e.id,reason,e.cancelledAt,e.cancelledBy,e.seal})
    mutate(ctx,"NC_GE_CANCEL",e.id,reason)
    return true,electionView(n,e),nil
  end

  return false,nil,nil
end

return D
