"""
Validator Lambda — Phase 5 of the AWS Data Pipeline
----------------------------------------------------
Triggered by Step Functions. Reads a CSV from S3 raw bucket,
validates schema and data quality, then writes run metadata
to DynamoDB (aws-data-pipeline-tracking).

Event payload:
    {
        "bucket": "aws-data-pipeline-raw-data",
        "key": "some_file.csv"
    }

Returns:
    { "status": "VALID", "run_id": "<uuid>", "record_count": N, "key": "..." }

Raises:
    ValueError on validation failures (Step Functions → Fail state).
"""
import json
import uuid
import csv
import io
import os
import logging
from datetime import datetime, timezone

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)


TRACKING_TABLE = os.environ.get("TRACKING_TABLE", "aws-data-pipeline-tracking")
REGION = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")
ENDPOINT_URL = os.environ.get("AWS_ENDPOINT_URL", "http://localhost:4566")

# Required columns 
REQUIRED_COLUMNS = {"id", "name", "value", "date"}


# boto3 clients  (endpoint_url makes these work with LocalStack)
s3 = boto3.client("s3", region_name=REGION, endpoint_url=ENDPOINT_URL)
dynamodb = boto3.resource("dynamodb", region_name=REGION, endpoint_url=ENDPOINT_URL)
table = dynamodb.Table(TRACKING_TABLE)


# Helpers
def _now_iso() -> str:
    """Return the current UTC time as an ISO-8601 string."""
    return datetime.now(timezone.utc).isoformat()


def _write_tracking_record(run_id: str, file_name: str, status: str,
                            record_count: int, error_message: str = "") -> None:
    """Write (or replace) a run-tracking record in DynamoDB."""
    table.put_item(Item={
        "run_id": run_id,
        "file_name": file_name,
        "status": status,
        "record_count": record_count,
        "error_message": error_message,
        "started_at": _now_iso(),
    })
    logger.info("DynamoDB record written: run_id=%s status=%s", run_id, status)


def _read_csv_from_s3(bucket: str, key: str) -> list[dict]:
    """Download a CSV from S3 and return a list of row dicts."""
    logger.info("Reading s3://%s/%s", bucket, key)
    response = s3.get_object(Bucket=bucket, Key=key)
    content = response["Body"].read().decode("utf-8")
    reader = csv.DictReader(io.StringIO(content))
    rows = list(reader)
    logger.info("Read %d rows from CSV", len(rows))
    return rows



# Validation logic
def _validate(rows: list[dict], file_name: str) -> tuple[bool, str]:
    """
    Run all validation checks. Returns (is_valid, error_message).
    is_valid = True means the data passed all checks.
    """
    
    if not rows:
        return False, "File is empty — no rows found."

    actual_columns = set(rows[0].keys())
    missing = REQUIRED_COLUMNS - actual_columns
    if missing:
        return False, f"Missing required columns: {sorted(missing)}"

    #  No null
    for i, row in enumerate(rows, start=1):
        for col in REQUIRED_COLUMNS:
            if not str(row.get(col, "")).strip():
                return False, (
                    f"Row {i} has missing value in column '{col}'. "
                    f"Row data: {dict(row)}"
                )

    # 'value' column must be numeric
    for i, row in enumerate(rows, start=1):
        try:
            float(row["value"])
        except (ValueError, TypeError):
            return False, (
                f"Row {i} has non-numeric 'value': '{row['value']}'"
            )

    return True, ""


# Entry point
def lambda_handler(event: dict, context) -> dict:
    """Main handler called by AWS Lambda / Step Functions."""
    logger.info("Validator invoked with event: %s", json.dumps(event))

    bucket = event["bucket"]
    key = event["key"]
    run_id = str(uuid.uuid4())

    try:
        rows = _read_csv_from_s3(bucket, key)
        is_valid, error_message = _validate(rows, key)

        if is_valid:
            _write_tracking_record(
                run_id=run_id,
                file_name=key,
                status="VALID",
                record_count=len(rows),
            )
            logger.info("Validation PASSED for '%s' (%d rows)", key, len(rows))
            return {
                "status": "VALID",
                "run_id": run_id,
                "record_count": len(rows),
                "bucket": bucket,
                "key": key,
            }
        else:
            _write_tracking_record(
                run_id=run_id,
                file_name=key,
                status="INVALID",
                record_count=len(rows),
                error_message=error_message,
            )
            logger.error("Validation FAILED for '%s': %s", key, error_message)
            raise ValueError(f"Validation failed for '{key}': {error_message}")

    except ValueError:
        # Re-raise validation errors so Step Functions sees a task failure
        raise
    except Exception as exc:
        # Unexpected errors (S3 read failure, DynamoDB write failure, etc.)
        logger.exception("Unexpected error during validation")
        _write_tracking_record(
            run_id=run_id,
            file_name=key,
            status="ERROR",
            record_count=0,
            error_message=str(exc),
        )
        raise
