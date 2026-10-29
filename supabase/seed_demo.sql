-- Run in Supabase SQL Editor after applying 001_schema.sql.
insert into public.organizations(id,name) values ('11111111-1111-1111-1111-111111111111','Demo Customer') on conflict do nothing;
insert into public.devices(id,organization_id,device_code,name,enabled) values
('22222222-2222-2222-2222-222222222221','11111111-1111-1111-1111-111111111111','ESP32-001','Water Quality Sensor',true),
('22222222-2222-2222-2222-222222222222','11111111-1111-1111-1111-111111111111','ESP32-002','Tank Temperature Sensor',true) on conflict do nothing;
insert into public.device_latest(device_id,received_at,measured_at,temperature_c,ph,voltage_v,status) values
('22222222-2222-2222-2222-222222222221',now(),now(),28.65,7.12,3.285,'RUNNING'),
('22222222-2222-2222-2222-222222222222',now(),now(),24.40,6.88,3.301,'RUNNING') on conflict(device_id) do update set received_at=excluded.received_at,measured_at=excluded.measured_at,temperature_c=excluded.temperature_c,ph=excluded.ph,voltage_v=excluded.voltage_v,status=excluded.status;
insert into public.telemetry(device_id,boot_id,sequence,measured_at,temperature_c,ph,voltage_v,status) values
('22222222-2222-2222-2222-222222222221','33333333-3333-3333-3333-333333333331',1,now()-interval '20 minutes',27.90,7.02,3.28,'RUNNING'),
('22222222-2222-2222-2222-222222222221','33333333-3333-3333-3333-333333333331',2,now()-interval '10 minutes',28.20,7.08,3.28,'RUNNING'),
('22222222-2222-2222-2222-222222222221','33333333-3333-3333-3333-333333333331',3,now(),28.65,7.12,3.285,'RUNNING') on conflict do nothing;
