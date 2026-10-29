import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"content-type,x-device-id,x-device-key"};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json"}});
const sha256=async(s:string)=>{const b=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(s));return [...new Uint8Array(b)].map(x=>x.toString(16).padStart(2,'0')).join('');};
const valid=(n:unknown,min:number,max:number)=>typeof n==='number'&&Number.isFinite(n)&&n>=min&&n<=max;

Deno.serve(async(req)=>{if(req.method==='OPTIONS')return new Response('ok',{headers:cors});if(req.method!=='POST')return json({error:'POST required'},405);try{
 const id=req.headers.get('x-device-id')||'',key=req.headers.get('x-device-key')||'';if(!id||key.length<16)return json({error:'Invalid device credentials'},401);
 const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
 const {data:device}=await admin.from('devices').select('id,enabled').eq('device_code',id).maybeSingle();if(!device||!device.enabled)return json({error:'Device is not enabled'},403);
 const {data:credential}=await admin.from('device_credentials').select('token_hash').eq('device_id',device.id).maybeSingle();if(!credential||credential.token_hash!==await sha256(key))return json({error:'Invalid device credentials'},401);
 const body=await req.json();if(JSON.stringify(body).length>16000)return json({error:'Payload too large'},413);
 if(typeof body.boot_id!=='string'||typeof body.sequence!=='number'||!Number.isInteger(body.sequence)||body.sequence<0)return json({error:'Invalid sample identity'},422);
 if(body.temperature_c!==undefined&&!valid(body.temperature_c,-80,150))return json({error:'Invalid temperature'},422);if(body.ph!==undefined&&!valid(body.ph,0,14))return json({error:'Invalid pH'},422);if(body.voltage_v!==undefined&&!valid(body.voltage_v,0,60))return json({error:'Invalid voltage'},422);
 const row={device_id:device.id,boot_id:body.boot_id,sequence:body.sequence,measured_at:body.measured_at||null,temperature_c:body.temperature_c??null,ph:body.ph??null,voltage_v:body.voltage_v??null,status:String(body.status||'RUNNING').slice(0,32)};
 const {data:inserted,error}=await admin.from('telemetry').upsert(row,{onConflict:'device_id,boot_id,sequence',ignoreDuplicates:true}).select('id').maybeSingle();if(error)throw error;
 const {data:latest}=await admin.from('device_latest').select('received_at').eq('device_id',device.id).maybeSingle();const received=new Date().toISOString();if(!latest||!row.measured_at||new Date(row.measured_at)>=new Date(latest.received_at)){await admin.from('device_latest').upsert({...row,received_at:received},{onConflict:'device_id'});}
 return json({success:true,accepted:inserted?1:0,duplicates:inserted?0:1});
}catch(e){return json({error:e instanceof Error?e.message:'Server error'},500)}});
