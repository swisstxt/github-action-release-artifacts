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

AUTH_HEADER="Authorization: token ${INPUT_GITHUB_TOKEN}"

RELEASE_NAME=${INPUT_RELEASE_NAME:-$TAG}

echo "::notice::Verifying release ${TAG}"
RESPONSE=$(curl \
  --write-out "%{http_code}" \
  --silent \
  --show-error \
  --location \
  --header "${AUTH_HEADER}" \
  "https://api.github.com/repos/${GITHUB_REPOSITORY}/releases/tags/${TAG}"
)
HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_STATUS" -eq 200 ]; then
  echo "::notice::Existing release found"
    CONTENT=$(echo "$RESPONSE" | sed "$ d" | jq --args)
    UPLOAD_URL=$(echo "$CONTENT" | jq -r ".upload_url")
    echo "::notice::Release found"
    echo "id=$(echo "$CONTENT" | jq -r ".id")" >> "${GITHUB_OUTPUT}"
    echo "html_url=$(echo "$CONTENT" | jq -r ".html_url")" >> "${GITHUB_OUTPUT}"
    echo "upload_url=${UPLOAD_URL}" >> "${GITHUB_OUTPUT}"
elif [ "$HTTP_STATUS" -eq 403 ]; then
  echo "::error::Authorization error when accessing the GitHub API"
  exit 1
elif [ "$HTTP_STATUS" -eq 404 ]; then
  if [ "${INPUT_CREATE_RELEASE}" = "true" ]; then
    echo "::notice::Creating new release"
    RESPONSE=$(curl \
      --write-out "%{http_code}" \
      --silent \
      --show-error \
      --location \
      --header "${AUTH_HEADER}" \
      --header "Content-Type: application/json" \
      --data "{\"tag_name\":\"${TAG}\",\"draft\":${INPUT_CREATE_DRAFT},\"name\":\"${RELEASE_NAME}\"}" \
      "https://api.github.com/repos/${GITHUB_REPOSITORY}/releases")
    HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
    CONTENT=$(echo "$RESPONSE" | sed "$ d" | jq --args)

    if [ "$HTTP_STATUS" -eq 201 ]; then
      echo "::notice::Release successfully created"
      UPLOAD_URL=$(echo "$CONTENT" | jq -r ".upload_url")
      echo "::notice::Release found"
      echo "id=$(echo "$CONTENT" | jq -r ".id")" >> "${GITHUB_OUTPUT}"
      echo "html_url=$(echo "$CONTENT" | jq -r ".html_url")" >> "${GITHUB_OUTPUT}"
      echo "upload_url=${UPLOAD_URL}" >> "${GITHUB_OUTPUT}"
    else
      echo "::error::Failed to create release: ${HTTP_STATUS}"
      echo "$CONTENT" | jq ".errors"
      exit 1
    fi
  else
    echo "::error::Release is missing"
    exit 1
  fi
else
  echo "::error::Unknown status code: ${HTTP_STATUS}"
  exit 1
fi

PATHS=${INPUT_FILES:-.}

# important: the UPLOAD_URL must be stripped of templates and exported, or it won't be visible in subshells
export UPLOAD_URL_STRIPPED=${UPLOAD_URL%%{*\}}
echo "::notice::Upload URL: ${UPLOAD_URL_STRIPPED}"
export UPLOAD_AUTH_HEADER="Authorization: Bearer ${INPUT_GITHUB_TOKEN}"


for path in ${PATHS}; do
  fullpath="${GITHUB_WORKSPACE}/${path}"
  echo "::notice::Processing path ${fullpath}"
  find ${fullpath} -type f -print0 | xargs -n1 -0 -I{} sh -c '
    filepath="{}" ;
    filename=$(basename "{}") ;
    echo "::notice::Uploading ${filename}" ;
    curl \
      --write-out "%{url} %{speed_upload}B/s %{size_upload}B %{response_code}\n" \
      --silent \
      --show-error \
      --location \
      --fail-with-body \
      --header "${UPLOAD_AUTH_HEADER}" \
      --header "Content-Type: application/octet-stream" \
      --data-binary @"${filepath}" \
      "${UPLOAD_URL_STRIPPED}?name=${filename}" ;
  '
done
