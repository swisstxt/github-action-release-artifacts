#!/bin/ash

set -e

set_tag() {
  if [ -n "${INPUT_TAG}" ]; then
    TAG=${INPUT_TAG}
  else
    TAG="$(echo ${GITHUB_REF} | grep tags | grep -o "[^/]*$" || true)"
  fi
}

set_tag

if [ -z "${TAG}" ]; then
  echo "::error::Cannot find tag to release." 1>&2
  exit 1
fi

# Prepare the headers
AUTH_HEADER="Authorization: token ${INPUT_GITHUB_TOKEN}"

RELEASE_ID=${INPUT_RELEASE_NAME:-$TAG}

echo "::notice::Verifying release"
RESPONSE=$(curl \
  --write-out "%{http_code}" \
  --silent \
  --show-error \
  --location \
  --header "${AUTH_HEADER}" \
  "https://api.github.com/repos/${GITHUB_REPOSITORY}/releases/tags/${RELEASE_ID}"
)
HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_STATUS" -eq 200 ]; then
  echo "::notice::Existing release found"
elif [ "$HTTP_STATUS" -eq 403 ]; then
  echo "::error::Authorization when accessing the GitHub API"
  exit 1
else
  if [ "${INPUT_CREATE_RELEASE}" = "true" ]; then
    echo "::notice::Creating new release"
    RESPONSE=$(curl \
      --write-out "%{http_code}" \
      --silent \
      --show-error \
      --location \
      --header "${AUTH_HEADER}" \
      --header "Content-Type: application/json" \
      --data "{\"tag_name\":\"${TAG}\",\"draft\":${INPUT_CREATE_DRAFT},\"name\":\"${RELEASE_ID}\"}" \
      "https://api.github.com/repos/${GITHUB_REPOSITORY}/releases")
    HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
    CONTENT=$(echo "$RESPONSE" | sed "$ d" | jq --args)

    if [ "$HTTP_STATUS" -eq 201 ]; then
      echo "::notice::Release successfully created"
      echo "::set-output name=id::$(echo "$CONTENT" | jq ".id")"
      echo "::set-output name=html_url::$(echo "$CONTENT" | jq ".html_url")"
      echo "::set-output name=upload_url::$(echo "$CONTENT" | jq ".upload_url")"
    else
      echo "::error::Failed to update release ($HTTP_STATUS):"
      echo "$CONTENT" | jq ".errors"
      exit 1
    fi
  else
    echo "::error::Release is missing"
    exit 1
  fi
fi

PATHS=${INPUT_FILES:-.}
WORKSPACE=/github/workspace
printenv

for path in ${PATHS}; do
  fullpath="${WORKSPACE}/${path}"
  echo "::notice::Processing path ${fullpath}"
  find ${fullpath} -type f -exec echo curl \
    --write-out "%{url} %{speed_upload}B/s %{size_upload}B %{response_code}\n" \
    --silent \
    --show-error \
    --location \
    --header "${AUTH_HEADER}" \
    --header "Content-Type: application/octet-stream" \
    --data-binary @"{}" \
    "https://uploads.github.com/repos/${GITHUB_REPOSITORY}/releases/${RELEASE_ID}/assets?name=$(basename \{})" \
  \;
done
