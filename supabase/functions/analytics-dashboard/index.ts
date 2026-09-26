// analytics-dashboard — Nile Tropical admin analytics gateway.
// Google Analytics credentials remain server-side.
//
// Required Supabase Edge Function secrets:
//   GOOGLE_ANALYTICS_PROPERTY_ID
//   GOOGLE_SERVICE_ACCOUNT_JSON
//
// The Google service account must have access to the GA4 property.

import { serve } from "https://deno.land/std@0.190.0/http/server.ts";

const cors = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const STAFF_ROLES = new Set([
  "super_admin", "admin", "manager", "inventory_officer", "inventory",
  "sales", "sales_staff", "finance", "content", "content_manager",
]);

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: cors });
}

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  }
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function textBase64Url(value: string): string {
  return base64Url(new TextEncoder().encode(value));
}

function pemToBytes(pem: string): Uint8Array {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

async function getGoogleAccessToken(credentials: { client_email: string; private_key: string }) {
  const now = Math.floor(Date.now() / 1000);
  const header = textBase64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = textBase64Url(JSON.stringify({
    iss: credentials.client_email,
    scope: "https://www.googleapis.com/auth/analytics.readonly",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = header + "." + claim;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToBytes(credentials.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body:
      "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer" +
      "&assertion=" + encodeURIComponent(unsigned + "." + base64Url(new Uint8Array(signature))),
  });

  const body = await response.json().catch(() => ({}));
  if (!response.ok || !body.access_token) {
    throw new Error("Google OAuth token request failed: " + JSON.stringify(body));
  }
  return String(body.access_token);
}

async function currentUserIsStaff(req: Request) {
  const auth = req.headers.get("authorization") ?? "";
  if (!auth.startsWith("Bearer ")) return { ok: false, error: "Missing Supabase access token." };

  const token = auth.slice("Bearer ".length).trim();
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRole) {
    return { ok: false, error: "Supabase server configuration is incomplete." };
  }

  const userResponse = await fetch(supabaseUrl + "/auth/v1/user", {
    headers: { apikey: serviceRole, Authorization: "Bearer " + token },
  });
  if (!userResponse.ok) return { ok: false, error: "Invalid or expired staff session." };

  const user = await userResponse.json();
  const userId = String(user?.id ?? "");
  if (!userId) return { ok: false, error: "Authenticated user was not found." };

  const rolesResponse = await fetch(
    supabaseUrl + "/rest/v1/user_roles?select=role&user_id=eq." + encodeURIComponent(userId),
    { headers: { apikey: serviceRole, Authorization: "Bearer " + serviceRole } },
  );
  if (rolesResponse.ok) {
    const roles = await rolesResponse.json();
    if (Array.isArray(roles) && roles.some((r: Record<string, unknown>) => STAFF_ROLES.has(String(r.role ?? "")))) {
      return { ok: true, userId };
    }
  }

  const profileResponse = await fetch(
    supabaseUrl + "/rest/v1/profiles?select=role,is_active&id=eq." +
      encodeURIComponent(userId) + "&limit=1",
    { headers: { apikey: serviceRole, Authorization: "Bearer " + serviceRole } },
  );
  if (profileResponse.ok) {
    const profiles = await profileResponse.json();
    const profile = Array.isArray(profiles) ? profiles[0] : null;
    if (profile && profile.is_active !== false && STAFF_ROLES.has(String(profile.role ?? ""))) {
      return { ok: true, userId };
    }
  }

  return { ok: false, error: "Analytics is restricted to Nile Tropical staff." };
}

function kampalaDate(daysAgo = 0): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Africa/Kampala",
    year: "numeric", month: "2-digit", day: "2-digit",
  }).formatToParts(new Date());
  const year = Number(parts.find((p) => p.type === "year")?.value);
  const month = Number(parts.find((p) => p.type === "month")?.value);
  const day = Number(parts.find((p) => p.type === "day")?.value);
  const date = new Date(Date.UTC(year, month - 1, day));
  date.setUTCDate(date.getUTCDate() - daysAgo);
  return date.toISOString().slice(0, 10);
}

function daysForRange(range: unknown): number {
  const value = String(range ?? "7");
  if (value === "30") return 30;
  if (value === "90") return 90;
  return 7;
}

async function analyticsRequest(
  accessToken: string,
  propertyId: string,
  method: string,
  body: Record<string, unknown>,
) {
  const response = await fetch(
    "https://analyticsdata.googleapis.com/v1beta/properties/" + propertyId + ":" + method,
    {
      method: "POST",
      headers: {
        Authorization: "Bearer " + accessToken,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    },
  );
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error("Google Analytics " + method + " failed (" + response.status + "): " + JSON.stringify(payload));
  }
  return payload;
}

function rows(response: any): Array<Record<string, unknown>> {
  const dimensions = (response?.dimensionHeaders ?? []).map((h: any) => String(h.name));
  const metrics = (response?.metricHeaders ?? []).map((h: any) => String(h.name));
  return (response?.rows ?? []).map((row: any) => {
    const out: Record<string, unknown> = {};
    (row?.dimensionValues ?? []).forEach((v: any, i: number) => {
      out[dimensions[i] ?? "dimension_" + i] = v?.value ?? "";
    });
    (row?.metricValues ?? []).forEach((v: any, i: number) => {
      out[metrics[i] ?? "metric_" + i] = v?.value ?? "0";
    });
    return out;
  });
}

