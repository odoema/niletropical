// Nile Tropical — free Web Push dispatcher.
// Runs in GitHub Actions. No SMS provider and no paid messaging API.
import webpush from 'web-push';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const VAPID_PRIVATE_KEY = process.env.WEB_PUSH_VAPID_PRIVATE_KEY;
const VAPID_PUBLIC_KEY_URL = 'https://niletropicaluganda.com/app/vapid-public.json';

if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !VAPID_PRIVATE_KEY) {
  throw new Error('Missing SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY or WEB_PUSH_VAPID_PRIVATE_KEY');
}

const vapidResponse = await fetch(VAPID_PUBLIC_KEY_URL, { cache: 'no-store' });
if (!vapidResponse.ok) throw new Error(`Unable to load VAPID public key: ${vapidResponse.status}`);
const vapidConfig = await vapidResponse.json();
const VAPID_PUBLIC_KEY = vapidConfig.publicKey;
if (!VAPID_PUBLIC_KEY) throw new Error('VAPID public key is missing from production config.');

webpush.setVapidDetails(
  'mailto:notifications@niletropicaluganda.com',
  VAPID_PUBLIC_KEY,
  VAPID_PRIVATE_KEY,
);

const headers = {
  apikey: SERVICE_ROLE_KEY,
  Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
  'Content-Type': 'application/json',
};

async function supabase(path, options = {}) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...options,
    headers: { ...headers, ...(options.headers || {}) },
  });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Supabase ${response.status}: ${body}`);
  }
  if (response.status === 204) return null;
  return response.json();
}

function templateMessage(eventKey, orderNumber) {
  const messages = {
    order_received: `Nile Tropical: We have received your order ${orderNumber}. Thank you.`,
    order_confirmed: `Nile Tropical: Your order ${orderNumber} has been confirmed and is being prepared.`,
    payment_confirmed: `Nile Tropical: Payment for order ${orderNumber} has been confirmed.`,
    dispatched: `Nile Tropical: Your order ${orderNumber} has been dispatched and is on its way.`,
    out_for_delivery: `Nile Tropical: Your order ${orderNumber} is now out for delivery.`,
    delivered: `Nile Tropical: Your order ${orderNumber} has been delivered. Thank you!`,
    order_cancelled: `Nile Tropical: Your order ${orderNumber} has been cancelled.`,
  };
  return messages[eventKey] || `Nile Tropical: Update on order ${orderNumber}.`;
}

async function dispatch() {
  const logs = await supabase(
    'notification_logs?select=id,order_id,customer_id,event_key,status&status=eq.pending&channel=eq.push&order_id=not.is.null&order=id.asc&limit=25'
  );

  console.log(`[Push] Pending notifications: ${logs.length}`);

  for (const log of logs) {
    try {
      await supabase(`notification_logs?id=eq.${encodeURIComponent(log.id)}&status=eq.pending`, {
        method: 'PATCH',
        body: JSON.stringify({ status: 'processing', provider: 'web_push' }),
      });

      const orders = await supabase(
        `orders?id=eq.${encodeURIComponent(log.order_id)}&select=order_number`
      );
      const orderNumber = orders?.[0]?.order_number || log.order_id;

      const subscriptions = await supabase(
        `push_subscriptions?auth_user_id=eq.${encodeURIComponent(log.customer_id)}&select=id,endpoint,p256dh,auth`
      );

      if (!subscriptions.length) {
        await supabase(`notification_logs?id=eq.${encodeURIComponent(log.id)}`, {
          method: 'PATCH',
          body: JSON.stringify({
            status: 'failed',
            provider: 'web_push',
            error_message: 'No registered push device for this customer.',
          }),
        });
        continue;
      }

      const payload = JSON.stringify({
        title: 'Nile Tropical',
        body: templateMessage(log.event_key, orderNumber),
        url: '/app/',
        tag: `nile-order-${log.order_id}`,
      });

      let delivered = 0;
      const errors = [];

      for (const sub of subscriptions) {
        try {
          await webpush.sendNotification(
            {
              endpoint: sub.endpoint,
              keys: { p256dh: sub.p256dh, auth: sub.auth },
            },
            payload,
            { TTL: 3600, urgency: 'high' },
          );
          delivered++;
        } catch (error) {
          const statusCode = error?.statusCode;
          errors.push(`${statusCode || 'ERR'}: ${error?.body || error?.message || 'push failed'}`);
          if (statusCode === 404 || statusCode === 410) {
            await supabase(`push_subscriptions?id=eq.${encodeURIComponent(sub.id)}`, {
              method: 'DELETE',
            });
          }
        }
      }

      if (delivered > 0) {
        await supabase(`notification_logs?id=eq.${encodeURIComponent(log.id)}`, {
          method: 'PATCH',
          body: JSON.stringify({
            status: 'sent',
            provider: 'web_push',
            provider_message_id: `${delivered} device(s)`,
            sent_at: new Date().toISOString(),
            error_message: errors.length ? errors.join(' | ') : null,
          }),
        });
        console.log(`[Push] Sent ${log.event_key} for order ${orderNumber} to ${delivered} device(s)`);
      } else {
        await supabase(`notification_logs?id=eq.${encodeURIComponent(log.id)}`, {
          method: 'PATCH',
          body: JSON.stringify({
            status: 'failed',
            provider: 'web_push',
            error_message: errors.join(' | ') || 'Push provider rejected all subscriptions.',
          }),
        });
      }
    } catch (error) {
      console.error(`[Push] Failed notification ${log.id}:`, error);
      try {
        await supabase(`notification_logs?id=eq.${encodeURIComponent(log.id)}`, {
          method: 'PATCH',
          body: JSON.stringify({
            status: 'failed',
            provider: 'web_push',
            error_message: error?.message || String(error),
          }),
        });
      } catch (_) {}
    }
  }
}

await dispatch();
