Deploy all CIS 3.X Benchmarks Using CloudFormation

Note:  CIS 3.2 will trigger on all non-MFA logins to include Single Sign-On.  Use the following Metric to trigger only AWS IAM Logins without MFA.

($.eventName = \"ConsoleLogin\") && 
($.additionalEventData.MFAUsed !=\"Yes\") &&
($.additionalEventData.SamlProviderArn NOT EXISTS)
