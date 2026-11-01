import {useCallback,useEffect,useMemo,useState,type ReactNode} from 'react';
import {createRoot} from 'react-dom/client';
import {Activity,BookOpen,ChevronRight,ClipboardCheck,Clock3,CreditCard,FileQuestion,Headphones,LayoutDashboard,LockKeyhole,RefreshCw,Search,ShieldCheck,ShieldAlert,Users,UserRound,ArrowRight,LogOut,AlertCircle} from 'lucide-react';
import {request,items,may,onlyServerRoles,ApiError,type AccessState,type Role,type AdminRequest,type Faq,type Ticket,type Subscriber,type Audit,type Page} from './api';
import {demoRequests,demoFaqs,demoTickets,demoSubscribers,demoAudit} from './fixtures';
import './styles.css';

type Section='overview'|'access'|'faqs'|'support'|'subscribers'|'usage'|'security';
const NAV:{key:Section;label:string;icon:typeof LayoutDashboard;role?:Role}[]=[
{key:'overview',label:'Overview',icon:LayoutDashboard},{key:'access',label:'Access requests',icon:Users,role:'ROOT_OWNER'},
{key:'faqs',label:'FAQ pages',icon:BookOpen,role:'FAQ_EDITOR'},{key:'support',label:'Support tickets',icon:Headphones,role:'SUPPORT_AGENT'},
{key:'subscribers',label:'Subscribers & billing',icon:CreditCard,role:'BILLING_VIEWER'},
{key:'usage',label:'Parent usage logs',icon:Activity,role:'USAGE_AUDITOR'},
{key:'security',label:'Audit & security',icon:ShieldCheck,role:'ROOT_OWNER'}];
const PREVIEW=import.meta.env.VITE_ADMIN_SYNTHETIC_PREVIEW==='true'&&import.meta.env.DEV;
const titles:Record<Section,string>={overview:'Super Admin · overview and access security',access:'Owner · review access requests',faqs:'FAQ pages · content management',support:'Support requests · conversation',subscribers:'Subscribers · plans and payments',usage:'Parent service usage',security:'Audit & access security'};
const subtitles:Record<Section,string>={overview:'Owner manages approval, FAQ, support, billing visibility and audit—not unrestricted child data.',access:'Only the verified owner can approve administrator access and assign roles.',faqs:'Edit helpful public content with revision checks and publication controls.',support:'Authorized staff reply only to approved ticket-scoped conversations.',subscribers:'Subscription and masked payment metadata only. No payment credentials.',usage:'Parent service-event metadata; no child GPS, media or screen content.',security:'Least privilege, audit trails and protected staff access.'};

function Box({title,children,soft=false,warn=false}: {title:string;children:ReactNode;soft?:boolean;warn?:boolean}){return <section className={'panel'+(soft?' soft':'')+(warn?' warn':'')}><h2>{title}</h2>{children}</section>;}
function Button({children,onClick,disabled=false,kind='primary'}:{children:ReactNode;onClick:()=>void;disabled?:boolean;kind?:'primary'|'secondary'|'danger'}){return <button className={'btn '+kind} disabled={disabled} onClick={onClick}>{children}</button>;}
function Label({children}: {children:ReactNode}){return <span className="chip">{children}</span>}
function Empty({text}: {text:string}){return <div className="empty"><FileQuestion size={28}/><p>{text}</p></div>}
function NoAccess({message}:{message:string}){return <main className="auth-layout"><div className="auth-card"><div className="brand-mark"><ShieldCheck/></div><p className="overline">MADALASA · ADMINISTRATION</p><h1>Secure administrator access</h1><p>{message}</p><div className="notice"><LockKeyhole size={18}/> Google sign-in requires a configured, server-verified admin OIDC exchange, session, and access policy. This UI cannot grant roles.</div><p className="fine">No child location, monitoring data or recordings are available in this console.</p></div></main>}