function number(value: unknown): number {
  const n = Number(value ?? 0);
  return Number.isFinite(n) ? n : 0;
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { status: 200, headers: cors });
  if (req.method !== "POST") return json({ error: "POST required" }, 405);

  try {
    const staff = await currentUserIsStaff(req);
    if (!staff.ok) return json({ error: staff.error ?? "Unauthorized" }, 401);

    const propertyId = Deno.env.get("GOOGLE_ANALYTICS_PROPERTY_ID");
    const rawCredentials = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON");
    if (!propertyId || !rawCredentials) {
      return json({
        error: "Google Analytics is not connected yet. Configure GOOGLE_ANALYTICS_PROPERTY_ID and GOOGLE_SERVICE_ACCOUNT_JSON in Supabase Edge Function secrets.",
        code: "GA_NOT_CONFIGURED",
      }, 503);
    }

    let credentials: { client_email: string; private_key: string };
    try {
      const parsed = JSON.parse(rawCredentials);
      credentials = {
        client_email: String(parsed.client_email ?? ""),
        private_key: String(parsed.private_key ?? ""),
      };
      if (!credentials.client_email || !credentials.private_key) throw new Error("Missing credentials");
    } catch {
      return json({ error: "GOOGLE_SERVICE_ACCOUNT_JSON is not valid service-account JSON.", code: "GA_CREDENTIALS_INVALID" }, 500);
    }

    const requestBody = await req.json().catch(() => ({}));
    const days = daysForRange(requestBody.range);
    const endDate = kampalaDate(0);
    const startDate = kampalaDate(days - 1);
    const accessToken = await getGoogleAccessToken(credentials);
    const dateRanges = [{ startDate, endDate }];

    const [overview, trend, countries, sources, pages, events, realtime] = await Promise.all([
      analyticsRequest(accessToken, propertyId, "runReport", {
        dateRanges,
        metrics: [
          { name: "activeUsers" }, { name: "sessions" },
          { name: "screenPageViews" }, { name: "eventCount" },
        ],
      }),
      analyticsRequest(accessToken, propertyId, "runReport", {
        dateRanges,
        dimensions: [{ name: "date" }],
        metrics: [{ name: "activeUsers" }, { name: "sessions" }],
        orderBys: [{ dimension: { dimensionName: "date", orderType: "NUMERIC_ASCENDING" } }],
        limit: "100",
      }),
      analyticsRequest(accessToken, propertyId, "runReport", {
        dateRanges,
        dimensions: [{ name: "country" }],
        metrics: [{ name: "activeUsers" }],
        orderBys: [{ metric: { metricName: "activeUsers", orderType: "NUMERIC_DESCENDING" } }],
        limit: "8",
      }),
      analyticsRequest(accessToken, propertyId, "runReport", {
        dateRanges,
        dimensions: [{ name: "sessionDefaultChannelGroup" }],
        metrics: [{ name: "activeUsers" }, { name: "sessions" }],
        orderBys: [{ metric: { metricName: "sessions", orderType: "NUMERIC_DESCENDING" } }],
        limit: "8",
      }),
      analyticsRequest(accessToken, propertyId, "runReport", {
        dateRanges,
        dimensions: [{ name: "pageTitle" }],
        metrics: [{ name: "screenPageViews" }],
        orderBys: [{ metric: { metricName: "screenPageViews", orderType: "NUMERIC_DESCENDING" } }],
        limit: "8",
      }),
      analyticsRequest(accessToken, propertyId, "runReport", {
        dateRanges,
        dimensions: [{ name: "eventName" }],
        metrics: [{ name: "eventCount" }],
        orderBys: [{ metric: { metricName: "eventCount", orderType: "NUMERIC_DESCENDING" } }],
        limit: "10",
      }),
      analyticsRequest(accessToken, propertyId, "runRealtimeReport", {
        dimensions: [{ name: "country" }],
        metrics: [{ name: "activeUsers" }],
        orderBys: [{ metric: { metricName: "activeUsers", orderType: "NUMERIC_DESCENDING" } }],
        limit: "8",
      }),
    ]);

    const overviewRow = rows(overview)[0] ?? {};
    return json({
      ok: true,
      propertyId,
      rangeDays: days,
      startDate,
      endDate,
      generatedAt: new Date().toISOString(),
      overview: {
        activeUsers: number(overviewRow.activeUsers),
        sessions: number(overviewRow.sessions),
        screenPageViews: number(overviewRow.screenPageViews),
        eventCount: number(overviewRow.eventCount),
      },
      trend: rows(trend).map((r) => ({
        date: String(r.date ?? ""),
        activeUsers: number(r.activeUsers),
        sessions: number(r.sessions),
      })),
      countries: rows(countries).map((r) => ({
        country: String(r.country ?? "(not set)"),
        activeUsers: number(r.activeUsers),
      })),
      sources: rows(sources).map((r) => ({
        source: String(r.sessionDefaultChannelGroup ?? "(not set)"),
        activeUsers: number(r.activeUsers),
        sessions: number(r.sessions),
      })),
      pages: rows(pages).map((r) => ({
        pageTitle: String(r.pageTitle ?? "(not set)"),
        screenPageViews: number(r.screenPageViews),
      })),
      events: rows(events).map((r) => ({
        eventName: String(r.eventName ?? "(not set)"),
        eventCount: number(r.eventCount),
      })),
      realtime: {
        countries: rows(realtime).map((r) => ({
          country: String(r.country ?? "(not set)"),
          activeUsers: number(r.activeUsers),
        })),
        activeUsers: rows(realtime).reduce((sum, r) => sum + number(r.activeUsers), 0),
      },
    });
  } catch (error) {
    console.error("[analytics-dashboard]", error);
    return json({ error: String(error), code: "GA_REPORT_FAILED" }, 502);
  }
});
