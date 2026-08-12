# Project 2: Serverless Cloud Engineering Portfolio Site

## Overview
Designed and deployed a fully serverless personal portfolio site — no servers to patch, scale, or maintain — demonstrating serverless architecture patterns end-to-end: static hosting, global content delivery, a live database-backed feature, and API-driven compute.

## Architecture
- **Hosting:** S3 static website hosting
- **CDN:** CloudFront distribution in front of S3 for global edge caching and HTTPS
- **Visitor Counter:** DynamoDB table tracking visit count, updated via a Lambda function
- **API Layer:** API Gateway exposing the Lambda function to the frontend
- **Live URL:** `hasan-cloud-pro-resume.s3-website-us-east-1.amazonaws.com`

## Design Decisions & Trade-offs

**Problem:** A personal portfolio site needed to be fast, globally available, and cost nothing to run while idle — traffic is unpredictable and often zero for long stretches.

**Trade-off — Traditional server vs. serverless:** A traditional EC2-hosted site is simpler to reason about but costs money 24/7 whether anyone visits or not, and requires ongoing patching and maintenance. I chose a fully serverless architecture (S3 + CloudFront + Lambda + API Gateway + DynamoDB) — no idle compute cost, and it scales automatically if traffic spikes, at the cost of slightly more complex initial wiring between services.

**Trade-off — Debugging a distributed system:** Serverless architectures trade simplicity of a single server for complexity spread across multiple managed services. The visitor counter's failure required checking four separate layers before it worked end-to-end: CORS configuration, API Gateway route paths, and — the two that actually mattered most — the Lambda function's own code correctness and its DynamoDB table schema. Real production debugging usually looks exactly like this: several plausible causes, only one of them actually right, found by isolating each layer rather than guessing at the whole system.

## The Debugging Sequence (real, in order — three separate bugs, not one)
1. **CORS error in the browser console** — traced to missing `Access-Control-Allow-Origin` headers on the Lambda response. Fixed by adding CORS headers to the Lambda return statement and enabling CORS at the API Gateway level.
2. **404 on the API call** — the frontend was calling the API root path (`/`) instead of the actual configured route (`/count`). Fixed by correcting the fetch URL in the frontend JavaScript.
3. **Silent Lambda crash (`IndentationError`)** — inconsistent indentation in the Lambda function meant it crashed before ever running, which is what caused the CORS headers to appear "missing" to the browser — the function never got far enough to send them. Fixed by correcting the indentation.
4. **`NameError` on an undefined variable** — the code referenced `current_count` without ever assigning it from the DynamoDB response. Fixed by properly extracting the value from `response['Attributes']['count']`.
5. **`ValidationException` — DynamoDB key schema mismatch** — the code assumed the table's primary key attribute was named `id`, but the actual table's primary key was named identically to the table itself (`cloud-resume-counter`). Confirmed via `aws dynamodb describe-table` and fixed by matching the `Key` parameter to the table's real schema.

Each of these was diagnosed from the actual error message — CloudWatch/Lambda invoke output, browser DevTools Network tab, and direct DynamoDB schema inspection — not guessed at. What looked like a single "visitor counter doesn't work" bug was actually five distinct, layered issues across networking, application logic, and database schema.

## Tools Used
S3, CloudFront, DynamoDB, Lambda, API Gateway, IAM

## Compliance Controls Demonstrated
| Framework | Control Area |
|---|---|
| Security Hub | Continuous compliance monitoring across the serverless stack |
| SOC 2 | High availability via CloudFront's global edge network — no single point of failure |

## Impact
Eliminated server maintenance costs entirely. Targeting near-continuous availability through CloudFront's globally distributed edge network, with a live, publicly interactive component (visitor counter) demonstrating full-stack serverless capability, not just static hosting.

## Status
- ✅ S3 static hosting live
- ✅ CloudFront distribution configured
- ✅ Visitor counter fully working end-to-end — confirmed live, incrementing correctly on each page load
- ⬜ Security Hub monitoring — to be finalized

## How to Reproduce
1. Create an S3 bucket, enable static website hosting
2. Upload site files (`index.html`, assets)
3. Create a DynamoDB table with a single counter item, and confirm the exact primary key attribute name before writing any code against it
4. Write a Lambda function to increment/read the counter via the DynamoDB SDK, returning proper CORS headers on every response
5. Expose the Lambda via API Gateway (HTTP API), with CORS configured at the API Gateway level as well
6. Point the site's JS at the API Gateway endpoint (including the correct route path) to fetch/increment the count on page load
7. Create a CloudFront distribution with the S3 bucket as origin

## Notes
This project shipped with a known bug (the visitor counter) for several weeks before being fully debugged and fixed — left that way deliberately in earlier versions of this README to reflect real-world iterative deployment. The fix itself, once returned to, took under 30 minutes and involved three genuinely separate root causes layered on top of each other — a legitimate example of methodical debugging rather than guesswork.
