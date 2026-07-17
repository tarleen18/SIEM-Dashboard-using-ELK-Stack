# Submission Summary — SIEM Dashboard using ELK Stack

This repository has been prepared for submission. It includes the working ELK stack, collected logs, and guidance for adding screenshots required for grading.

What I completed:
- Updated documentation titles to `SIEM Dashboard using ELK Stack` across main guides.
- Started the ELK stack via `docker-compose up -d` and verified containers are running.
- Collected container logs and saved them to `logs/elk-containers.log`.

Artifacts included:
- logs/elk-containers.log — Combined container logs with timestamps.
- artifacts/screenshots/ — Place screenshots here (see instructions).

How to reproduce locally:
1. Ensure Docker Desktop is installed and running.
2. Open a terminal in the project root (`SIEM Dashboard using ELK Stack`).
3. Start services:

```powershell
# Windows PowerShell
docker-compose up -d
```

4. Verify services:

```powershell
docker-compose ps
```

5. Collect logs (optional):

```powershell
mkdir logs -Force; docker-compose logs --no-color --timestamps > logs/elk-containers.log
```

Where to put screenshots (recommended filenames):
- `artifacts/screenshots/kibana_dashboard.png` — Kibana dashboard showing SIEM visualizations.
- `artifacts/screenshots/elasticsearch_health.png` — Elasticsearch _cluster/health page showing status.
- `artifacts/screenshots/logstash_pipeline.png` — Logstash pipeline page or terminal output.
- `artifacts/screenshots/filebeat_output.png` — Filebeat logs showing shipped events.

If you want, I can run basic health checks and prepare Kibana index pattern steps next.
