// Request plumbing shared by every Edge Function: JSON responses, CORS
// (so browser clients such as tools/gate-playground.html and Flutter web
// can call the functions), and resolving the caller from their JWT.
import { createClient } from "npm:@supabase/supabase-js@2";

export const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", ...CORS_HEADERS },
  });
}

// Handles the CORS preflight and the method check. Returns a response to
// send as-is, or null to carry on.
export function preflight(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method not allowed" }, 405);
  }
  return null;
}

// The caller's user id from their verified JWT, or an error response.
export async function requireUser(
  req: Request,
): Promise<{ userId: string } | { response: Response }> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return {
      response: jsonResponse({ error: "missing Authorization header" }, 401),
    };
  }
  const authedClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data, error } = await authedClient.auth.getUser();
  if (error || !data.user) {
    return { response: jsonResponse({ error: "invalid session" }, 401) };
  }
  return { userId: data.user.id };
}

// Service-role client. Bypasses RLS, so only use it for the writes this
// function owns.
export function serviceClient() {
  return createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
}

// Parses a JSON body, treating an empty body as {}.
export async function readJson(req: Request): Promise<unknown> {
  const text = await req.text();
  return text.trim() === "" ? {} : JSON.parse(text);
}
