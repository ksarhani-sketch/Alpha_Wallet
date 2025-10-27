import type { StackProps } from 'aws-cdk-lib';

export interface WithTags extends StackProps {
  tags?: Record<string, string>;
}
