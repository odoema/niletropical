import { corsHeaders } from '../_shared/cors.ts';

const OSRM = 'https://router.project-osrm.org/route/v1/driving';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const origin = body?.origin;
    const destination = body?.destination;

    const validPoint = (p: unknown) =>
      typeof p === 'object' && p !== null &&
      Number.isFinite((p as any).latitude) &&
      Number.isFinite((p as any).longitude) &&
      Math.abs((p as any).latitude) <= 90 &&
      Math.abs((p as any).longitude) <= 180;

    if (!validPoint(origin) || !validPoint(destination)) {
      return new Response(JSON.stringify({ error: 'Valid origin and destination coordinates are required.' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const path = OSRM + '/' +
      origin.longitude + ',' + origin.latitude + ';' +
      destination.longitude + ',' + destination.latitude;

    const upstream = new URL(path);
    upstream.searchParams.set('overview', 'full');
    upstream.searchParams.set('geometries', 'geojson');
    upstream.searchParams.set('steps', 'false');

    const response = await fetch(upstream, { headers: { Accept: 'application/json' } });
    const payload = await response.json();

    return new Response(JSON.stringify(payload), {
      status: response.status,
      headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Cache-Control': 'public, max-age=60' },
    });
  } catch (error) {
    return new Response(JSON.stringify({
      error: error instanceof Error ? error.message : 'Route calculation failed',
    }), {
      status: 502,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
