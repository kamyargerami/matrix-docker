![ScreenShot](https://matrix.org/docs/guides/img/understanding-synapse-hosting-nginx.png)

# Setup Matrix with docker-compose

This repository helps you to run your messaging application.

You can set up all you need for the matrix in less than an hour. it will install the below applications for you.

- Synapse
- Element
- PostgreSQL
- Coturn
- Nginx
- Traefik

# Requirements

- Docker
- Docker-compose

# Installation
1. Add these two subdomains to your DNS:

```
matrix.example.com
web.example.com
```

---

2. Clone the repository and go to the `matrix` directory

---

3. Copy `.env.example` to `.env` and change `DOMAIN` in `.env` file to your domain

---

4. Run ``docker-compose up`` and after 1 minute stop it to do the next action.

---

5. Edit the `/var/lib/docker/volumes/matrix_nginx_conf/_data/default.conf` and add these lines in the bottom
   of the file before `}` then change the `examle.com` to your domain.

```
    location /.well-known/matrix/server {
        access_log off;
        add_header Access-Control-Allow-Origin *;
        default_type application/json;
        return 200 '{"m.server": "matrix.example.com:443"}';
    }

    location /.well-known/matrix/client {
        access_log off;
        add_header Access-Control-Allow-Origin *;
        default_type application/json;
        return 200 '{"m.homeserver": {"base_url": "https://matrix.example.com"}}';
    }
```

---

6. Edit the `/var/lib/docker/volumes/matrix_coturn/_data/turnserver.conf` and add the below configuration:

- Replace the `LongSecretKeyMustEnterHere` with a secure random password.
- Replace `matrix.example.com` with your domain
- Change the `YourServerIP` to your server's public IP address.

```
use-auth-secret
static-auth-secret=LongSecretKeyMustEnterHere
realm=matrix.example.com
listening-port=3478
tls-listening-port=5349
min-port=49160
max-port=49200
verbose
allow-loopback-peers
cli-password=SomePasswordForCLI
external-ip=YourServerIP
```

---

7. Change the `example.com` with your domain in the below command and run it
```
docker run -it --rm -v matrix_synapse_data:/data -e SYNAPSE_SERVER_NAME=example.com -e SYNAPSE_REPORT_STATS=yes matrixdotorg/synapse:v1.63.0 generate
```

---

8. Edit `/var/lib/docker/volumes/matrix_synapse_data/_data/homeserver.yaml` file and change it as below:

- You need to replace the database config to PostgreSQL

Don't worry about the database security, this is not going to expose to the internet.

```
database:
  name: psycopg2
  txn_limit: 10000
  args:
    user: synapse
    password: aComplexPassphraseNobodyCanGuess
    database: synapse
    host: matrix_synapse_db_1
    port: 5432
    cp_min: 5
    cp_max: 10
```

- Add the coturn config to the file
- Change all `example.com` to your domain address.
- Change `LongSecretKeyMustEnterHere` to the secret key that you choose before in `/var/lib/docker/volumes/matrix_coturn/_data/turnserver.conf`

```
turn_uris:
  - "turn:matrix.example.com:3478?transport=udp"
  - "turn:matrix.example.com:3478?transport=tcp"
  - "turns:matrix.example.com:3478?transport=udp"
  - "turns:matrix.example.com:3478?transport=tcp"
turn_shared_secret: "LongSecretKeyMustEnterHere"
turn_user_lifetime: 86400000
turn_allow_guests: True
```

---

9. Run the containers with `docker-compose up` and if everything goes well stop it
   and run the `docker-compose up -d` to run these containers in the background.

# Testing

1. The matrix URL (`https://matrix.example.com`) must show the synapse default page
2. The Nginx must respond to these two URLs
   - https://example.com/.well-known/matrix/client
   - https://example.com/.well-known/matrix/server
3. You can test the federation on the below link
   - https://federationtester.matrix.org/
4. You can log in to your Element client at `https://web.example.com`

# Add new user

You need to enter the container with `docker exec -it matrix_synapse_1 bash`

Run the below command to create a user.

```
register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008
```

# Enable the registration

By default, registration is disabled and users must be added using the command line, but if you want to access
everybody to register in your matrix you can add the below line to the end of `/var/lib/docker/volumes/matrix_synapse_data/_data/homeserver.yaml` file.

```
enable_registration: true
enable_registration_without_verification: true
```

Run the `docker-compose restart` to apply the new setting.

If you need to have email verification enabled or a captcha on registration you can read the link below:

https://matrix-org.github.io/synapse/latest/usage/configuration/config_documentation.html#registration

## For more information you can watch the tutorials.

https://www.youtube.com/watch?v=JCsw1bbBjAM

https://matrix.org/docs/guides/understanding-synapse-hosting

https://gist.github.com/matusnovak/37109e60abe79f4b59fc9fbda10896da?permalink_comment_id=3626248#optional-turn-server-video-calls
