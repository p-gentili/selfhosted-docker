# AdGuard Home
Official website: [https://adguard.com/it/adguard-home/overview.html](https://adguard.com/it/adguard-home/overview.html)

Github: [https://github.com/AdguardTeam/AdGuardHome](https://github.com/AdguardTeam/AdGuardHome)

## Install
Port 53, generally used for DNS, could be already taken by `systemd-resolved`. Follow [the official guide](https://github.com/AdguardTeam/AdGuardHome/wiki/FAQ#why-am-i-getting-bind-address-already-in-use-error-when-trying-to-install-on-ubuntu) before setting this container up.

## Configure
Access `http://<HOST>:3000` for first configuration. The dashboard is then accessible at `http://<HOST>:3080`.
