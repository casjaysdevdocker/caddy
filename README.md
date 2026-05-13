## 👋 Welcome to caddy 🚀  

caddy README  
  
  
## Install my system scripts  

```shell
 sudo bash -c "$(curl -q -LSsf "https://github.com/systemmgr/installer/raw/main/install.sh")"
 sudo systemmgr --config && sudo systemmgr install scripts  
```
  
## Automatic install/update  
  
```shell
dockermgr update caddy
```
  
## Install and run container
  
```shell
dockerHome="/var/lib/srv/$USER/docker/casjaysdevdocker/caddy/caddy/latest/rootfs"
mkdir -p "/var/lib/srv/$USER/docker/caddy/rootfs"
git clone "https://github.com/dockermgr/caddy" "$HOME/.local/share/CasjaysDev/dockermgr/caddy"
cp -Rfva "$HOME/.local/share/CasjaysDev/dockermgr/caddy/rootfs/." "$dockerHome/"
docker run -d \
--restart always \
--privileged \
--name casjaysdevdocker-caddy-latest \
--hostname caddy \
-e TZ=${TIMEZONE:-America/New_York} \
-v "$dockerHome/data:/data:z" \
-v "$dockerHome/config:/config:z" \
-p 80:80 \
casjaysdevdocker/caddy:latest
```
  
## via docker-compose  
  
```yaml
version: "2"
services:
  ProjectName:
    image: casjaysdevdocker/caddy
    container_name: casjaysdevdocker-caddy
    environment:
      - TZ=America/New_York
      - HOSTNAME=caddy
    volumes:
      - "/var/lib/srv/$USER/docker/casjaysdevdocker/caddy/caddy/latest/rootfs/data:/data:z"
      - "/var/lib/srv/$USER/docker/casjaysdevdocker/caddy/caddy/latest/rootfs/config:/config:z"
    ports:
      - 80:80
    restart: always
```
  
## Get source files  
  
```shell
dockermgr download src casjaysdevdocker/caddy
```
  
OR
  
```shell
git clone "https://github.com/casjaysdevdocker/caddy" "$HOME/Projects/github/casjaysdevdocker/caddy"
```
  
## Build container  
  
```shell
cd "$HOME/Projects/github/casjaysdevdocker/caddy"
buildx 
```
  
## Authors  
  
🤖 casjay: [Github](https://github.com/casjay) 🤖  
⛵ casjaysdevdocker: [Github](https://github.com/casjaysdevdocker) [Docker](https://hub.docker.com/u/casjaysdevdocker) ⛵  
