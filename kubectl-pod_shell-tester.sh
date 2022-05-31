#!/usr/bin/env bash
set -e

if [ "$1" == "" ]; then
	NAMESPACE=test-ohad
else
	NAMESPACE=$1
fi


echo "Will work on Namespace '$NAMESPACE'" ...
echo

kubectl=kubectl

cmd=(sh -c --)

# translate embedded single-quotes to double-quotes, so the following line will work
cmd=( "${cmd[@]//\'/\"}" )

cmd+=("while true; do sleep 30; done;")

# jsonify(as an array) the argument list (mainly from the command line)
entrypoint="$(echo "['${cmd[@]/%/\', \'}']" | sed -e "s/' /'/g" \
                   -e "s/, '']\$/]/" -Ee "s/([\"\\])/\\\\\1/g" -e 's/\\\\n/\\n/g' | tr \' \")"


image=repository.local/alpine:3.14.0

pod="pod-shell-$(env LC_ALL=C tr -dc a-z0-9 </dev/urandom | head -c 6)"

overrides="$(
  cat <<EOT
{
  "spec": {
    "hostPID": false,
    "hostNetwork": false,
    "serviceAccount": "sa-test-ohadm",
    "imagePullSecrets": [{"name": "ohadm-nexus-dev"}],
    "securityContext": { "runAsUser": 0 },
    "containers": [
      {
        "securityContext": {
          "privileged": false
        },
        "image": "$image",
        "name": "$pod",
        "stdin": true,
        "stdinOnce": true,
        "tty": true,
        "command": $entrypoint
      }
    ],
    "tolerations": [
      {
        "key": "CriticalAddonsOnly",
        "operator": "Exists"
      },
      {
        "effect": "NoExecute",
        "operator": "Exists"
      }
    ]
  }
}
EOT
)"

trap "EC=\$?; $kubectl -n $NAMESPACE delete pod --wait=false $pod >&2 || true; exit \$EC" EXIT INT TERM

echo "creating pod '$pod' ..."
echo

$kubectl -n $NAMESPACE run --image "$image" --restart=Never --overrides="$overrides" "$pod" &

$kubectl -n $NAMESPACE get pods
echo

sleep 3

echo "openning a shell in pod '$pod' ..."
echo

$kubectl -n $NAMESPACE exec -it "$pod" -- sh








