const required = [
  'SUPABASE_URL',
  'SUPABASE_SERVICE_ROLE_KEY',
  'AFRICASTALKING_USERNAME',
  'AFRICASTALKING_API_KEY',
];
for (const name of required) {
  if (!process.env[name]) throw new Error(`Missing GitHub secret: ${name}`);
}

const SUPABASE_URL = process.env.SUPABASE_URL.replace(/\/$/, '');
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const AT_USERNAME = process.env.AFRICASTALKING_USERNAME;
const AT_API_KEY = process.env.AFRICASTALKING_API_KEY;
const AT_SENDER_ID = process.env.AFRICASTALKING_SENDER_ID || '';

const headers = {
  apikey: SUPABASE_KEY,
  Authorization: `Bearer ${SUPABASE_KEY}`,
  'Content-Type': 'application/json',
};

async function supabase(path, options = {}) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...options,
    headers: { ...headers, ...(options.headers || {}) },
  });
  const text = await response.text();
  if (!response.ok) throw new Error(`Supabase ${response.status}: ${text}`);
  return text ? JSON.parse(text) : null;
}

function normalizeUgandaPhone(value) {
  const raw = String(value || '').trim().replace(/[\\s()-]/g, '');
  if (raw.startsWith('+256')) return raw;
  if (raw.startsWith('256')) return `+${raw}`;
  if (raw.startsWith('0')) return `+256${raw.slice(1)}`;
  return raw;
}

function render(template, orderNumber) {
  return String(template || '').replaceAll('{{order_number}}', orderNumber || '');
}

async function updateLog(id, patch) {
  await supabase(`notification_logs?id=eq.${encodeURIComponent(id)}`, {
    method: 'PATCH',
    headers: { Prefer: 'return=minimal' },
    body: JSON.stringify(patch),
  });
}

const pending = await supabase(
  'notification_logs?select=id,order_id,channel,recipient,event_key,status,created_at&status=eq.pending&channel=eq.sms&order_id=not.is.null&order=id.asc&limit=25'
);

if (!pending.length) {
  console.log('No pending SMS notifications.');
  process.exit(0);
}

console.log(`Found ${pending.length} pending SMS notification(s).`);

for (const log of pending) {
  try {
    await updateLog(log.id, { status: 'processing', error_message: null });

    const orders = await supabase(
      `orders?select=order_number&id=eq.${encodeURIComponent(log.order_id)}&limit=1`
    );
    if (!orders?.length) throw new Error('Order not found.');

    const templates = await supabase(
      `notification_templates?select=body_template,is_active&event_key=eq.${encodeURIComponent(log.event_key)}&is_active=eq.true&limit=1`
    );

    const fallback = `Nile Tropical: Update for order ${orders[0].order_number}.`;
    const message = templates?.length
      ? render(templates[0].body_template, orders[0].order_number)
      : fallback;

    const to = normalizeUgandaPhone(log.recipient);
    if (!to) throw new Error('Recipient phone number is empty.');

    const form = new URLSearchParams();
    form.set('username', AT_USERNAME);
    form.set('to', to);
    form.set('message', message);
    if (AT_SENDER_ID) form.set('from', AT_SENDER_ID);

    const atResponse = await fetch('https://api.africastalking.com/version1/messaging', {
      method: 'POST',
      headers: {
        apiKey: AT_API_KEY,
        Accept: 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: form.toString(),
    });

    const raw = await atResponse.text();
    let data;
    try { data = JSON.parse(raw); } catch { data = { raw }; }

    if (!atResponse.ok) {
      throw new Error(`Africa's Talking ${atResponse.status}: ${raw}`);
    }

    const recipient = data?.SMSMessageData?.Recipients?.[0];
    const statusCode = String(recipient?.statusCode ?? '');
    const providerStatus = String(recipient?.status ?? '').toLowerCase();
    const messageId = recipient?.messageId ?? null;

    if (statusCode && statusCode !== '100' && statusCode !== '101') {
      throw new Error(`Africa's Talking rejected message: ${JSON.stringify(recipient)}`);
    }

    await updateLog(log.id, {
      status: 'sent',
      provider: 'africas_talking',
      provider_message_id: messageId,
      sent_at: new Date().toISOString(),
      error_message: providerStatus && providerStatus !== 'sent'
        ? `Provider status: ${providerStatus}`
        : null,
    });

    console.log(`Sent ${log.event_key} to ${to}; provider message: ${messageId || 'n/a'}`);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    await updateLog(log.id, {
      status: 'failed',
      provider: 'africas_talking',
      error_message: message.slice(0, 1000),
    });
    console.error(`Notification ${log.id} failed: ${message}`);
  }
}
