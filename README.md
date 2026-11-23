# public-wiki

Creative Commons (CC) Public Wiki


## Overview

The goals of this project are to:
1. Maintain the [Package public-wiki][public-wiki-pkg] in support of the CC
   Public Wiki remote production Railway environment
2. Maintain the CC Public Wiki local Docker development environment
3. Maintain parity between production and development environments

Production website: [CC Public Wiki](https://wiki.creativecommons.org/)

[public-wiki-pkg]: https://github.com/creativecommons/public-wiki/pkgs/container/public-wiki


## Code of Conduct

[`CODE_OF_CONDUCT.md`][org-coc]:
> The Creative Commons team is committed to fostering a welcoming community.
> This project and all other Creative Commons open source projects are governed
> by our [Code of Conduct][code_of_conduct]. Please report unacceptable
> behavior to [conduct@creativecommons.org](mailto:conduct@creativecommons.org)
> per our [reporting guidelines][reporting_guide].

[org-coc]: https://github.com/creativecommons/.github/blob/main/CODE_OF_CONDUCT.md
[code_of_conduct]: https://opensource.creativecommons.org/community/code-of-conduct/
[reporting_guide]: https://opensource.creativecommons.org/community/code-of-conduct/enforcement/


## Contributing

See [`CONTRIBUTING.md`][org-contrib] and the [**Development**](#Development)
section, below.

[org-contrib]: https://github.com/creativecommons/.github/blob/main/CONTRIBUTING.md


## Development


### Docker containers

The [`docker-compose.yml`](docker-compose.yml) file defines the following
containers:
- **web** - Web server (Apache2/MediaWiki)
  - **[`localhost:8080`](http://localhost:8080/)**
- **db** - Database server (MySQL)


### Dependencies

1. Install Docker ([Get Docker | Docker Docs][docker-install])
2. Install additional dependencies
   macOS installation example (assumes [Homebrew][brew]):
   ```shell
   brew install hadolint prek railway rsync shellcheck
   ```
   ```shell
   gh extension install github/gh-actions-lock
   ```
   1. Install hadolint ([Install - hadolint/hadolint][hadolint-install])
   2. Install prek ([Installation - j178/prek][prek-install])
   3. Install Railway CLI ([Installing - CLI | Railway Docs][railway-install])
   4. Install Rsync ([rsync download][rsync-install])
   5. Install shellcheck ([Installing -
      koalaman/shellcheck][shellcheck-install])
   6. Install gh ([Installation - github/cli/cli][gh-install])
   7. Install gh-actions-lock ([Install - github/gh-actinos-lock][lock-install])

[docker-install]: https://docs.docker.com/get-started/get-docker/
[brew]: https://brew.sh/
[hadolint-install]: https://github.com/hadolint/hadolint#install
[prek-install]: https://github.com/j178/prek#installation
[railway-install]: https://docs.railway.com/cli#installing-the-cli
[rsync-install]: https://rsync.samba.org/download.html
[shellcheck-install]: https://github.com/koalaman/shellcheck#installing
[gh-install]: https://github.com/cli/cli#installation
[lock-install]: https://github.com/github/gh-actions-lock#install


## Setup

1. Prepare and install prek Git hooks:
   ```shell
   prek install --prepare-hooks
   ```
2. Create the environment `.env` file by copying
   [`.env.example`](.env.example):
    ```shell
    cp .env.example .env
    ```
2. Update `.env` to ensure all variable have appropriate values.
3. Build and start Docker:
    ```shell
    docker-compose up
    ```
4. Wait for the build and initialization to complete


### Static analysis

Analysis on git commit is configure in Setup, step 1, above.

Prek can be invoked manually:
```shell
prek run --show-diff-on-failure --color=always --all-files
```


## Web container configuration

See the `config/configure_*` configuration scripts called from [`config/startupservice.sh`][config/startupservice.sh].


#### MediaWiki configuration

| Name      | Version  | Notes
| --------- | -------- | ------------------------------- |
| MediaWiki | `1.43.6` | Packaged for Debian 13 (trixie) |

Also see:
- [`.env.example`](.env.example).
- [`config/configure_mediawiki.sh`](config/configure_mediawiki.sh)


## Migration from legacy server

The legacy migration directory has been deleted. Links below are to commit `e1ea34af3cc8151df8e73d80b2d0c2e7dff2d5e8`.
- [`migrate/`][migrate-dir]
  - [`README.md`][migrate-readme]
    - Includes related Debian, Docker, and MediaWiki documentation links

[migrate-dir]: https://github.com/creativecommons/public-wiki/tree/e1ea34af3cc8151df8e73d80b2d0c2e7dff2d5e8/migrate
[migrate-readme]: https://github.com/creativecommons/public-wiki/blob/e1ea34af3cc8151df8e73d80b2d0c2e7dff2d5e8/migrate/README.md


## License

- [`LICENSE`](LICENSE) (Expat/[MIT][mit] License)

[mit]: http://www.opensource.org/licenses/MIT "The MIT License | Open Source Initiative"
