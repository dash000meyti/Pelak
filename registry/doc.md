# verdaccio docker

## Docker confog.yaml

```
storage: /verdaccio/storage

listen: 0.0.0.0:4873

max_body_size: 900mb

server:
  keepAliveTimeout: 60

auth:
  htpasswd:
    file: /verdaccio/storage/htpasswd

uplinks: {}

packages:
  '@*/*':
    access: $all
    publish: admin
    unpublish: admin
    proxy: false

  '**':
    access: $all
    publish: admin
    unpublish: admin
    proxy: false

web:
  title: Registry Pelak 0.1.0
  darkMode: true

middlewares:
  audit:
    enabled: false

logs:
  - type: stdout
    format: pretty
    level: http
```

run local

```
docker run -d \
  --name verdaccio \
  -p 4873:4873 \
  -v verdaccio-storage:/verdaccio/storage \
  -v $(pwd)/config.yaml:/verdaccio/conf/config.yaml \
  verdaccio/verdaccio
```

## hamgit config :

```
configmap:
  configmapItems:
    verdaccio-config:
      path: /verdaccio/conf/config.yaml
      subPath: config.yaml
      value:
        config.yaml: |-
          storage: /verdaccio/storage

          listen: 0.0.0.0:4873

          max_body_size: 900mb

          server:
            keepAliveTimeout: 60

          auth:
            htpasswd:
              file: /verdaccio/storage/htpasswd

          uplinks: {}

          packages:
            '@*/*':
              access: $all
              publish: admin
              unpublish: admin
              proxy: false

            '**':
              access: $all
              publish: admin
              unpublish: admin
              proxy: false

          web:
            title: Registry Pelak 0.1.0
            darkMode: true

          middlewares:
            audit:
              enabled: false

          logs:
            - type: stdout
              format: pretty
              level: http
```

## use

### set registry:

```
npm set registry https://npm-registry.darkube.ir/
```

### user :

- add admin

```
npm adduser --registry https://npm-registry.darkube.ir/
```

```
npm notice Log in on https://npm-registry.darkube.ir/

Username: admin
Password: 
Email (this will be public):
Logged in on https://npm-registry.darkube.ir/.
```

- login

```
npm login --registry https://npm-registry.darkube.ir
```

```
npm notice Log in on https://npm-registry.darkube.ir/

Username: admin
Password: 
Logged in on https://npm-registry.darkube.ir/.
```

### run :

- copy file and folder

```
registry/
├─ npm-pull.sh
├─ npm-push.sh
└─ packages/
   ├─ todo/
   │  └─ *.tgz
   └─ done/
      └─ *.tgz
```

- edit **npm-push.sh** change REGISTRY

```
REGISTRY="https://npm-registry.darkube.ir/"
```

- add **Dockerfile**

add this line
```
RUN npm set registry https://npm-registry.darkube.ir/
```
after
```
WORKDIR /app
```
or befor
```
RUN npm ci |or| RUN npm i
```

- add **package.json**

```
  "scripts": {
    ...
    "registry:pull": "sh registry/npm-pull.sh",
    "registry:push": "sh registry/npm-push.sh",
    "registry": "npm run registry:pull && npm run registry:push"
  },
```

- option **.dockerignore**

```
registry
```

- option **.gitignore**

```
registry/packages
```