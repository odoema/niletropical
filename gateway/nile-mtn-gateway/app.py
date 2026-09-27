import base64
import os
from typing import Any, Dict, Optional

import httpx
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel


app = FastAPI(title="Nile Tropical MTN Gateway", version="1.1.0")

GATEWAY_SHARED_SECRET = os.getenv("GATEWAY_SHARED_SECRET")
MTN_BASE_URL = os.getenv(
    "MTN_COLLECTION_BASE_URL",
    "https://sandbox.momodeveloper.mtn.com",
)
MTN_TARGET_ENVIRONMENT = os.getenv(
    "MTN_TARGET_ENVIRONMENT",
    "sandbox",
)
MTN_SUBSCRIPTION_KEY = os.getenv("MTN_SUBSCRIPTION_KEY")
MTN_API_USER = os.getenv("MTN_API_USER")
MTN_API_KEY = os.getenv("MTN_API_KEY")

# Sandbox uses EUR. The merchant/provider amount is supplied by the
# Supabase payment-initiate adapter. Do not replace it with a fixed amount:
# payment-status intentionally verifies the exact provider amount returned
# by MTN against the immutable request recorded in payment_transactions.
MTN_SANDBOX_TEST_CURRENCY = os.getenv("MTN_SANDBOX_TEST_CURRENCY", "EUR")
MTN_SANDBOX_TEST_MSISDN = os.getenv("MTN_SANDBOX_TEST_MSISDN", "46733123499")


class RequestToPay(BaseModel):
    reference_id: str
    external_id: str
    amount: str
    currency: str = "UGX"
    payer_party_id_type: str = "MSISDN"
    payer_party_id: str
    payer_message: str
    payee_note: str
    transfer_type: str = "CUSTOM_PAYMENT"


def require_gateway_secret(secret: Optional[str]) -> None:
    if not GATEWAY_SHARED_SECRET:
        raise HTTPException(
            status_code=500,
            detail="Gateway shared secret is not configured",
        )

    if secret != GATEWAY_SHARED_SECRET:
        raise HTTPException(status_code=401, detail="Unauthorized")


def require_mtn_credentials() -> None:
    global MTN_SUBSCRIPTION_KEY, MTN_API_USER, MTN_API_KEY
    MTN_SUBSCRIPTION_KEY = os.getenv("MTN_SUBSCRIPTION_KEY")
    MTN_API_USER = os.getenv("MTN_API_USER")
    MTN_API_KEY = os.getenv("MTN_API_KEY")
    missing = []

    if not MTN_SUBSCRIPTION_KEY:
        missing.append("MTN_SUBSCRIPTION_KEY")
    if not MTN_API_USER:
        missing.append("MTN_API_USER")
    if not MTN_API_KEY:
        missing.append("MTN_API_KEY")

    if missing:
        raise HTTPException(
            status_code=500,
            detail={"message": "Missing MTN gateway credentials", "missing": missing},
        )


async def get_mtn_access_token() -> str:
    require_mtn_credentials()

    url = MTN_BASE_URL.rstrip("/") + "/collection/token/"

    basic = base64.b64encode(
        "{}:{}".format(MTN_API_USER, MTN_API_KEY).encode()
    ).decode()

    headers = {
        "Authorization": "Basic {}".format(basic),
        "Ocp-Apim-Subscription-Key": MTN_SUBSCRIPTION_KEY,
    }

    async with httpx.AsyncClient(
        timeout=httpx.Timeout(30.0, connect=10.0)
    ) as client:
        response = await client.post(url, headers=headers)

    if response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail={
                "upstream": "MTN",
                "operation": "oauth",
                "status_code": response.status_code,
                "response": response.text[:1000],
            },
        )

    try:
        data = response.json()
    except Exception:
        raise HTTPException(
            status_code=502,
            detail={
                "upstream": "MTN",
                "operation": "oauth",
                "status_code": response.status_code,
                "content_type": response.headers.get("content-type"),
                "response": response.text[:1000],
            },
        )

    access_token = data.get("access_token")

    if not access_token:
        raise HTTPException(status_code=502, detail="MTN returned no access token")

    return access_token


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "service": "nile-mtn-gateway",
        "environment": MTN_TARGET_ENVIRONMENT,
    }


