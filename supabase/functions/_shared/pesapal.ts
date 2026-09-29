// Pesapal API 3.0 adapter primitives for server-side Edge Functions.
// This module intentionally does not initiate or settle orders by itself.
// Keep provider secrets in Supabase Edge Function secrets; never import this
// module into Flutter or other browser code.

export type PesapalEnvironment = "sandbox" | "production";

export type PesapalTransactionStatus =
  | "completed"
  | "failed"
  | "reversed"
  | "invalid"
  | "pending";

export interface PesapalStatusResponse {
  order_tracking_id?: string;
  merchant_reference?: string;
  amount?: number | string;
  currency?: string;
  payment_status_description?: string;
  status_code?: number | string;
  payment_method?: string;
  confirmation_code?: string;
  error?: unknown;
}

const BASE_URLS: Record<PesapalEnvironment, string> = {
  sandbox: "https://cybqa.pesapal.com/pesapalv3",
  production: "https://pay.pesapal.com/v3",
};

export function parsePesapalEnvironment(
  value: string | undefined,
): PesapalEnvironment {
  const normalized = (value ?? "").trim().toLowerCase();
  if (normalized === "sandbox" || normalized === "production") {
    return normalized;
  }
  throw new Error("PESAPAL_ENVIRONMENT must be explicitly set to sandbox or production");
}

export function pesapalBaseUrl(environment: PesapalEnvironment): string {
  return BASE_URLS[environment];
}

export function normalizePesapalStatus(
  statusCode: number | string | undefined,
  description?: string,
): PesapalTransactionStatus {
  const code = statusCode == null ? "" : String(statusCode).trim();
  switch (code) {
    case "1":
      return "completed";
    case "2":
      return "failed";
    case "3":
      return "reversed";
    case "0":
      return "invalid";
  }

  const status = (description ?? "").trim().toLowerCase();
  if (status === "completed" || status === "complete" || status === "paid") {
    return "completed";
  }
  if (status === "failed") return "failed";
  if (status === "reversed") return "reversed";
  if (status === "invalid") return "invalid";
  return "pending";
}

export function validatePesapalStatusBinding(
  status: PesapalStatusResponse,
  expected: {
    merchantReference: string;
    amount: number;
    currency: string;
  },
): { ok: true } | { ok: false; reason: string } {
  if (
    !status.merchant_reference ||
    status.merchant_reference !== expected.merchantReference
  ) {
    return { ok: false, reason: "PESAPAL_MERCHANT_REFERENCE_MISMATCH" };
  }

  const amount = Number(status.amount);
  if (!Number.isFinite(amount) || Math.abs(amount - expected.amount) > 0.01) {
    return { ok: false, reason: "PESAPAL_AMOUNT_MISMATCH" };
  }

  if (
    typeof status.currency !== "string" ||
    status.currency.trim().toUpperCase() !== expected.currency.toUpperCase()
  ) {
    return { ok: false, reason: "PESAPAL_CURRENCY_MISMATCH" };
  }

  return { ok: true };
}

async function readJson(response: Response): Promise<Record<string, unknown>> {
  const text = await response.text();
  let parsed: unknown;
  try {
    parsed = text ? JSON.parse(text) : {};
  } catch {
    throw new Error("PESAPAL_INVALID_JSON_RESPONSE");
  }
  if (!response.ok || !parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    const body = parsed && typeof parsed === "object"
      ? parsed as Record<string, unknown>
      : {};
    const error = body.error as Record<string, unknown> | undefined;
    throw new Error(
      typeof error?.message === "string"
        ? `PESAPAL_HTTP_${response.status}: ${error.message}`
        : `PESAPAL_HTTP_${response.status}`,
    );
  }
  return parsed as Record<string, unknown>;
}

export async function requestPesapalToken(args: {
  environment: PesapalEnvironment;
  consumerKey: string;
  consumerSecret: string;
  fetchImpl?: typeof fetch;
}): Promise<string> {
  if (!args.consumerKey.trim() || !args.consumerSecret.trim()) {
    throw new Error("PESAPAL_CREDENTIALS_NOT_CONFIGURED");
  }

  const fetchImpl = args.fetchImpl ?? fetch;
  const response = await fetchImpl(
    `${pesapalBaseUrl(args.environment)}/api/Auth/RequestToken`,
    {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        consumer_key: args.consumerKey,
        consumer_secret: args.consumerSecret,
      }),
    },
  );
  const data = await readJson(response);
  const token = data.token;
  if (typeof token !== "string" || !token.trim()) {
    throw new Error("PESAPAL_ACCESS_TOKEN_MISSING");
  }
  return token;
}

export async function submitPesapalOrder(args: {
  environment: PesapalEnvironment;
  accessToken: string;
  order: Record<string, unknown>;
  fetchImpl?: typeof fetch;
}): Promise<{ trackingId: string; merchantReference: string; redirectUrl: string }> {
  const fetchImpl = args.fetchImpl ?? fetch;
  const response = await fetchImpl(
    `${pesapalBaseUrl(args.environment)}/api/Transactions/SubmitOrderRequest`,
    {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        Authorization: `Bearer ${args.accessToken}`,
      },
      body: JSON.stringify(args.order),
    },
  );
  const data = await readJson(response);
  const trackingId = data.order_tracking_id;
  const merchantReference = data.merchant_reference;
  const redirectUrl = data.redirect_url;

  if (
    typeof trackingId !== "string" || !trackingId.trim() ||
    typeof merchantReference !== "string" || !merchantReference.trim() ||
    typeof redirectUrl !== "string" || !redirectUrl.trim()
  ) {
    throw new Error("PESAPAL_ORDER_RESPONSE_INCOMPLETE");
  }

  // Do not permit a provider response to redirect customers to arbitrary hosts.
  const redirect = new URL(redirectUrl);
  const expectedHost = new URL(pesapalBaseUrl(args.environment)).hostname;
  if (redirect.protocol !== "https:" || redirect.hostname !== expectedHost) {
    throw new Error("PESAPAL_REDIRECT_URL_NOT_TRUSTED");
  }

  return { trackingId, merchantReference, redirectUrl };
}

export async function getPesapalTransactionStatus(args: {
  environment: PesapalEnvironment;
  accessToken: string;
  trackingId: string;
  fetchImpl?: typeof fetch;
}): Promise<PesapalStatusResponse> {
  if (!args.trackingId.trim()) throw new Error("PESAPAL_TRACKING_ID_REQUIRED");

  const fetchImpl = args.fetchImpl ?? fetch;
  const endpoint = new URL(
    `${pesapalBaseUrl(args.environment)}/api/Transactions/GetTransactionStatus`,
  );
  endpoint.searchParams.set("orderTrackingId", args.trackingId);

  const response = await fetchImpl(endpoint.toString(), {
    method: "GET",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      Authorization: `Bearer ${args.accessToken}`,
    },
  });
  return await readJson(response) as PesapalStatusResponse;
}
