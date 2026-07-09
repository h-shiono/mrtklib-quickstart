# ============================================================================
#  run-container.ps1  -  start the container -> open the browser
#
#  Role: start the mrtklib-docker-ui container with `docker run`.
#        Pass the two COM streams (raw / CON) as devices, and open the UI
#        in the browser once it is up.
#
#  Idempotency: if a container of the same name exists, either stop+remove it
#               before starting, or reuse it (pick one policy and keep it consistent).
# ============================================================================

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"

$IMAGE          = 'TODO/mrtklib-docker-ui:latest'
$CONTAINER_NAME = 'mrtklib-ui'
$UI_URL         = 'http://localhost:8080'   # TODO: match the actual published port

Write-Step "Starting the container"

# TODO: implement
#  1. Clean up any existing container (idempotent)
#  2. docker run -d --name $CONTAINER_NAME \
#        --device <raw path> --device <CON path> \
#        -p <host>:<container> $IMAGE
#  3. Health check (wait until the UI responds)
#  4. Open the browser: Start-Process $UI_URL

Write-Warn "run-container.ps1 is not implemented yet (skeleton)"
# Start-Process $UI_URL
