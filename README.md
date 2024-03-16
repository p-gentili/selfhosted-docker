```mermaid
graph TD
  subgraph DDNS
    ddns(IP)
  end
  subgraph Router
    portForwarding(Port Forwarding)
  end

  subgraph Local Host
    subgraph Docker Containers
      caddy[Caddy]
      adguard-home[AdGuard Home]
      cloudflare-ddns[CloudFlare DDNS]
      subgraph CaddyServices
        vaultwarden[Vaultwarden]
        jellyfin[Jellyfin]
        actual[Actual Budget]
        transmission[Transmission]
        linkding[Linkding]
        subgraph NextCloud Network
            nextcloud[NextCloud]
            nextcloud-code[Collabora]
            nextcloud-db[Database]
        end
        subgraph Immich Network
            immich[immich]
            immich-redis[Redis]
            immich-db[Database]
            immich-ml[ML]
        end
      end
    end
  end

  WAN --> ddns
  ddns --> portForwarding
  portForwarding --> caddy
  Router --DNS--> adguard-home
  caddy --> vaultwarden
  caddy --> jellyfin
  caddy --> nextcloud
  caddy --> actual
  caddy --> immich
  caddy --> transmission
  caddy --> linkding
```

## Install

Each application can be set up by running the `init.sh` script contained in each directory: the script will delete and re-create the containers maintaining the data stored in mount binds and, if present, it will restore the database backup.

For convenience, the user can run `init-all.sh` script to set up every application contained in this repository.

## Backup

Before backing up the whole directory, the user should run `pre-backup-all.sh` script which, depending on the application, will put the containers in the right mode and eventually dump the database.

Once the backup is complete, the user should run `post-backup-all.sh` script to restore the normal functionality.

