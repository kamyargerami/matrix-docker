# Setup Matrix with docker-compose 

This repository helps you to run your own messaging application.

You can set up all you need for matrix in less than an hour. it will install below applications for you.

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
1. Clone the repository and go to the `matrix` directory

2. Change domain in ``.env`` file to your domain

3. Run ``docker-compose up`` and after 1 minute stop it to do the next action.
   
7. Edit the `/var/lib/docker/volumes/matrix_nginx_conf/_data/default.conf` and add these line in the bottom 
   of the file before `}` then change the `examle.com` to your own domain.

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


6. Edit the `/var/lib/docker/volumes/matrix_coturn/_data/turnserver.conf` and add the below configuration:

- Replace the `LongSecretKeyMustEnterHere` with a secure random password.
- Change the `YourServerIP` to your server public ip address.

```
use-auth-secret
static-auth-secret=LongSecretKeyMustEnterHere
realm=matrix.matrix.org
listening-port=3478
tls-listening-port=5349
min-port=49160
max-port=49200
verbose
allow-loopback-peers
cli-password=SomePasswordForCLI
external-ip=YourServerIP
```

3. Change the `example.com` with your domain in below command and run it
```
docker run -it --rm -v matrix_synapse_data:/data -e SYNAPSE_SERVER_NAME=example.com -e SYNAPSE_REPORT_STATS=yes matrixdotorg/synapse:v1.63.0 generate
```

5. Edit `/var/lib/docker/volumes/matrix_synapse_data/_data/homeserver.yaml` file and change it as below:

- You need to replace the database config to postgresql

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

- Add the coturn config to below the file
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

8. Add these two subdomains to your dns provider:

```
matrix.example.com
web.examplw.com
```

9. Run the containers with `docker-compose up` and if everything goes well stop it 
   and run the `docker-compose up -d` to run these containers in background.

## For more information you can watch the tutorials.

https://www.youtube.com/watch?v=JCsw1bbBjAM

https://matrix.org/docs/guides/understanding-synapse-hosting

https://federationtester.matrix.org/

https://gist.github.com/matusnovak/37109e60abe79f4b59fc9fbda10896da?permalink_comment_id=3626248#optional-turn-server-video-calls