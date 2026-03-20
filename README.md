# public-wiki

_Development_ Creative Commons (CC) Public Wiki


## Overview

The aim of the project is to establish a robust and localized development
environment for MediaWiki using Docker. This repository should represent the
most advanced and closest implementation of the
[CC Public Wiki](https://wiki.creativecommons.org).


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

See [`CONTRIBUTING.md`][org-contrib].

[org-contrib]: https://github.com/creativecommons/.github/blob/main/CONTRIBUTING.md


## Docker containers:

The [`docker-compose.yml`](docker-compose.yml) file defines the following containers:
- **wiki-web** - Public Wiki web server (Apache2/MediaWiki)
- **wiki-db** - Database server (MariaDB)
  - **[localhost:8080](http://localhost:8080/)**


## Setup

1. Create the enviornment `.env` file by copying
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


## Dev configuration


### Apache2

See [`config/web-sites-available/000-default.conf`][dev-webconfig].

[dev-webconfig]: config/web-sites-available/000-default.conf


### MediaWiki configuration

| Name      | Version  | Notes
| --------- | -------- | ------------------------------- |
| MediaWiki | `1.43.6` | Packaged for Debian 13 (trixie) |

Also see:
- [`.env.example`](.env.example).
- [`config/configure_mediawiki.sh`](config/configure_mediawiki.sh)


### Migration from legacy server

- [`migrate/`](migrate/)
  - [`README.md`](migrate/README.md)
    - Includes related Debian, Docker, and MediaWiki documentation links


### Related development links

- [creativecommons/index-dev-env][index-dev-env]: _Local development
  environment for CreativeCommons.org (product name: index)_
- [creativecommons/sre-salt-prime][sre-salt-prime]: _Site Reliability
  Engineering / DevOps SaltStack configuration files_

[index-dev-env]: https://github.com/creativecommons/index-dev-env
[sre-salt-prime]: https://github.com/creativecommons/sre-salt-prime


## License

- [`LICENSE`](LICENSE) (Expat/[MIT][mit] License)

[mit]: http://www.opensource.org/licenses/MIT "The MIT License | Open Source Initiative"
