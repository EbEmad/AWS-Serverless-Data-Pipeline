"""
Transformer Lambda — Phase 6 of the AWS Data Pipeline
------------------------------------------------------
Triggered by Step Functions after the Validator succeeds.
Reads the raw CSV from S3, cleans and enriches the data,
writes the cleaned file to the processed S3 bucket,
publishes each row to a Kinesis stream, and updates the
DynamoDB tracking record with the final TRANSFORMED status.

Event payload (passed from Validator output in Step Functions):
    {
        "bucket":       "aws-data-pipeline-raw-data",
        "key":          "some_file.csv",
        "run_id":       "<uuid from Validator>",
        "record_count": N
    }

Returns:
    { "status": "TRANSFORMED", "run_id": "...", "output_record_count": N }
"""
import csv
import io
import json
import logging
import os
import re
from datetime import datetime, timezone

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Configuration
TRACKING_TABLE   = os.environ.get("TRACKING_TABLE",       "aws-data-pipeline-tracking")
PROCESSED_BUCKET = os.environ.get("PROCESSED_BUCKET",     "aws-data-pipeline-processed-data")
#KINESIS_STREAM   = os.environ.get("KINESIS_STREAM",        "aws-data-pipeline-stream")
REGION           = os.environ.get("AWS_DEFAULT_REGION",    "us-east-1")
ENDPOINT_URL     = os.environ.get("AWS_ENDPOINT_URL",      "http://localhost:4566")

# boto3 clients
s3       = boto3.client("s3",       region_name=REGION, endpoint_url=ENDPOINT_URL)
#kinesis  = boto3.client("kinesis",  region_name=REGION, endpoint_url=ENDPOINT_URL)
dynamodb = boto3.resource("dynamodb", region_name=REGION, endpoint_url=ENDPOINT_URL)
table    = dynamodb.Table(TRACKING_TABLE)


# Helpers
def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _normalize_column_name(name: str) -> str:
    """'First Name ' → 'first_name'"""
    name = name.strip().lower()
    name = re.sub(r"[^a-z0-9]+", "_", name)
    return name.strip("_")


def _normalize_date(raw: str) -> str:
    """
    Try a few common date formats and return YYYY-MM-DD.
    Falls back to the raw value if no format matches.
    """
    formats = ["%Y-%m-%d", "%d/%m/%Y", "%m/%d/%Y", "%d-%m-%Y", "%Y%m%d"]
    for fmt in formats:
        try:
            return datetime.strptime(raw.strip(), fmt).strftime("%Y-%m-%d")
        except ValueError:
            continue
    logger.warning("Could not parse date '%s', keeping as-is", raw)
    return raw.strip()



# Core transformation
def _transform_rows(raw_rows: list[dict]) -> list[dict]:
    """
    Apply all cleaning / enrichment rules to the raw row list.
    Returns the cleaned row list (bad rows are dropped with a warning).
    """
    cleaned = []

    for i, row in enumerate(raw_rows, start=1):
        # Normalize column names
        row = {_normalize_column_name(k): v.strip() if isinstance(v, str) else v
               for k, v in row.items()}

        # Cast 'value' to float — drop row if impossible
        try:
            row["value"] = float(row["value"])
        except (ValueError, TypeError, KeyError):
            logger.warning("Row %d: dropping row with non-numeric value: %s", i, row)
            continue

        # Normalize the date column
        if "date" in row:
            row["date"] = _normalize_date(row["date"])

        #  Drop rows where any required field is blank
        if not all([str(row.get("id", "")).strip(),
                    str(row.get("name", "")).strip()]):
            logger.warning("Row %d: dropping row with empty id/name: %s", i, row)
            continue

        cleaned.append(row)

    return cleaned


# S3 read / write
def _read_csv_from_s3(bucket: str, key: str) -> list[dict]:
    logger.info("Reading s3://%s/%s", bucket, key)
    response = s3.get_object(Bucket=bucket, Key=key)
    content = response["Body"].read().decode("utf-8")
    return list(csv.DictReader(io.StringIO(content)))


def _write_csv_to_s3(bucket: str, key: str, rows: list[dict]) -> None:
    if not rows:
        logger.warning("No rows to write to processed bucket — skipping.")
        return

    buf = io.StringIO()
    writer = csv.DictWriter(buf, fieldnames=rows[0].keys())
    writer.writeheader()
    writer.writerows(rows)

    logger.info("Writing %d rows to s3://%s/%s", len(rows), bucket, key)
    s3.put_object(Bucket=bucket, Key=key, Body=buf.getvalue().encode("utf-8"))


# Kinesis publish

def _publish_to_kinesis(rows: list[dict], run_id: str) -> None:
    """Send each row as a JSON record to the Kinesis stream."""
    if not rows:
        return

    # Kinesis PutRecords accepts up to 500 records per call
    BATCH = 500
    sent = 0
    for start in range(0, len(rows), BATCH):
        batch = rows[start : start + BATCH]
        records = [
            {
                "Data": json.dumps({**row, "run_id": run_id}).encode("utf-8"),
                "PartitionKey": str(row.get("id", run_id)),
            }
            for row in batch
        ]
        kinesis.put_records(StreamName=KINESIS_STREAM, Records=records)
        sent += len(batch)

    logger.info("Published %d records to Kinesis stream '%s'", sent, KINESIS_STREAM)



# DynamoDB update
def _update_tracking_record(run_id: str, output_record_count: int,
                             status: str = "TRANSFORMED",
                             error_message: str = "") -> None:
    table.update_item(
        Key={"run_id": run_id},
        UpdateExpression=(
            "SET #s = :status, "
            "output_record_count = :orc, "
            "processed_at = :ts, "
            "error_message = :err"
        ),
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={
            ":status": status,
            ":orc":    output_record_count,
            ":ts":     _now_iso(),
            ":err":    error_message,
        },
    )
    logger.info("DynamoDB record updated: run_id=%s status=%s", run_id, status)


# Entry point

def lambda_handler(event: dict, context) -> dict:
    logger.info("Transformer invoked with event: %s", json.dumps(event))

    bucket   = event["bucket"]
    key      = event["key"]
    run_id   = event["run_id"]

    try:
        #  Read raw data
        raw_rows = _read_csv_from_s3(bucket, key)

        #  Clean and transform
        clean_rows = _transform_rows(raw_rows)
        logger.info("Transformation complete: %d/%d rows kept", len(clean_rows), len(raw_rows))

        #  Write cleaned data to processed bucket
        _write_csv_to_s3(PROCESSED_BUCKET, key, clean_rows)

        #  Publish to Kinesis stream
        # _publish_to_kinesis(clean_rows, run_id)

        #  Update DynamoDB tracking record
        _update_tracking_record(run_id, output_record_count=len(clean_rows))

        return {
            "status": "TRANSFORMED",
            "run_id": run_id,
            "output_record_count": len(clean_rows),
            "processed_key": key,
        }

    except Exception as exc:
        logger.exception("Unexpected error during transformation")
        _update_tracking_record(
            run_id=run_id,
            output_record_count=0,
            status="TRANSFORM_ERROR",
            error_message=str(exc),
        )
        raise
