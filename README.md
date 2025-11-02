# Codex Monorepo

## Prerequisites

* AWS Account + IAM user/role with CDK permissions
* Store GitHub token in **Secrets Manager** at `/codex/github/token`
* Node 20, pnpm, AWS CLI v2, CDK v2

## 1) Bootstrap & deploy dev

```bash
cd infra
pnpm install
cdk bootstrap aws://<ACCOUNT>/me-south-1
ENV=dev pnpm deploy
```

## 2) Set up CodePipeline

* Commit to the branch defined in `infra/config/staging.json` (`release/main`).
* Pipeline will run **Infra** then **Services** builds.

## 3) Test API locally (optional)

Use `sam local` or invoke deployed API URL from API Gateway console.

## 4) Flutter quick test

* Edit `apiBase` in `main.dart` to your API invoke URL.
* `flutter run` on a device/simulator.
* Provide web favicon and app icons by uploading `clients/flutter/web/favicon.png`, `clients/flutter/web/icons/Icon-180.png`, `clients/flutter/web/icons/Icon-192.png`, and `clients/flutter/web/icons/Icon-512.png` before building the Flutter web bundle.

## Notes

* The demo API deploys without authentication; all requests operate against a shared sandbox user.
* DynamoDB keys are simplified for the prototype. For production, add GSIs for byAccount/byCategory queries and write capacity alarms.
