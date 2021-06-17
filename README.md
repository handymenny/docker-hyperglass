## Docker

### User: General use

- Copy [docker-compose.yaml](docker-compose.yaml) to your destination and edit as desired
- Create a valid `devices.yaml`
    - I.e. based on [hyperglass/examples/devices.yaml](hyperglass/examples/devices.yaml)
- Create a valid `hyperglass.yaml`
    - I.e. based on [hyperglass/examples/hyperglass.docker.yaml](hyperglass/examples/hyperglass.docker.yaml)
    - If redis runs on docker make sure `cache.host` is set to `redis.hyperglass`
- Run `docker-compose up -d`
- Run `docker-compose ps`, to wait till it's up

### Developer: Build and publish

- Copy [docker-compose.build.yaml](docker-compose.build.yaml) and [docker-compose.yaml](docker-compose.yaml) to your destination and edit as desired
- `docker-compose -f docker-compose.yaml -f docker-compose.build.yaml build`
- `docker push ...`