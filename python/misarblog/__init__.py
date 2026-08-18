"""Official Python SDK for the Misar.Blog developer API.

- :class:`MisarBlogClient` — full sync/async client for the dev API
  (``https://api.misar.io/blog/v1``), authenticated with a ``mbk_`` key.
- :func:`embed_url` — build a public iframe embed URL for an article or profile.

Every API call goes through the metered ``/blog/v1`` gateway with the API key
as a Bearer token; feature access and throughput follow the subscription
attached to that key. A blocked call raises :class:`MisarBlogPlanLimitError`,
which carries the upgrade URL.
"""

from misarblog.client import DEFAULT_BASE_URL, MisarBlogClient
from misarblog.embed import embed_url
from misarblog.errors import (
    MisarBlogError,
    MisarBlogNetworkError,
    MisarBlogPlanLimitError,
)

__all__ = [
    "MisarBlogClient",
    "MisarBlogError",
    "MisarBlogNetworkError",
    "MisarBlogPlanLimitError",
    "DEFAULT_BASE_URL",
    "embed_url",
]

__version__ = "1.1.0"
