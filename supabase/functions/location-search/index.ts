import { corsHeaders } from '../_shared/cors.ts';

const PHOTON = 'https://photon.komoot.io/api/';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const body = req.method === 'POST' ? await req.json().catch(() => ({})) : {};
    const q = ((body?.q ?? url.searchParams.get('q') ?? '') as string).trim();

    if (q.length < 3 || q.length > 120) {
      return new Response(JSON.stringify({ error: 'q must be 3-120 characters' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const upstream = new URL(PHOTON);
    upstream.searchParams.set('q', q + ', Uganda');
    upstream.searchParams.set('limit', '6');
    upstream.searchParams.set('lang', 'en');

    const response = await fetch(upstream, { headers: { Accept: 'application/json' } });
    const body = await response.text();

    return new Response(body, {
      status: response.status,
      headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Cache-Control': 'public, max-age=300' },
    });
  } catch (error) {
    return new Response(JSON.stringify({
      error: error instanceof Error ? error.message : 'Location search failed',
    }), {
      status: 502,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
