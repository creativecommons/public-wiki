# Migration


## Overview

The migration process moves MediaWiki hosting from the Bytemark legacy virtual
machine, to local Docker containers to perform the upgrades, and then up to the
new production Northflank container.

The following local Docker containers are used:
1. `db`: MariaDB (latest)
2. `web-bullseye`: Debian 11 (Bullseye) running MediaWiki 1.35.13
   - [`Dockerfile.bullseye`](`Dockerfile.bullseye`)
3. `web`: Debian 13 (Trixie) container running MediaWiki 1.43.8
   - [`Dockerfile`](../Dockerfile)
     - The same `Dockerfile` is also used in production

The following script is used:
- [`migrate_cc_mediawiki.sh`](migrate_cc_mediawiki.sh)


### Process

1. Ensure you are in this directory (`migrate/`)
2. Create and start Docker containers
    ```shell
    docker compose up
    ```
3. Export MediaWiki data (database SQL and images files) from Bytemark legacy
   virtual machine running MediaWiki 1.30.0
    ```shell
    ./migrate_cc_mediawiki.sh pull
    ```
   1. Store data in `cache-legacy/`
      1. Copy `images/` (uploaded files) from legacy server
      2. Dump database to a SQL file
   3. Update SQL dump to change `ENGINE` to `InnoDB` for all tables
   4. Update SQL dump to change `CHARSET` to `binary` for all tables
   5. Update SQL dump to change `CHARSET` to `utf8mb4` for `searchindex` table
4. Import MediaWiki data to local Docker containers and upgrade MediaWiki to
   1.43.8
    ```shell
    ./migrate_cc_mediawiki.sh import
    ```
    1. Import and upgrade MediaWiki on Docker `web-bullseye`
       1. Copy `images/` (uploaded files) to Docker volume
       2. Import database from the SQL file
       3. Run MediaWiki update to version 1.35.13
       4. Clean-up MediaWiki users with no ID
    2. Upgrade MediaWiki on Docker `web` container
       1. Run MediaWiki update to version 1.43.8
       2. Clean-up page titles
       3. Remove unused accounts
       4. Rebuild all
          - rebuild text index
          - rebuild recent changes
          - refresh links
5. Export MediaWiki data (database SQL and images file) from local Docker
   containers
    ```shell
    ./migrate_cc_mediawiki.sh export
    ```
   1. Store data in `cache-docker/`
      1. Copy `images/` (uploaded files) from legacy cache
      2. Dump database to a SQL file


## Related documentation


## Docker

- [Dockerfile reference | Docker Docs][dockerfile]
- [Compose file reference | Docker Docs][composefile]
- [Best practices | Docker Docs][practices]

[dockerfile]: https://docs.docker.com/reference/dockerfile
[composefile]: https://docs.docker.com/reference/compose-file/
[practices]: https://docs.docker.com/build/building/best-practices/


## Docker images

- [mediawiki - Official Image | Docker Hu](https://hub.docker.com/_/mediawiki/)
- [mariadb - Official Image | Docker Hub](https://hub.docker.com/_/mariadb)


## MediaWiki on Debian

- [Manual:Running MediaWiki on Debian or Ubuntu - MediaWiki][mw_on_debian]
- [MediaWiki - Debian Wiki][deb_wiki_mw]
- [Manual:Short URL/Apache - MediaWiki][mw_short_url]
- [Manual:Configuring file uploads - MediaWiki][mw_file_up]
- [MediaWiki 1.43 - MediaWiki][mw_1_43] LTS (long term support)

[mw_on_debian]: https://www.mediawiki.org/wiki/Manual:Running_MediaWiki_on_Debian_or_Ubuntu
[deb_wiki_mw]: https://wiki.debian.org/MediaWiki
[mw_short_url]: https://www.mediawiki.org/wiki/Manual:Short_URL/Apache
[mw_file_up]: https://www.mediawiki.org/wiki/Manual:Configuring_file_uploads
[mw_1_43]: https://www.mediawiki.org/wiki/MediaWiki_1.43


## Mediawiki database schema

- [Manual:Database layout - MediaWiki][mw_db_layout]
- [sql/mysql/tables-generated.sql - mediawiki/core - Gitiles][tables_sql]
- [standard UTF8 encoding for MediaWiki databases · Issue #373 ·
  openstreetmap/operations][osm_issue_373]

[mw_db_layout]: https://www.mediawiki.org/wiki/Manual:Database_layout
[tables_sql]: https://gerrit.wikimedia.org/g/mediawiki/core/%2B/HEAD/sql/mysql/tables-generated.sql
[osm_issue_373]: https://github.com/openstreetmap/operations/issues/373


## MediaWiki maintenance

- [Manual:**Maintenance scripts/List of scripts** - MediaWiki][mw_list_scripts]

[mw_list_scripts]: https://www.mediawiki.org/wiki/Manual:Maintenance_scripts/List_of_scripts


## MediaWiki release notes

- [MediaWiki 1.31 - MediaWiki](https://www.mediawiki.org/wiki/MediaWiki_1.31)
- [MediaWiki 1.32 - MediaWiki](https://www.mediawiki.org/wiki/MediaWiki_1.32)
- [MediaWiki 1.33 - MediaWiki](https://www.mediawiki.org/wiki/MediaWiki_1.33)
- [MediaWiki 1.34 - MediaWiki](https://www.mediawiki.org/wiki/MediaWiki_1.34)
- [MediaWiki 1.35 - MediaWiki](https://www.mediawiki.org/wiki/MediaWiki_1.35)
- [MediaWiki 1.36 - MediaWiki](https://www.mediawiki.org/wiki/MediaWiki_1.36)
- [MediaWiki 1.37 - MediaWiki](https://www.mediawiki.org/wiki/MediaWiki_1.37)
- [MediaWiki 1.38 - MediaWiki](https://www.mediawiki.org/wiki/MediaWiki_1.38)
- [MediaWiki 1.39 - MediaWiki](https://www.mediawiki.org/wiki/MediaWiki_1.39)
- [MediaWiki 1.40 - MediaWiki](https://www.mediawiki.org/wiki/MediaWiki_1.40)
- [MediaWiki 1.41 - MediaWiki](https://www.mediawiki.org/wiki/MediaWiki_1.41)
- [MediaWiki 1.42 - MediaWiki](https://www.mediawiki.org/wiki/MediaWiki_1.42)
- [MediaWiki 1.43 - MediaWiki](https://www.mediawiki.org/wiki/MediaWiki_1.43)
