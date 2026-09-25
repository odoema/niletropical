import crypto from 'node:crypto';

const privateKey = process.env.WEB_PUSH_VAPID_PRIVATE_KEY;
if (!privateKey) throw new Error('WEB_PUSH_VAPID_PRIVATE_KEY is required');

const raw = Buffer.from(privateKey, 'base64url');
if (raw.length !== 32) throw new Error('VAPID private key must be 32 bytes');

const ecdh = crypto.createECDH('prime256v1');
ecdh.setPrivateKey(raw);

process.stdout.write(JSON.stringify({
  publicKey: ecdh.getPublicKey().toString('base64url')
}) + '\n');