@app.post("/mtn/token")
async def mtn_token(
    x_gateway_secret: Optional[str] = Header(default=None),
):
    require_gateway_secret(x_gateway_secret)
    token = await get_mtn_access_token()
    return {"status": "ok", "token_received": bool(token)}


@app.get("/mtn/collection/request-to-pay/{reference_id}")
async def request_to_pay_status(
    reference_id: str,
    x_gateway_secret: Optional[str] = Header(default=None),
):
    require_gateway_secret(x_gateway_secret)

    access_token = await get_mtn_access_token()

    url = (
        MTN_BASE_URL.rstrip("/")
        + "/collection/v1_0/requesttopay/"
        + reference_id
    )

    headers = {
        "Authorization": "Bearer {}".format(access_token),
        "X-Target-Environment": MTN_TARGET_ENVIRONMENT,
        "Ocp-Apim-Subscription-Key": MTN_SUBSCRIPTION_KEY,
    }

    async with httpx.AsyncClient(
        timeout=httpx.Timeout(30.0, connect=10.0)
    ) as client:
        response = await client.get(url, headers=headers)

    content_type = response.headers.get("content-type", "")

    if "application/json" in content_type:
        try:
            response_body = response.json()
        except Exception:
            response_body = response.text
    else:
        response_body = response.text

    return {
        "status_code": response.status_code,
        "headers": {
            "location": response.headers.get("location"),
        },
        "body": response_body,
    }


@app.post("/mtn/collection/request-to-pay")
async def request_to_pay(
    request: RequestToPay,
    x_gateway_secret: Optional[str] = Header(default=None),
):
    require_gateway_secret(x_gateway_secret)

    access_token = await get_mtn_access_token()

    url = MTN_BASE_URL.rstrip("/") + "/collection/v1_0/requesttopay"

    headers = {
        "Authorization": "Bearer {}".format(access_token),
        "X-Reference-Id": request.reference_id,
        "X-Target-Environment": MTN_TARGET_ENVIRONMENT,
        "Ocp-Apim-Subscription-Key": MTN_SUBSCRIPTION_KEY,
        "Content-Type": "application/json",
    }

    if MTN_TARGET_ENVIRONMENT.lower() == "sandbox":
        request_currency = MTN_SANDBOX_TEST_CURRENCY.upper()
        incoming_currency = request.currency.upper()

        if incoming_currency != request_currency:
            raise HTTPException(
                status_code=400,
                detail={
                    "error": "MTN_SANDBOX_CURRENCY_MISMATCH",
                    "expected_currency": request_currency,
                    "received_currency": incoming_currency,
                },
            )

        # IMPORTANT: preserve the exact provider amount calculated by
        # payment-initiate. The old gateway replaced every amount with a
        # fixed test value of 1 EUR, which made payment-status correctly
        # reject successful MTN transactions as PAYMENT_AMOUNT_MISMATCH.
        request_amount = request.amount
        request_currency = request_currency
        request_payer = MTN_SANDBOX_TEST_MSISDN
    else:
        request_amount = request.amount
        request_currency = request.currency
        request_payer = request.payer_party_id

    body: Dict[str, Any] = {
        "amount": request_amount,
        "currency": request_currency,
        "externalId": request.external_id,
        "payer": {
            "partyIdType": request.payer_party_id_type,
            "partyId": request_payer,
        },
        "payerMessage": request.payer_message,
        "payeeNote": request.payee_note,
        "transferType": request.transfer_type,
    }

    async with httpx.AsyncClient(
        timeout=httpx.Timeout(30.0, connect=10.0)
    ) as client:
        response = await client.post(url, headers=headers, json=body)

    response_body: Any

    if response.text:
        content_type = response.headers.get("content-type", "")

        if "application/json" in content_type:
            try:
                response_body = response.json()
            except Exception:
                response_body = response.text
        else:
            response_body = response.text
    else:
        response_body = None

    return {
        "status_code": response.status_code,
        "headers": {
            "location": response.headers.get("location"),
        },
        "body": response_body,
    }
