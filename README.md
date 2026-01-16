# Influx DB Stack

## Manual test alert

A manual alert rule is wired to the Pushgateway so you can verify Alertmanager routing.

Trigger:

```bash
scripts/trigger-test-alert.sh trigger
```

Clear:

```bash
scripts/trigger-test-alert.sh clear
```

If Pushgateway is not on `http://localhost:9091`, set `PUSHGATEWAY_URL` and (optionally) `JOB`.
