"""PortOne V2 결제 검증 클라이언트."""

import httpx

from app.config import settings

PORTONE_API_BASE = "https://api.portone.io"


async def verify_payment(payment_id: str) -> dict:
    """PortOne V2 API로 결제 상태 검증.

    Returns:
        dict with keys: status, amount, currency, method, paid_at
    Raises:
        ValueError if payment not found or not paid
    """
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{PORTONE_API_BASE}/payments/{payment_id}",
            headers={
                "Authorization": f"PortOne {settings.PORTONE_API_SECRET}",
                "Content-Type": "application/json",
            },
        )

        if resp.status_code == 404:
            raise ValueError("결제 정보를 찾을 수 없습니다")

        resp.raise_for_status()
        data = resp.json()

        status = data.get("status")
        if status != "PAID":
            raise ValueError(f"결제가 완료되지 않았습니다 (status: {status})")

        return {
            "status": status,
            "amount": data.get("amount", {}).get("total", 0),
            "currency": data.get("currency", "KRW"),
            "method": data.get("method", {}).get("type", ""),
            "paid_at": data.get("paidAt"),
        }


async def verify_payment_amount(payment_id: str, expected_amount: int) -> dict:
    """결제 검증 + 금액 일치 확인."""
    payment = await verify_payment(payment_id)
    if payment["amount"] != expected_amount:
        raise ValueError(f"결제 금액 불일치: 예상 {expected_amount}원, 실제 {payment['amount']}원")
    return payment
