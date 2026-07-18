# simulate the actions using act.

default:
    @just --lis

pr env="staging":
    @echo "Running simulation for environment: {{env}}"
    act pull_request \
        -W ./.github/workflows/azure-terraform.yaml \
        --eventpath event-sim/pr-{{env}}.json \
        --artifact-server-path ./tmp/artifacts \
        --secret-file .secrets

push env="staging":
    @echo "Pushing to: {{env}}"
    act push \
        -W ./.github/workflows/azure-terraform.yaml \
        --eventpath event-sim/push-{{env}}.json \
        --artifact-server-path ./tmp/artifacts \
        --secret-file .secrets

check:
    act -l