# public-wiki
Public Wiki

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


### Goals

The aim of the project is to establish a robust and localized development environment for MediaWiki using Docker. This repository should represent the most advanced and closest implementation of [publicWiki](https://wiki.creativecommons.org)


#### Docker containers:

The [`docker-compose.yml`](docker-compose.yml) file defines the following containers:
- **wiki-web** - PublicWiki web server (Apache2/MediaWiki)
- **wiki-db** - Database server (MariaDB)

### Setup
- Build and start Docker:
    ```shell
    docker-compose up
    ```
- Wait for the build and initialization to complete

## Related Links
- [FrontPage - Debian Wiki](https://wiki.debian.org/FrontPage)
- [Docker Docs](https://docs.docker.com/)
- [creativecommons/sre-salt-prime](https://github.com/creativecommons/sre-salt-prime): Site Reliability Engineering / DevOps SaltStack configuration files
- [creativecommons/index-dev-env](https://github.com/creativecommons/index-dev-env): Local development environment for CreativeCommons.org (reference for docker project)
- [MainPage - Wiki](https://wiki.creativecommons.org/)

## License

- [`LICENSE`](LICENSE) (Expat/[MIT][mit] License)

[mit]: http://www.opensource.org/licenses/MIT "The MIT License | Open Source Initiative" 
