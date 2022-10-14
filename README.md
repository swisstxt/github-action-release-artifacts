# Another GitHub action for uploading release artifacts

Uploads artifacts from a GitHub action into a GitHub release.

Optionally creates the release if it doesn't exist.

## Usage

Example usage with an intermediate build artifacts stage:

```yaml
on:
  push:
    tags: "*"
name: Build & Release
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@master
    - name: build
      run: ./build.sh
    - name: upload artifacts
      uses: actions/upload-artifact@v3.1.0
      with:
        name: artifacts
        path: build/*
        if-no-files-found: warn
        retention-days: 1
  release:
    runs-on: ubuntu-latest
    needs: [build]
    permissions:
      contents: write
    steps:
    - name: download artifacts
      uses: actions/download-artifact@v3
      with:
        name: artifacts
    - name: create release
      uses: swisstxt/github-action-release-artifacts@master
      with:
        tag: ${{ github.ref_name }}
        create_release: true
        release_name: "my project ${{ github.ref_name }}"
      permissions:
        contents: read
        packages: write
```

## Inputs

* `files` - List of files or paths to upload, separated by space. Upload all files in the working directory if missing.
* `created_tag` - Create a release from a specific tag. If missing, try to derive it from the commit ID.
* `create_release` - If false, fails when the release doesn't exist. If true and the release doesn't exist, it is created automatically.
* `release_name` - When creating a new release, use the value of this input as the release name. Otherwise, use the name of the tag.
* `create_draft` - When creating a release, specifies if a normal (false) or draft (true) release should be created. Ignored when not creating a release.

**Note**: If you use the `create_draft` option, a new draft will be created on every run.

## Acknowledgments + Legal

Copyright © 2022 SWISS TXT AG - All rights reserved

Released under the MIT license. See the [LICENSE](LICENSE) file for details.

Based on: [github:Roang-zero1/github-upload-release-artifacts-action](https://github.com/Roang-zero1/github-upload-release-artifacts-action)

With ideas from: [gist:stefanbuck/ce788fee19ab6eb0b4447a85fc99f447](https://gist.github.com/stefanbuck/ce788fee19ab6eb0b4447a85fc99f447)