type Data={requests:AdminRequest[];faqs:Faq[];tickets:Ticket[];subscribers:Subscriber[];audit:Audit[]};
const empty:Data={requests:[],faqs:[],tickets:[],subscribers:[],audit:[]};
function useAdminData(section:Section,allowed:boolean,preview:boolean){
 const [data,setData]=useState<Data>(empty);const [loading,setLoading]=useState(false);const [error,setError]=useState<string|null>(null);
 const load=useCallback(async()=>{
  if(!allowed){setData(empty);return;}
  if(preview){setData({requests:demoRequests,faqs:demoFaqs,tickets:demoTickets,subscribers:demoSubscribers,audit:demoAudit});setError(null);return;}
  setLoading(true);setError(null);setData(empty);
  const path:Record<Section,string|undefined>={overview:undefined,access:'/admin/owner/access-requests',faqs:'/admin/faqs',support:'/admin/support/tickets',subscribers:'/admin/subscribers',usage:'/admin/usage/parents',security:'/admin/security/audit'};
  try{
   if(section==='overview'){setData(empty);return;}
   const endpoint=path[section];if(!endpoint)return;
   const response=await request<Page<unknown>|unknown[]>(endpoint);
   // Validate only the fields rendered, and never infer a record from malformed replies.
   const list=items(response as Page<unknown>);
   const next:Data={...empty};
   if(section==='access')next.requests=list.filter(x=>typeof x==='object'&&x!==null&&'id' in x&&'state' in x) as AdminRequest[];
   if(section==='faqs')next.faqs=list.filter(x=>typeof x==='object'&&x!==null&&'id' in x&&'revision' in x) as Faq[];
   if(section==='support')next.tickets=list.filter(x=>typeof x==='object'&&x!==null&&'id' in x&&'subject' in x) as Ticket[];
   if(section==='subscribers')next.subscribers=list.filter(x=>typeof x==='object'&&x!==null&&'family_id' in x) as Subscriber[];
   if(section==='security')next.audit=list.filter(x=>typeof x==='object'&&x!==null&&'id' in x&&'action' in x) as Audit[];
   setData(next);
  }catch(e){setError(e instanceof Error?e.message:'Unknown API failure');setData(empty);}finally{setLoading(false);}
 },[section,allowed,preview]);
 useEffect(()=>{void load();},[load]);
 return {data,error,loading,refresh:load};
}
function App(){
 const [section,setSection]=useState<Section>('overview');
 const [auth,setAuth]=useState<'checking'|'signed-out'|'active'|'applicant'>(PREVIEW?'active':'checking');
 const [roles,setRoles]=useState<Role[]>(PREVIEW?['ROOT_OWNER']:[]);
 const [access,setAccess]=useState<AccessState|null>(null);
 const [sessionError,setSessionError]=useState('');
 const [menuOpen,setMenuOpen]=useState(false);
 const allowed=PREVIEW||auth==='active';
 useEffect(()=>{if(PREVIEW)return;let active=true;request<AccessState>('/admin/access/me').then(s=>{if(!active)return;setAccess(s);setAuth('applicant');}).catch(e=>{if(!active)return;setAuth('signed-out');setSessionError(e instanceof ApiError&&e.status===401?'Sign in is required.':'Admin authentication backend is not yet available.');});return()=>{active=false};},[]);
 const available=useMemo(()=>NAV.filter(x=>!x.role||may(roles,x.role)),[roles]);
 const permitted=available.some(x=>x.key===section);
 const {data,error,loading,refresh}=useAdminData(section,permitted&&allowed,PREVIEW);
 const [query,setQuery]=useState('');const [selected,setSelected]=useState('');
 const [draft,setDraft]=useState({slug:'',title:'',category:'General',safe_markdown:''});
 const [busy,setBusy]=useState(false);const [actionError,setActionError]=useState('');const [actionMessage,setActionMessage]=useState('');
 const act=async(path:string,method:'POST'|'PUT'|'PATCH',body:unknown)=>{
  if(PREVIEW){setActionMessage('Synthetic preview only — no changes were sent.');return;}
  setBusy(true);setActionError('');setActionMessage('');
  try{await request(path,{method,body});setActionMessage('Server confirmed the update.');await refresh();}
  catch(e){setActionError(e instanceof Error?e.message:'Action failed; no success assumed');}finally{setBusy(false);}
 };
 if(auth==='checking')return <NoAccess message="Checking administrator session…"/>;
 if(auth==='signed-out')return <GoogleEntry error={sessionError} onApproved={async(idToken,nonce,csrfState)=>{
   try{
     const result=await request<{state:string;role_codes?:string[];session_expires_at:string;contact_email_verified:boolean}>('/admin/auth/google',{method:'POST',body:{id_token:idToken,nonce,csrf_state:csrfState}});
     const validated=await request<AccessState>('/admin/access/me');
     const nextRoles=onlyServerRoles(result.role_codes);
     setAccess(validated);
     if(result.state==='ACTIVE'&&validated.state==='APPROVED'&&nextRoles.length){
       setRoles(nextRoles);setAuth('active');setSessionError('');
     }else{setRoles([]);setAuth('applicant');}
   }catch(e){setSessionError(e instanceof Error?e.message:'Authentication failed');setAuth('signed-out');}
 }}/>
 if(auth==='applicant')return <Applicant access={access} onRefresh={()=>{void request<AccessState>('/admin/access/me').then(setAccess).catch(()=>setSessionError('Unable to refresh application status'));}} error={sessionError}/>;
 const accessLocked=(!permitted||!allowed);
 return <div className="app-shell">
  <aside className={'sidebar '+(menuOpen?'open':'')}>
   <div className="brand"><div className="brand-icon"><ShieldCheck size={22}/></div><div><strong>MADALASA</strong><span>ADMINISTRATION</span></div></div>
   <div className="access-state"><div className="overline">ACCESS STATE</div><strong>{PREVIEW?'SYNTHETIC ROOT_OWNER':roles.join(' · ')||'NO ROLE'}</strong><small>Role-scoped operations</small></div>
   <nav aria-label="Admin navigation">{available.map(({key,label,icon:Icon})=><button key={key} className={'nav-link '+(section===key?'active':'')} onClick={()=>{setSection(key);setSelected('');setQuery('');setActionError('');setActionMessage('');setMenuOpen(false);}}><Icon size={18}/><span>{label}</span><ChevronRight size={15} className="nav-chevron"/></button>)}</nav>
   <div className="sidebar-foot"><LockKeyhole size={16}/><span>CHILD PRIVACY WALL ACTIVE</span></div>
  </aside>
  <main className="main">
   <header className="topbar"><button className="menu-toggle" onClick={()=>setMenuOpen(x=>!x)} aria-label="Toggle menu">☰</button><span>Operations workspace</span><div className="top-actions"><Label>{PREVIEW?'SYNTHETIC PREVIEW':'SERVER AUTHENTICATED'}</Label><button className="icon-button" aria-label="Refresh" onClick={()=>void refresh()}><RefreshCw size={18}/></button><button className="icon-button" aria-label="Leave console" onClick={()=>{setAuth('signed-out');setRoles([]);setAccess(null);}}><LogOut size={18}/></button></div></header>
   <div className="content"><div className="page-heading"><div><div className="breadcrumb">Administration <span>/</span> {section}</div><h1>{titles[section]}</h1><p>{subtitles[section]}</p></div><Label>{PREVIEW?'NOT LIVE':'PROTECTED'}</Label></div>
   {PREVIEW&&<div className="preview-note"><AlertCircle size={18}/> <span>Invented example accounts, tickets and subscriptions. No real records are accessed and all mutations are disabled.</span></div>}
   {error&&<div className="error-note" role="alert">{error}. No cached or fabricated live results shown.</div>}
   {actionError&&<div className="error-note" role="alert">{actionError}</div>}{actionMessage&&<div className="success-note" role="status">{actionMessage}</div>}
   {loading&&<p className="subtle">Loading authorized records…</p>}
   {accessLocked?<Empty text="This role cannot access this module."/>:
   section==='overview'?<div className="grid two">
      <Box title="Admin operations summary" soft><div className="metric-grid"><div className="metric"><strong>{PREVIEW?data.requests.length:'—'}</strong><span>Access applications</span></div><div className="metric"><strong>{PREVIEW?data.tickets.length:'—'}</strong><span>Support tickets</span></div><div className="metric"><strong>{PREVIEW?data.faqs.filter(f=>f.status==='DRAFT').length:'—'}</strong><span>FAQ drafts</span></div></div><p className="fine">Live overview metrics require authorized aggregation endpoints; no numbers are inferred from partial data.</p></Box>
      <Box title="Assigned privileges"><div className="record"><ShieldCheck size={22}/><div><strong>{roles.join(' · ')||'No roles'}</strong><p>Roles are derived only from the authoritative admin service. No UI role escalation.</p></div></div><div className="line">Manage content and service operations within assigned scope.</div><div className="line">Children's private data remains inaccessible by default.</div></Box>
      <Box title="Recent security events"><p>View access decisions, denials and audited administrative actions in the security module.</p><Button kind="secondary" onClick={()=>setSection('security')} disabled={!may(roles,'ROOT_OWNER')}>View audit <ArrowRight size={16}/></Button></Box>
      <Box title="Staff and controls" warn><p>MFA, short-lived sessions, revocable roles and scoped access are required on the server.</p><p>Exports, live GPS, audio, video, and screen captures are not exposed by this panel.</p><Button kind="secondary" onClick={()=>setSection('access')} disabled={!may(roles,'ROOT_OWNER')}>Review access requests</Button></Box>
    </div>:
   section==='access'?<div className="grid layout-split"><Box title={'Access Requests · '+data.requests.length+' visible'}>
      <SearchField query={query} setQuery={setQuery} placeholder="Search request / applicant"/>
      <div className="record-list">{data.requests.filter(x=>JSON.stringify(x).toLowerCase().includes(query.toLowerCase())).map(x=><button className={'record selectable '+(selected===x.id?'selected':'')} key={x.id} onClick={()=>setSelected(x.id)}><span className="avatar"><UserRound size={17}/></span><span><strong>{x.profile?.full_name||'Applicant'}</strong><small>{x.id.slice(0,8)} · {x.state}</small></span><ChevronRight size={16}/></button>)}</div>
      {!data.requests.length&&<Empty text="No authorized access applications returned."/>}
    </Box><Box title="Decide & assign roles">
      {data.requests.find(x=>x.id===selected)?<RequestDecision entry={data.requests.find(x=>x.id===selected)!} onDecision={(body)=>void act('/admin/owner/access-requests/'+selected+'/decision','POST',body)} busy={busy} preview={PREVIEW}/>:<Empty text="Select an application to inspect and decide."/>}
      <div className="notice"><LockKeyhole size={17}/> Only ROOT_OWNER with server-verified step-up may approve or reject access. Applicant cannot choose a role.</div>
    </Box></div>:
   section==='faqs'?<div className="grid layout-split"><Box title="FAQ pages · search + categories"><SearchField query={query} setQuery={setQuery} placeholder="Search FAQ title"/><div className="record-list">{data.faqs.filter(x=>x.title.toLowerCase().includes(query.toLowerCase())).map(f=><button key={f.id} className={'record selectable '+(selected===f.id?'selected':'')} onClick={()=>{setSelected(f.id);setDraft({slug:f.slug,title:f.title,category:f.category||'General',safe_markdown:f.safe_body});}}><span className="avatar"><BookOpen size={17}/></span><span><strong>{f.title}</strong><small>{f.category||'General'} · {f.status} · rev {f.revision}</small></span></button>)}</div>{!data.faqs.length&&<Empty text="No published/draft FAQ records available."/>}</Box><Box title="FAQ editor"><label>Slug<input value={draft.slug} maxLength={150} onChange={e=>setDraft({...draft,slug:e.target.value})}/></label><label>Title<input value={draft.title} maxLength={220} onChange={e=>setDraft({...draft,title:e.target.value})}/></label><label>Category<input value={draft.category} maxLength={100} onChange={e=>setDraft({...draft,category:e.target.value})}/></label><label>Public safe Markdown<textarea rows={5} maxLength={10000} value={draft.safe_markdown} onChange={e=>setDraft({...draft,safe_markdown:e.target.value})}/></label><div className="button-row"><Button disabled={busy||!draft.title||!draft.slug||!draft.safe_markdown||PREVIEW} onClick={()=>void act(selected?'/admin/faqs/'+selected:'/admin/faqs',selected?'PUT':'POST',{...draft,language:'en',expected_revision:data.faqs.find(x=>x.id===selected)?.revision||0})}>Save draft</Button><Button kind="secondary" disabled={busy||!selected||PREVIEW} onClick={()=>void act('/admin/faqs/'+selected+'/publish','POST',{revision_id:selected,expected_revision:data.faqs.find(x=>x.id===selected)?.revision||0,request_id:crypto.randomUUID()})}>Publish</Button></div><p className="fine">Publishing requires server-side sanitization, revision validation and authorized role.</p></Box></div>:
   section==='support'?<div className="grid layout-split"><Box title="Support inbox"><SearchField query={query} setQuery={setQuery} placeholder="Search support tickets"/><div className="record-list">{data.tickets.filter(x=>x.subject.toLowerCase().includes(query.toLowerCase())).map(t=><button key={t.id} className={'record selectable '+(selected===t.id?'selected':'')} onClick={()=>setSelected(t.id)}><span className="avatar"><Headphones size={17}/></span><span><strong>{t.subject}</strong><small>{t.status} · {t.priority||'NORMAL'}</small></span></button>)}</div>{!data.tickets.length&&<Empty text="No ticket-scoped support records returned."/>}</Box><SupportReply selected={selected} ticket={data.tickets.find(t=>t.id===selected)} preview={PREVIEW} busy={busy} act={act}/></div>:
   section==='subscribers'?<div className="grid layout-split"><Box title="Subscriber ledger"><SearchField query={query} setQuery={setQuery} placeholder="Search family ID"/>{data.subscribers.filter(x=>x.family_id.includes(query)).map(x=><button className={'record selectable '+(selected===x.family_id?'selected':'')} key={x.family_id} onClick={()=>setSelected(x.family_id)}><span className="avatar"><CreditCard size={17}/></span><span><strong>{x.family_id.slice(0,8)}…{x.family_id.slice(-5)}</strong><small>{x.plan_status} · {x.paid_children}/{x.children_total} paid children</small></span></button>)}{!data.subscribers.length&&<Empty text="No authorized subscription metadata returned."/>}</Box><Box title="Subscription & payment summary">{selected?<><p>Family reference: <code>{selected}</code></p><p>Paid seats: {data.subscribers.find(x=>x.family_id===selected)?.paid_children}</p><p>Plan: {data.subscribers.find(x=>x.family_id===selected)?.plan_status}</p><p className="fine">Masked payments and entitlements must be fetched only after server authorization; no raw payment instruments.</p><Button kind="secondary" onClick={()=>setActionMessage('Payment drill-down requires the verified billing API and appropriate server role.')} >Payment details</Button></>:<Empty text="Choose a subscriber account."/>}</Box></div>:
   section==='usage'?<div className="grid two"><Box title="Parent usage summary"><p>Usage reports are restricted to parent service events (feature requests, time, delivery status).</p><Empty text={PREVIEW?'Synthetic preview intentionally excludes detailed usage logs.':'Parent service event endpoint needs a real authorized implementation.'}/></Box><Box title="Child privacy wall" warn><ShieldAlert size={30}/><p>No child location history, private media, screen capture, or device secret appears in admin usage reporting.</p></Box></div>:
   <div className="grid two"><Box title="Recent security events"><div className="record-list">{data.audit.map(a=><div className="record" key={a.id}><span className="avatar"><ClipboardCheck size={17}/></span><span><strong>{a.action}</strong><small>{a.outcome} · {a.occurred_at}</small></span></div>)}</div>{!data.audit.length&&<Empty text="No authorized audit events returned."/>}</Box><Box title="Staff and controls" warn><p>Role provisioning is enforced by the owner-controlled backend. Google sign-in alone is not an administrator grant.</p><div className="line"><Clock3 size={16}/> Session expiration and step-up checks are server-owned.</div><div className="line"><LockKeyhole size={16}/> Access to child private-data is prohibited by default.</div></Box></div>}
   <footer className="footer">Madalasa–Alarka · Administrative operations · No direct access to children's private data</footer>
   </div>
  </main>
 </div>;
}
function SearchField({query,setQuery,placeholder}:{query:string;setQuery:(v:string)=>void;placeholder:string}){return <div className="search"><Search size={17}/><input value={query} onChange={e=>setQuery(e.target.value)} placeholder={placeholder} aria-label={placeholder}/></div>;}
function RequestDecision({entry,onDecision,busy,preview}:{entry:AdminRequest;onDecision:(v:object)=>void;busy:boolean;preview:boolean}){
 const [role,setRole]=useState<'FAQ_EDITOR'|'SUPPORT_AGENT'|'BILLING_VIEWER'|'USAGE_AUDITOR'>('SUPPORT_AGENT');
 const [reason,setReason]=useState('');return <div><p><strong>{entry.profile?.full_name||'Applicant'}</strong></p><p className="subtle">{entry.profile?.contact_email||'No verified contact displayed'}</p><p>Request: <code>{entry.id}</code></p><p>Status: <Label>{entry.state}</Label></p><label>Assigned role<select value={role} onChange={e=>setRole(e.target.value as typeof role)}><option>FAQ_EDITOR</option><option>SUPPORT_AGENT</option><option>BILLING_VIEWER</option><option>USAGE_AUDITOR</option></select></label><label>Reason<textarea rows={3} maxLength={500} value={reason} onChange={e=>setReason(e.target.value)}/></label><div className="button-row"><Button disabled={preview||busy||!reason.trim()||entry.state!=='PENDING_REVIEW'} onClick={()=>onDecision({decision:'APPROVE',role_codes:[role],reason,expected_revision:0})}>Approve</Button><Button kind="danger" disabled={preview||busy||!reason.trim()||entry.state!=='PENDING_REVIEW'} onClick={()=>onDecision({decision:'REJECT',role_codes:[],reason,expected_revision:0})}>Reject</Button></div><p className="fine">Requires authoritative revision, verified owner MFA and audit. In preview, no action is sent.</p></div>;
}
function SupportReply({ticket,selected,preview,busy,act}:{ticket:Ticket|undefined;selected:string;preview:boolean;busy:boolean;act:(path:string,method:'POST'|'PUT'|'PATCH',body:unknown)=>Promise<void>}){
 const [message,setMessage]=useState('');return <Box title={ticket?'Ticket conversation · '+ticket.subject:'Ticket conversation'}>{!ticket?<Empty text="Choose a ticket to inspect authorized messages."/>:<><p>Status: <Label>{ticket.status}</Label></p><p className="fine">Ticket messages are independently restricted; never infer message text from the summary.</p><label>Reply<textarea rows={5} value={message} maxLength={5000} onChange={e=>setMessage(e.target.value)} placeholder="Write an authorized support response…"/></label><div className="button-row"><Button disabled={preview||busy||!message.trim()} onClick={()=>{void act('/admin/support/tickets/'+selected+'/reply','POST',{body:message,request_id:crypto.randomUUID()});}}>Send reply</Button></div><div className="notice"><LockKeyhole size={18}/> Child GPS, private recordings and screen captures cannot be attached by default.</div></>}</Box>;
}
function GoogleEntry({error,onApproved}:{error:string;onApproved:(idToken:string,nonce:string,csrfState:string)=>Promise<void>}){
 const clientId=import.meta.env.VITE_ADMIN_GOOGLE_CLIENT_ID as string|undefined;
 const [root,setRoot]=useState<HTMLDivElement|null>(null);
 const [status,setStatus]=useState('');
 useEffect(()=>{
   if(!root||!clientId)return;
   // The backend must deliver a CSRF meta-token in the protected same-origin
   // HTML bootstrap and independently verify OIDC issuer, audience, expiry,
   // email_verified, nonce, subject and session authorization.
   if(!document.querySelector('meta[name="csrf-token"]')){setStatus('Admin session bootstrap is not configured: Google login disabled.');return;}
   const nonce=crypto.randomUUID()+crypto.randomUUID();
   const csrfState=crypto.randomUUID()+crypto.randomUUID();
   const script=document.createElement('script');
   script.src='https://accounts.google.com/gsi/client';script.async=true;
   script.onload=()=>{
     const google=(window as Window&{google?:{accounts:{id:{initialize:(args:object)=>void;renderButton:(el:HTMLElement,opts:object)=>void}}}}).google;
     if(!google){setStatus('Google Identity Services could not initialize.');return;}
     google.accounts.id.initialize({client_id:clientId,nonce,auto_select:false,callback:(value:{credential?:string})=>{
       if(value.credential)void onApproved(value.credential,nonce,csrfState);
     }});
     google.accounts.id.renderButton(root,{theme:'outline',size:'large',text:'continue_with',width:270});
   };
   script.onerror=()=>setStatus('Google Identity Services unavailable.');
   document.head.appendChild(script);
   return ()=>{script.remove();};
 },[root,clientId,onApproved]);
 return <main className="auth-layout"><div className="auth-card"><div className="brand-mark"><ShieldCheck/></div><p className="overline">MADALASA · ADMINISTRATION</p><h1>Welcome to the secure administration portal</h1><p>Continue with Google. Only a verified owner can approve staff and assign roles. An applicant may only access their own application status.</p><div ref={setRoot} className="google-button"/>{(!clientId||!root)&&<div className="notice"><LockKeyhole size={17}/> Google admin login is unavailable until the approved OAuth client and secure admin backend are configured.</div>}{status&&<div className="notice">{status}</div>}{error&&<div className="error-note" role="alert">{error}</div>}<p className="fine">Google sign-in alone does not grant administrative access, billing visibility or access to child data.</p></div></main>;
}
function Applicant({access,onRefresh,error}:{access:AccessState|null;onRefresh:()=>void;error:string}){
 const [fullName,setFullName]=useState(''),[email,setEmail]=useState(''),[address,setAddress]=useState(''),[gender,setGender]=useState(''),[dob,setDob]=useState('');
 const [revision]=useState(0),[busy,setBusy]=useState(false),[message,setMessage]=useState(''),[problem,setProblem]=useState('');
 const [challenge,setChallenge]=useState(''),[code,setCode]=useState('');
 const act=async(path:string,method:'PUT'|'POST',body:unknown)=>{
   setBusy(true);setProblem('');setMessage('');
   try{await request(path,{method,body});setMessage('Server acknowledged this step.');onRefresh();}
   catch(e){setProblem(e instanceof Error?e.message:'Request rejected');}
   finally{setBusy(false);}
 };
 const pending=access?.state==='PENDING_REVIEW';
 return <main className="auth-layout"><div className="auth-card applicant-card">
 <div className="brand-mark"><UserRound/></div><p className="overline">BO-02 / BO-02V / BO-03 · ADMIN ACCESS</p>
 <h1>{pending?'Your access application is awaiting review':'Complete your verified applicant profile'}</h1>
 <p>Application state: <strong>{access?.state||'UNKNOWN'}</strong>. Only your own application is visible before owner approval.</p>
 {error&&<div className="error-note">{error}</div>}{problem&&<div className="error-note">{problem}</div>}{message&&<div className="success-note">{message}</div>}
 {!pending&&<><div className="notice"><LockKeyhole size={18}/> Name and contact email are required by the proposed contract. Date of birth, postal address and gender remain optional unless separately justified by approved privacy policy.</div>
 <label>Full name<input value={fullName} onChange={e=>setFullName(e.target.value)} maxLength={150} autoComplete="name"/></label>
 <label>Contact email<input type="email" value={email} onChange={e=>setEmail(e.target.value)} autoComplete="email"/></label>
 <label>Postal address (optional)<textarea rows={2} value={address} onChange={e=>setAddress(e.target.value)} maxLength={600}/></label>
 <div className="grid two"><label>Date of birth (optional)<input type="date" value={dob} onChange={e=>setDob(e.target.value)}/></label><label>Gender (optional)<select value={gender} onChange={e=>setGender(e.target.value)}><option value="">Prefer not to specify</option><option>Female</option><option>Male</option><option>Non-binary</option><option>Self-describe</option><option>Prefer not to say</option></select></label></div>
 <div className="button-row"><Button disabled={busy||!fullName.trim()||!email.includes('@')} onClick={()=>void act('/admin/access/profile','PUT',{full_name:fullName.trim(),contact_email:email.trim(),postal_address:address,date_of_birth:dob||undefined,gender:gender||undefined,privacy_notice_version:'admin-access-draft-2026-10'})}>Save profile</Button>
 <Button kind="secondary" disabled={busy||!email.includes('@')} onClick={()=>void act('/admin/access/verify-email','POST',{contact_email:email.trim()})}>Verify email</Button></div>
 <p className="fine">The backend must create the email challenge and validate verified Google email server-side; the UI cannot self-certify.</p>
 <label>Verification challenge ID<input value={challenge} onChange={e=>setChallenge(e.target.value)} placeholder="Server-provided UUID"/></label><label>One-time code<input value={code} onChange={e=>setCode(e.target.value)} autoComplete="one-time-code"/></label>
 <Button kind="secondary" disabled={busy||!challenge||code.length<6} onClick={()=>void act('/admin/access/confirm-email','POST',{challenge_id:challenge,one_time_code:code})}>Confirm email</Button>
 <div className="line">Server email verification: <strong>{access?.email_verified?'VERIFIED':'NOT VERIFIED'}</strong></div>
 <Button disabled={busy||!access?.email_verified||revision<1||!(access.allowed_actions||[]).includes('REQUEST_ACCESS')} onClick={()=>void act('/admin/access/requests','POST',{profile_revision:revision,privacy_notice_version:'admin-access-draft-2026-10',request_id:crypto.randomUUID()})}>Request access</Button>
 <p className="fine">Request remains disabled until server-authorized profile revision, verified contact email and accepted privacy notice. No role may be selected by an applicant.</p>
 <label>Verified profile revision (server-supplied only)<input value={revision||''} readOnly placeholder="Awaiting server profile revision"/></label>
 </>}
 <div className="button-row"><Button onClick={onRefresh} kind="secondary">Refresh application status</Button></div>
 <p className="fine">No subscriber data or children’s private records are visible before authorized staff approval.</p>
 </div></main>;
}

createRoot(document.getElementById('root')!).render(<App/>);
