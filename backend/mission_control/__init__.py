"""Small, internal Paperclip integration for operator/agent workflows."""

from .client import (
    PaperclipAuthError,
    PaperclipClient,
    PaperclipConfig,
    PaperclipConflictError,
    PaperclipError,
    PaperclipHTTPError,
    PaperclipNetworkError,
    PaperclipResponseError,
)

__all__ = [
    "PaperclipAuthError",
    "PaperclipClient",
    "PaperclipConfig",
    "PaperclipConflictError",
    "PaperclipError",
    "PaperclipHTTPError",
    "PaperclipNetworkError",
    "PaperclipResponseError",
]
