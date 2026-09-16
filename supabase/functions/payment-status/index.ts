// payment-status — read payments.provider_reference; client is not authority
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: { "Access-Control-Allow-Origin": "*" } });
  }
  try {
    let reference: string | null = null;
    const url = new URL(req.url);
    reference = url.searchParams.get("reference");
    if (!reference) {
      const body = await req.json().catch(() => ({}));
      reference = body.reference ?? null;
    }
    if (!reference) {
      return new Response(JSON.stringify({ error: "reference required" }), {
        status: 400,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    }
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { data: payment } = await supabase
      .from("payments")
      .select("id, order_id, status, method, provider_reference")
      .eq("provider_reference", reference)
      .maybeSingle();
    if (!payment) {
      return new Response(JSON.stringify({ error: "Not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    }
    return new Response(
      JSON.stringify({
        reference,
        status: payment.status,
        order_id: payment.order_id,
        method: payment.method,
      }),
      { headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  }
});
