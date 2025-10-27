import { App } from 'aws-cdk-lib';
import { CoreStack } from '../lib/core-stack.js';
import { AuthStack } from '../lib/auth-stack.js';
import { ApiStack } from '../lib/api-stack.js';
import { JobsStack } from '../lib/jobs-stack.js';
import { PipelineStack } from '../lib/pipeline-stack.js';
import fs from 'node:fs';

const app = new App();

const envName = process.env.ENV || 'dev';
const cfg = JSON.parse(fs.readFileSync(`./config/${envName}.json`, 'utf-8'));
const env = { account: cfg.account, region: cfg.region };

const core = new CoreStack(app, `Codex-Core-${envName}`, { env, tags: cfg.tags });
const auth = new AuthStack(app, `Codex-Auth-${envName}`, { env, core, tags: cfg.tags });
const api = new ApiStack(app, `Codex-Api-${envName}`, { env, core, auth, tags: cfg.tags });
new JobsStack(app, `Codex-Jobs-${envName}`, { env, core, api, tags: cfg.tags });

if (envName === 'prod' || envName === 'staging') {
  new PipelineStack(app, `Codex-Pipeline-${envName}`, {
    env,
    repo: cfg.repo,
    branch: cfg.branch,
    tags: cfg.tags,
  });
}
