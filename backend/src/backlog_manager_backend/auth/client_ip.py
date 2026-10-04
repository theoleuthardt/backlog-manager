"""Client IP resolution for rate limiting behind a reverse proxy.

Behind Cloudflare / cloudflared every request reaches the backend from the
proxy's address, so keying the login rate limit on the socket peer would
make all users share one bucket. CF-Connecting-IP carries the real client
address, but it is a plain header any caller can send - it is believed only
when the socket peer is inside `settings.trusted_proxy_ips`."""

import ipaddress

from litestar import Request

from backlog_manager_backend.config import settings

_FORWARDED_HEADER = "cf-connecting-ip"
_UNKNOWN_PEER = "unknown"


def _is_trusted_proxy(peer: str) -> bool:
    try:
        address = ipaddress.ip_address(peer)
    except ValueError:
        return False
    return any(address in network for network in settings.trusted_proxy_networks)


def _is_ip(value: str) -> bool:
    try:
        ipaddress.ip_address(value)
    except ValueError:
        return False
    return True


def get_client_ip(request: Request) -> str:
    peer = request.client.host if request.client else _UNKNOWN_PEER
    forwarded = request.headers.get(_FORWARDED_HEADER, "").strip()
    if forwarded and _is_ip(forwarded) and _is_trusted_proxy(peer):
        return forwarded
    return peer
