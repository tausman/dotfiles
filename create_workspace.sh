# WIP
workspaces create tausman1 --region us-east-1 --repo dogweb
scp workspace-tausman:~/.config/datadog/dev-ssl/localhost.crt ~
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ~/localhost.crt

