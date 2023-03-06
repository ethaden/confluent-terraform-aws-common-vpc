client
dev tun
proto udp
remote ${vpn_gateway_endpoint} 443
remote-random-hostname
resolv-retry infinite
nobind
remote-cert-tls server
cipher AES-256-GCM
verb 3
<ca>
${ca_cert_pem}
</ca>

<cert>
${client_cert_pem}
</cert>

<key>
${client_key_pem}
</key>

reneg-sec 0
