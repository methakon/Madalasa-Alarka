// Typed adapter for the planned admin OpenAPI contract. No client-made role authority.
export type LoginResult={state:'NO_ACCESS'|'ACTIVE'|'PENDING_REVIEW'|'SUSPENDED';session_expires_at:string;role_codes?:string[];contact_email_verified:boolean};
export type AccessState={state:'NO_ACCESS'|'EMAIL_PENDING'|'PENDING_REVIEW'|'APPROVED'|'REJECTED'|'SUSPENDED';email_verified:boolean;allowed_actions:string[];request_id?:string|null};
export type Page<T>={items:T[];next_cursor?:string|null;as_of?:string};
export type AdminRequest={id:string;applicant_id:string;state:string;submitted_at:string;assigned_roles?:string[];profile?:{full_name?:string;contact_email?:string}};
export type Faq={id:string;slug:string;title:string;safe_body:string;category?:string;language?:string;revision:number;status:'DRAFT'|'PUBLISHED'|'ARCHIVED'};
export type Ticket={id:string;requester_id:string;subject:string;status:string;priority?:string;updated_at:string};
export type Subscriber={family_id:string;paid_children:number;children_total:number;plan_status:string;founding_eligible?:boolean;valid_until?:string|null};
export type Audit={id:string;actor_ref?:string;action:string;outcome:string;occurred_at:string;request_id?:string};
export type Role='ROOT_OWNER'|'FAQ_EDITOR'|'SUPPORT_AGENT'|'BILLING_VIEWER'|'USAGE_AUDITOR';
export class ApiError extends Error{constructor(public status:number,message:string){super(message);this.name='ApiError';}}
const roots=['/admin/access/me','/admin/access/profile','/admin/access/requests/me','/admin/access/requests','/admin/access/verify-email','/admin/access/confirm-email','/admin/auth/google','/admin/owner/','/admin/faqs','/admin/support/','/admin/subscribers','/admin/usage/parents','/admin/security/','/admin/billing/'];
export function safePath(path:string):string{
 if(!path.startsWith('/admin/')||!roots.some(r=>path===r||path.startsWith(r+'/')||(r.endsWith('/')&&path.startsWith(r))))throw new Error('Non-admin API path blocked');
 if(/[?#]/.test(path)||path.includes('..')||path.includes('//')||/[%\\]/.test(path))throw new Error('Unsafe API path');
 return path;
}
export function onlyServerRoles(v:unknown):Role[]{if(!Array.isArray(v))return [];const a:Role[]=['ROOT_OWNER','FAQ_EDITOR','SUPPORT_AGENT','BILLING_VIEWER','USAGE_AUDITOR'];return v.filter((x):x is Role=>a.includes(x as Role));}
export function may(roles:Role[],role:Role){return roles.includes('ROOT_OWNER')||roles.includes(role);}
function csrf(){return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content||'';}
export async function request<T>(path:string,opts:{method?:'GET'|'POST'|'PUT'|'PATCH';body?:unknown;query?:Record<string,string|number|undefined>}={},signal?:AbortSignal):Promise<T>{
 const url=new URL('/v1'+safePath(path),location.origin);Object.entries(opts.query||{}).forEach(([k,v])=>{if(v!==undefined)url.searchParams.set(k,String(v));});
 const method=opts.method||'GET';
 if(method!=='GET'&&!csrf())throw new ApiError(403,'Admin CSRF token unavailable: action blocked');
 const response=await fetch(url.toString(),{method,credentials:'same-origin',cache:'no-store',signal,
  headers:{Accept:'application/json',...(method==='GET'?{}:{'Content-Type':'application/json','X-CSRF-Token':csrf()})},
  ...(opts.body===undefined?{}:{body:JSON.stringify(opts.body)})});
 if(!response.ok){let message='Admin API unavailable or access denied';try{const data=await response.json() as {message?:string};if(data.message)message=data.message;}catch{}throw new ApiError(response.status,message);}
 if(response.status===204)return undefined as T;
 if(!(response.headers.get('content-type')||'').includes('application/json'))throw new ApiError(502,'Unexpected response content type');
 return await response.json() as T;
}
export function items<T>(v:Page<T>|T[]|undefined):T[]{return Array.isArray(v)?v:(v?.items||[]);}
export function syntheticId(n:number){return '00000000-0000-4000-8000-'+n.toString().padStart(12,'0');}
