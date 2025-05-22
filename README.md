# CloudResume

This website showcases my experience, home projects and my learnings. This Project is used to host a portfolio static website using S3 Bucket ,Cloudfront and Route53.Secured it using AWS WAF.

# Architecture Components

Amazon S3 – Hosts the static website files (HTML, CSS, JS).

Amazon CloudFront – Serves content globally with low latency.

AWS WAF – Protects your CloudFront distribution from common web exploits.Here, I used for Geo filtering

Amazon Route 53 – Manages DNS and routes traffic to CloudFront.

ACM – Manages SSL/TLS certificates for HTTPS.

<img src="EmailApp Architecture.png" alt="Architecture Diagram" width="500"/>
