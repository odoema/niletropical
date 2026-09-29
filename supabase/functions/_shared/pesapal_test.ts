import {
  normalizePesapalStatus,
  parsePesapalEnvironment,
  pesapalBaseUrl,
  validatePesapalStatusBinding,
} from "./pesapal.ts";

Deno.test("Pesapal environment must be explicit and recognized", () => {
  if (parsePesapalEnvironment("sandbox") !== "sandbox") {
    throw new Error("sandbox environment was not parsed");
  }
  if (parsePesapalEnvironment("PRODUCTION") !== "production") {
    throw new Error("production environment was not normalized");
  }
  let rejected = false;
  try {
    parsePesapalEnvironment(undefined);
  } catch {
    rejected = true;
  }
  if (!rejected) throw new Error("missing environment must be rejected");
});

Deno.test("Pesapal environment selects only official API base URLs", () => {
  if (pesapalBaseUrl("sandbox") !== "https://cybqa.pesapal.com/pesapalv3") {
    throw new Error("unexpected sandbox base URL");
  }
  if (pesapalBaseUrl("production") !== "https://pay.pesapal.com/v3") {
    throw new Error("unexpected production base URL");
  }
});

Deno.test("Pesapal transaction statuses normalize conservatively", () => {
  const cases: Array<[number, string]> = [
    [1, "completed"],
    [2, "failed"],
    [3, "reversed"],
    [0, "invalid"],
  ];
  for (const [code, expected] of cases) {
    if (normalizePesapalStatus(code) !== expected) {
      throw new Error(`status code ${code} did not map to ${expected}`);
    }
  }
  if (normalizePesapalStatus(undefined, "processing") !== "pending") {
    throw new Error("unknown provider status must remain pending");
  }
});

Deno.test("Pesapal status must match merchant reference, amount and currency", () => {
  const expected = {
    merchantReference: "NT-ORDER-123",
    amount: 42500,
    currency: "UGX",
  };
  const valid = validatePesapalStatusBinding({
    merchant_reference: "NT-ORDER-123",
    amount: 42500,
    currency: "UGX",
    status_code: 1,
  }, expected);
  if (!valid.ok) throw new Error("matching transaction should be accepted");

  const wrongReference = validatePesapalStatusBinding({
    merchant_reference: "NT-OTHER-ORDER",
    amount: 42500,
    currency: "UGX",
  }, expected);
  if (wrongReference.ok || wrongReference.reason !== "PESAPAL_MERCHANT_REFERENCE_MISMATCH") {
    throw new Error("wrong merchant reference must be rejected");
  }

  const wrongAmount = validatePesapalStatusBinding({
    merchant_reference: "NT-ORDER-123",
    amount: 42501,
    currency: "UGX",
  }, expected);
  if (wrongAmount.ok || wrongAmount.reason !== "PESAPAL_AMOUNT_MISMATCH") {
    throw new Error("wrong amount must be rejected");
  }

  const wrongCurrency = validatePesapalStatusBinding({
    merchant_reference: "NT-ORDER-123",
    amount: 42500,
    currency: "KES",
  }, expected);
  if (wrongCurrency.ok || wrongCurrency.reason !== "PESAPAL_CURRENCY_MISMATCH") {
    throw new Error("wrong currency must be rejected");
  }
});
