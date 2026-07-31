"""
Disparador S3 -> Langflow. Se activa con cada objeto nuevo bajo el prefijo
"inbox/" del bucket de documentos, descarga el archivo, lo envia al mismo
endpoint /api/v1/run/<FLOW_ID> que ya usa el resto del proyecto (mismo
contrato: JSON con media_type + content en Base64), y guarda la respuesta
bajo el prefijo "results/" del mismo bucket.

No modifica el flujo de Langflow ni el componente TextractOCR: solo
reemplaza la llamada HTTP manual del cliente por una automatica basada en
el evento de S3.
"""

import base64
import json
import mimetypes
import os
import urllib.error
import urllib.parse
import urllib.request

import boto3

s3 = boto3.client("s3")
secretsmanager = boto3.client("secretsmanager")

LANGFLOW_URL = os.environ["LANGFLOW_URL"].rstrip("/")
FLOW_ID = os.environ["FLOW_ID"]
API_KEY_SECRET_ARN = os.environ["API_KEY_SECRET_ARN"]
RESULTS_PREFIX = os.environ.get("RESULTS_PREFIX", "results/")

_MEDIA_TYPE_OVERRIDES = {
    ".pdf": "application/pdf",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".tif": "image/tiff",
    ".tiff": "image/tiff",
    ".txt": "text/plain",
}


def _guess_media_type(key: str) -> str:
    for ext, media_type in _MEDIA_TYPE_OVERRIDES.items():
        if key.lower().endswith(ext):
            return media_type
    guessed, _ = mimetypes.guess_type(key)
    return guessed or "application/octet-stream"


def _get_api_key() -> str:
    resp = secretsmanager.get_secret_value(SecretId=API_KEY_SECRET_ARN)
    return resp["SecretString"]


def _result_key(source_key: str, suffix: str) -> str:
    basename = source_key.rsplit("/", 1)[-1]
    return f"{RESULTS_PREFIX}{basename}.{suffix}.json"


def handler(event, _context):
    for record in event.get("Records", []):
        bucket = record["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])

        obj = s3.get_object(Bucket=bucket, Key=key)
        file_bytes = obj["Body"].read()

        payload = json.dumps(
            {
                "media_type": _guess_media_type(key),
                "content": base64.b64encode(file_bytes).decode("ascii"),
            }
        ).encode("utf-8")

        req = urllib.request.Request(
            url=f"{LANGFLOW_URL}/api/v1/run/{FLOW_ID}",
            data=payload,
            method="POST",
            headers={
                "Content-Type": "application/json",
                "x-api-key": _get_api_key(),
            },
        )

        try:
            with urllib.request.urlopen(req, timeout=280) as resp:
                body = resp.read().decode("utf-8", errors="replace")
                status = resp.status
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            status = exc.code
        except urllib.error.URLError as exc:
            body = json.dumps({"error": str(exc)})
            status = 0

        suffix = "ok" if 200 <= status < 300 else "error"
        s3.put_object(
            Bucket=bucket,
            Key=_result_key(key, suffix),
            Body=body.encode("utf-8"),
            ContentType="application/json",
        )

        if suffix == "error":
            raise RuntimeError(f"Langflow devolvio HTTP {status} para {bucket}/{key}: {body}")

    return {"processed": len(event.get("Records", []))}
