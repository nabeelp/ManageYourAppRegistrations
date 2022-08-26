# Overview

The function ExportADApps is a PowerShell-based function app, which runs on a scheduled timer trigger, and which will export all AD App Registrations to which the executing service principal has access into a JSON file in blob storage. Optionally, the script can also output a separate JSON file for all AD App Registrations that have expired, or soon to expire, secrets or certificates.

## Timer Trigger - PowerShell

The `TimerTrigger` makes it incredibly easy to have your functions executed on a schedule. This sample demonstrates a simple use case of calling your function every 5 minutes.

For a `TimerTrigger` to work, you provide a schedule in the form of a [cron expression](https://en.wikipedia.org/wiki/Cron#CRON_expression)(See the link for full details). A cron expression is a string with 6 separate expressions which represent a given schedule via patterns. The pattern we use to represent every 5 minutes is `0 */5 * * * *`. This, in plain text, means: "When seconds is equal to 0, minutes is divisible by 5, for any hour, day of the month, month, day of the week, or year".
