import { decideSettlement } from "./pesapal_settle.ts";

function eq(actual: unknown, expected: unknown, label: string) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`${label}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

Deno.test("only a completed Pesapal status marks the order paid", () => {
  eq(decideSettlement("completed"), { txStatus: "successful", orderPaymentStatus: "paid" }, "completed");
  for (const s of ["pending", "reversed"] as const) {
    eq(decideSettlement(s).orderPaymentStatus, null, s);
  }
});

Deno.test("failed and invalid statuses fail the order payment", () => {
  eq(decideSettlement("failed"), { txStatus: "failed", orderPaymentStatus: "failed" }, "failed");
  eq(decideSettlement("invalid"), { txStatus: "failed", orderPaymentStatus: "failed" }, "invalid");
});

Deno.test("a reversal is recorded but never changes the order automatically", () => {
  eq(decideSettlement("reversed"), { txStatus: "refunded", orderPaymentStatus: null }, "reversed");
});
