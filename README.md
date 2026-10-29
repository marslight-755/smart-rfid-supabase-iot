# ESP32 IoT Customer Dashboard — Supabase Edition

This is the active architecture approved for the POC. It replaces Firebase with Supabase.

## Stack

- React + Vite + TypeScript
- Supabase PostgreSQL with Row Level Security
- Supabase Auth for customer sessions
- Supabase Edge Functions for authenticated ESP32 ingestion
- Supabase Realtime on `device_latest`
- ESP32 HTTPS + JSON telemetry

## Quick start

1. Create a Supabase project.
2. Install the Supabase CLI and run `supabase link --project-ref YOUR_PROJECT_REF`.
3. Apply the schema: `supabase db push`.
4. Set Edge Function secrets:

```text
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

5. Deploy the ingestion function: `supabase functions deploy ingest-telemetry --no-verify-jwt`.
6. Copy `frontend/.env.example` to `frontend/.env`, add the project URL and publishable key, then run:

```text
cd frontend
npm install
npm run dev
```

7. Create a user in Supabase Auth, then provision an organization, membership, and device using the SQL comments in `supabase/migrations/001_schema.sql`.

## Device endpoint

```text
POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/ingest-telemetry
X-Device-Id: ESP32-001
X-Device-Key: unique-device-secret
Content-Type: application/json
```

Payload:

```json
{"boot_id":"550e8400-e29b-41d4-a716-446655440000","sequence":1052,"measured_at":"2026-10-30T12:00:00Z","temperature_c":28.65,"ph":7.12,"voltage_v":3.285,"status":"RUNNING"}
```

## Security

Device credentials are stored as SHA-256 hashes. The service role key is used only in the Edge Function environment. Customer data is protected by organization-based RLS. Never place the service-role key in the React frontend or ESP32 firmware.
