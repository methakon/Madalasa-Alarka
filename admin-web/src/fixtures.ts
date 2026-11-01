// Explicit local preview only; never used as fallback for failed production requests.
import {syntheticId,type AdminRequest,type Audit,type Faq,type Subscriber,type Ticket} from './api';
export const demoRequests:AdminRequest[]=[
{id:syntheticId(1048),applicant_id:syntheticId(101),state:'PENDING_REVIEW',submitted_at:'2026-10-29T10:00:00Z',profile:{full_name:'Example Applicant A',contact_email:'applicant-a@example.invalid'}},
{id:syntheticId(1049),applicant_id:syntheticId(102),state:'PENDING_REVIEW',submitted_at:'2026-10-30T10:00:00Z',profile:{full_name:'Example Applicant B',contact_email:'applicant-b@example.invalid'}}];
export const demoFaqs:Faq[]=[
{id:syntheticId(201),slug:'renewal-guide',title:'How to renew a prepaid plan',category:'Billing',language:'en',safe_body:'The guardian can review available offers in the parent application.',revision:1,status:'DRAFT'},
{id:syntheticId(202),slug:'location-permissions',title:'Understanding location permissions',category:'Setup',language:'en',safe_body:'Check Android settings and the current app permission status.',revision:2,status:'PUBLISHED'}];
export const demoTickets:Ticket[]=[
{id:syntheticId(210),requester_id:syntheticId(301),subject:'Prepaid renewal issue',status:'OPEN',priority:'NORMAL',updated_at:'2026-10-31T07:30:00Z'},
{id:syntheticId(211),requester_id:syntheticId(302),subject:'Device not syncing',status:'PENDING',priority:'NORMAL',updated_at:'2026-10-30T18:00:00Z'},
{id:syntheticId(212),requester_id:syntheticId(303),subject:'Location permission help',status:'RESOLVED',priority:'LOW',updated_at:'2026-10-29T11:00:00Z'}];
export const demoSubscribers:Subscriber[]=[
{family_id:syntheticId(21),paid_children:2,children_total:3,plan_status:'ACTIVE',founding_eligible:true,valid_until:'2027-10-31T00:00:00Z'},
{family_id:syntheticId(22),paid_children:0,children_total:1,plan_status:'FREE',founding_eligible:false}];
export const demoAudit:Audit[]=[
{id:syntheticId(901),action:'ACCESS_REVIEW',outcome:'APPROVED',occurred_at:'2026-10-30T10:10:00Z',actor_ref:'synthetic-owner'},
{id:syntheticId(902),action:'SUPPORT_REPLY',outcome:'DELIVERED',occurred_at:'2026-10-30T08:40:00Z',actor_ref:'synthetic-agent'},
{id:syntheticId(903),action:'CHILD_PRIVATE_DATA_READ',outcome:'DENIED',occurred_at:'2026-10-29T15:20:00Z',actor_ref:'synthetic-agent'}];
