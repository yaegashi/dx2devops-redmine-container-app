# Redmine container

## Local development

[compose.yml](compose.yml) is provided
so that you can easily build and test Redmine container images.
Using a devcontainer is also recommended.

1. Place the Redmine source files in the `redmine` directory.
You can clone it from the official repository by either of the following commands:
    * Run `git clone https://github.com/redmine/redmine` for Redmine
    * Run `git clone https://github.com/redmica/redmica redmine` for RedMica
2. Copy file [`docker.env.example`](docker.env.example) to `docker.env`.
3. Copy file [`.env.example`](.env.example) to `.env` and set `COMPOSE_PROFILES` in it.
Choose one of the supported profiles: `sqlite`, `mysql`, `mariadb`, `postgres`.
4. Run `docker compose build` to build a container image.
5. Run `docker compose up -d` to start containers in the background.
    * The redmine container creates `./data/wwwroot` for `/home/site/wwwroot` volume.
    * The redmine container enters maintenance mode because the operation mode is not set.
    * The database container creates `./data/mysql` etc. for the database volume.
6. Perform the following initial setup steps in the container:
    1. Invoke a shell in the redmine container using either of the following methods:
        * Run `docker compose exec redmine-<profile> bash`
        * Run `ssh root@localhost -p 3333`.  The password is `Docker!`.
    2. Run `rmops dbinit` only when the profile is not `sqlite`.  It will prompt you for username/password of the DB admin user.
        * The username is `root` for `mysql` or `mariadb`, and `postgres` for `postgres`.
        * The password is `secret`.
    3. Run `rmops setup`.  This command does the initial migration tasks.  The admin password can be found in `/home/site/wwwroot/etc/password.txt`.
    4. Run `rmops env set mode rails`.  This command sets the operation mode of rails in service.
    4. Exit from the shell.
7. Run `docker compose restart` to restart the redmine container.
    * The redmine container enters service mode because the operation mode is set to `rails`.
8. Open http://localhost:8080 in your web browser to test the Redmine app.
