import crypto from 'node:crypto';

const suppliedPrivateKey = process.env.WEB_PUSH_VAPID_PRIVATE_KEY;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

function derivePrivateKey(seed) {
  const digest = crypto.createHmac('sha256', 'nile-tropical-web-push-vapid-v1').update(seed, 'utf8').digest();
  const curveOrder = BigInt('0xffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551');
  const scalar = (BigInt('0x' + digest.toString('hex')) % (curveOrder - 1n)) + 1n;
  return Buffer.from(scalar.toString(16).padStart(64, '0'), 'hex');
}

const raw = suppliedPrivateKey
  ? Buffer.from(suppliedPrivateKey, 'base64url')
  : serviceRoleKey
    ? derivePrivateKey(serviceRoleKey)
    : null;

if (!raw) throw new Error('Missing WEB_PUSH_VAPID_PRIVATE_KEY or SUPABASE_SERVICE_ROLE_KEY');
if (raw.length !== 32) throw new Error('VAPID private key must be 32 bytes');

const ecdh = crypto.createECDH('prime256v1');
ecdh.setPrivateKey(raw);

process.stdout.write(JSON.stringify({
  publicKey: ecdh.getPublicKey().toString('base64url')
}) + '\n');
