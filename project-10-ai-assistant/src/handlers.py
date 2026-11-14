"""AWS Lambda entry points. Uses Amazon Bedrock through the function's IAM role, so there are no API keys in code."""
import hashlib
import json
import os
import time
import uuid

import boto3

import agent as agent_mod
import guard
import rag

REGION = os.environ.get("AWS_REGION", "us-east-1")
BUCKET = os.environ.get("DOCS_BUCKET", "")
INDEX_KEY = "index/index.json"
EMBED_MODEL = os.environ.get("EMBED_MODEL_ID", "amazon.titan-embed-text-v2:0")
GEN_MODEL = os.environ.get("GEN_MODEL_ID", "")
TABLE = os.environ.get("TICKETS_TABLE", "")

_s3 = boto3.client("s3", region_name=REGION)
_bedrock = boto3.client("bedrock-runtime", region_name=REGION)
_cache = {}


def log(event, **fields):
    print(json.dumps({"event": event, **fields}))  # JSON logs so CloudWatch can count tokens


def embed(text):
    r = _bedrock.invoke_model(modelId=EMBED_MODEL, body=json.dumps({"inputText": text[:8000]}))
    return json.loads(r["body"].read())["embedding"]


def converse(messages, system=None, tools=None):
    kwargs = {"modelId": GEN_MODEL, "messages": messages, "inferenceConfig": {"maxTokens": 500, "temperature": 0}}
    if system:
        kwargs["system"] = [{"text": system}]
    if tools:
        kwargs["toolConfig"] = {"tools": [{"toolSpec": t} for t in tools]}
    return _bedrock.converse(**kwargs)


def generate(system, user):
    r = converse([{"role": "user", "content": [{"text": user}]}], system=system)
    text = "".join(b.get("text", "") for b in r["output"]["message"]["content"])
    u = r.get("usage", {})
    return text, {"input_tokens": u.get("inputTokens", 0), "output_tokens": u.get("outputTokens", 0)}


def load_index():
    if "index" not in _cache:
        body = _s3.get_object(Bucket=BUCKET, Key=INDEX_KEY)["Body"].read()
        _cache["index"] = json.loads(body)
    return _cache["index"]


def ingest_handler(event, context):
    """Read every file under docs/, chunk it, embed it, write one index file."""
    index = []
    pages = _s3.get_paginator("list_objects_v2").paginate(Bucket=BUCKET, Prefix="docs/")
    for page in pages:
        for obj in page.get("Contents", []):
            text = _s3.get_object(Bucket=BUCKET, Key=obj["Key"])["Body"].read().decode("utf-8", "ignore")
            for chunk in rag.chunk_text(text, obj["Key"].split("/")[-1]):
                chunk["vector"] = embed(chunk["text"])
                index.append(chunk)
    _s3.put_object(Bucket=BUCKET, Key=INDEX_KEY, Body=json.dumps(index).encode(), ServerSideEncryption="aws:kms")
    log("ingest", chunks=len(index))
    return {"chunks": len(index)}


def _tools():
    def search_handbook(question):
        hits = rag.top_k(embed(question), load_index(), k=3)
        safe, _ = guard.quarantine(hits)
        return [{"id": p["id"], "text": p["text"]} for p in safe]

    def open_ticket(summary):
        tid = str(uuid.uuid4())
        boto3.client("dynamodb", region_name=REGION).put_item(
            TableName=TABLE,
            Item={"id": {"S": tid}, "summary": {"S": guard.redact(summary)[:500]}, "created": {"N": str(int(time.time()))}},
        )
        return {"ticket_id": tid}

    return agent_mod.make_tools(search_handbook, open_ticket)


def _model_step(messages, specs):
    bedrock_msgs = []
    for m in messages:
        if "tool_use" in m:
            t = m["tool_use"]
            bedrock_msgs.append({"role": "assistant", "content": [{"toolUse": {"toolUseId": t["id"], "name": t["name"], "input": t.get("input", {})}}]})
        elif "tool_result" in m:
            r = m["tool_result"]
            bedrock_msgs.append({"role": "user", "content": [{"toolResult": {"toolUseId": r["id"], "content": [{"text": r["content"]}]}}]})
        else:
            bedrock_msgs.append({"role": "user", "content": [{"text": m["content"]}]})
    r = converse(bedrock_msgs, system=rag.SYSTEM, tools=specs)
    for block in r["output"]["message"]["content"]:
        if "toolUse" in block:
            t = block["toolUse"]
            return {"type": "tool_use", "id": t["toolUseId"], "name": t["name"], "input": t["input"]}
    return {"type": "text", "text": "".join(b.get("text", "") for b in r["output"]["message"]["content"])}


def ask_handler(event, context):
    started = time.time()
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _resp(400, {"error": "body must be JSON"})
    question = body.get("question", "")
    if body.get("mode") == "agent":
        ok, reason = guard.check_input(question)
        if not ok:
            return _resp(400, {"error": reason})
        out = agent_mod.run_agent(question, _model_step, _tools(), allowed=("search_handbook", "open_ticket", "send_email"))
        out["answer"] = guard.redact(out["answer"])
        log("agent", steps=len(out["trace"]), pending=len(out["pending_approval"]), ms=int((time.time() - started) * 1000))
        return _resp(200, out)
    out = rag.answer(question, load_index(), embed, generate)
    usage = out.get("usage", {})
    log("usage", input_tokens=usage.get("input_tokens", 0), output_tokens=usage.get("output_tokens", 0),
        total_tokens=usage.get("input_tokens", 0) + usage.get("output_tokens", 0), blocked=out["blocked"],
        quarantined=len(out.get("quarantined", [])), question_hash=hashlib.sha256(question.encode()).hexdigest()[:12],
        ms=int((time.time() - started) * 1000))  # hash, not the question: do not log what people type
    return _resp(400 if out["blocked"] else 200, out)


def _resp(code, body):
    return {"statusCode": code, "headers": {"Content-Type": "application/json"}, "body": json.dumps(body)}
