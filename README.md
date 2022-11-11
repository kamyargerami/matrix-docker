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

3. Run ``docker-compose up`` and after a while stop it to do the next action.

4. Change path to this repository and also change the domain and run the below command:


```
docker run -it --rm -v /absolute/path/to/repository/volumes/synapse_data:/data -e SYNAPSE_SERVER_NAME=matrix.org -e SYNAPSE_REPORT_STATS=yes matrixdotorg/synapse:v1.63.0 generate
```

5. Edit `volumes/synapse_data/homeserver.yaml` file and change it as below:

- You need to change the database to postgresql


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

- Add the coturn config to below the file, change all `example.com` to your domain address.

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


6. Edit the `volumes/coturn/_data/turnserver.conf` and change external ip to your server public ip address.

7. Edit the `volumes/nginx_conf/_data/default.conf` and change your domain address in it.

8. Add these two dns records to your domain:

```
matrix.example.com
web.examplw.com
```

9. Run the containers with `docker-compose up -d`

## For more information you can watch the tutorials.

https://www.youtube.com/watch?v=JCsw1bbBjAM

https://matrix.org/docs/guides/understanding-synapse-hosting

https://federationtester.matrix.org/

https://gist.github.com/matusnovak/37109e60abe79f4b59fc9fbda10896da?permalink_comment_id=3626248#optional-turn-server-video-calls