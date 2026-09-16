"""Strukturiertes Logging fuer den Betrieb.

Siehe docs/22-deploy-runbook.md Abschnitt "Monitoring" fuer die Signalliste
(was einen Menschen weckt vs. nur geloggt/aufbewahrt wird). JSON-Logging
macht Backend-Logs fuer jeden log-basierten Aggregator (Loki, CloudWatch,
journald-Weiterleitung an einen Hosted-Dienst) maschinenlesbar, ohne eine
konkrete SaaS-Anbindung als Pflichtabhaengigkeit einzufuehren - die
Anbieterwahl ist laut docs/17-release-readiness.md Abschnitt 5 noch offen.
"""

from __future__ import annotations

import json
import logging
import time

_EXTRA_FIELDS = ("path", "method", "status_code")


class JsonLogFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(record.created)),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        for key in _EXTRA_FIELDS:
            value = getattr(record, key, None)
            if value is not None:
                payload[key] = value
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        return json.dumps(payload, ensure_ascii=False)


def configure_logging(*, json_format: bool, level: str = "INFO") -> None:
    handler = logging.StreamHandler()
    if json_format:
        handler.setFormatter(JsonLogFormatter())
    else:
        handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(name)s: %(message)s"))

    root = logging.getLogger()
    root.handlers = [handler]
    root.setLevel(level)
